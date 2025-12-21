require_relative "emitter"

class Gouache
  module Builder


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
        @instance = instance
        @tags     = []
        @nesting  = 0
        @emitter  = ::Gouache::Emitter.new(instance:)
      end

      # def call(...) = _build!(nil, ...)

      def <<(s) = @emitter << s

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
        content.each{ @emitter << it }

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
