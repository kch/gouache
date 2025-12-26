# frozen_string_literal: true

require_relative "emitter"
require_relative "wrap"
require "strscan"

class Gouache
  module Builder

    using Wrap

    def self._compile node, emitter:
      return unless node&.any?                       # stop recursing
      first, *rest = *node.slice_before(Symbol)      # each symbol marks a new tag/node
      tag, *first = first if first in [Symbol, *]    # node may begin with tag or not
      rest = rest.reverse_each.inject{|b,a| a << b } # nest symbol chains [:a,:b,:c] -> [:a,[:b,[:c]]]
      emitter.open_tag tag if tag
      first.each{ emit_content(it, emitter:) }
      _compile(rest, emitter:)
      emitter.close_tag if tag
      nil
    end

    def self.compile root, instance:
      emitter = instance.mk_emitter
      _compile(root, emitter:)
      emitter.emit!
    end

    def self.safe_emit_sgr s, emitter:
      unless s.has_sgr?
        emitter << s
        return nil
      end

      ss = StringScanner.new s.wrap
      wraps = 0
      while text = ss.scan_until(RX_ESC_LA)
        emitter << text
        case
        when ss.skip(WRAP_OPEN)
          wraps += 1
          emitter.begin_sgr
          emitter << ss.scan_until(RX_ESC_LA)
        when ss.skip(WRAP_CLOSE)
          next if wraps == 0
          wraps -= 1
          emitter.end_sgr
        when sgr = ss.scan(RX_SGR)
          emitter.push_sgr sgr
        else emitter << ss.scan(?\e)
        end
      end
      wraps.times{ emitter.end_sgr }
      emitter << ss.rest
      nil
    end

    def self.emit_content(x, emitter:)
      case x
      in Array  then _compile(x, emitter:)
      in String then safe_emit_sgr(x, emitter:)
      in _      then emitter << x
      end
    end

    class UnfinishedChain < RuntimeError
      def initialize(chain) = super "call chain #{chain.instance_exec{@tags}*?.} left dangling with no arguments"
    end


    class ChainProxy < BasicObject
      def initialize parent, tag
        @tags = [tag]
        @parent = parent
      end

      private def method_missing(m, *a, &b)
        return super if %i[ to_s to_str to_ary ].include? m # prevent confusion if proxy leaks

        if a.empty? && b.nil?
          @tags << m
          return self
        end

        @parent.instance_exec{ @chain = nil }
        # inject tags into nested blocks and send to owner proxy
        buildme = @tags.reverse_each.inject(->{ __send__(:_build!, m, *a, &b) }){|b, t| ->{ __send__(:_build!, t, &b) }}
        @parent.instance_exec(&buildme)
      end
    end


    class Proxy < BasicObject

      def self.for(instance, m, ...)
        return unless m.nil? || instance.rules.key?(m)
        new(instance).__send__(:_build!, m, ...)
      end

      def initialize(instance)
        # @instance = instance
        @emitter  = instance.mk_emitter
        @tags     = []
        @nesting  = 0
      end

      # def call(...) = _build!(nil, ...) # TODO: Do we want this?

      def <<(s) = ::Gouache::Builder.emit_content(s, emitter: @emitter)

      private def method_missing(m, ...)
        return super if %i[ to_s to_str to_ary ].include? m # prevent confusion if proxy leaks
        # return super unless @instance.rules.key? m  # TODO: optional?
        _build!(m, ...)
      end

      private def _build!(m, *content, &builder)
        ::Kernel.raise UnfinishedChain, @chain if @chain
        if content.empty? && builder.nil?
          @chain = ChainProxy.new(self, m)
          return @chain
        end

        @emitter.open_tag m if m
        content.each{ ::Gouache::Builder.emit_content(it, emitter: @emitter) }

        @nesting += 1
        case builder&.arity
        in nil
        in 1 then builder[self]
        in 0 then instance_exec(&builder)
        in _ then raise ::ArgumentError
        end
        @nesting -= 1
        ::Kernel.raise UnfinishedChain, @chain if @chain
        @emitter.close_tag if m
        @nesting == 0 ? @emitter.emit! : nil
      end

    end # Proxy

  end # Builder
end # Gouache
