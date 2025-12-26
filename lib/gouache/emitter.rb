# frozen_string_literal: true

require_relative "layer_stack"
require_relative "stylesheet"

class Gouache
  class Emitter

    def initialize(instance:)
      @rules   = instance.rules # stylesheet
      @enabled = instance.enabled?
      @layers  = LayerStack.new # each tag or bare sgr emitted generates a layer
      @flushed = @layers.base   # keep layer state after each flush so next flush can diff against it
      @queue   = []             # accumulate sgr params to emit until we have text to style (we collapse to minimal set then)
      @got_sgr = false          # did we emit sgr at all? used to determine if reset in the end
      @out     = +""
    end

    def enqueue(sgr)       = (@queue << sgr; self)
    def open_tag(tag)      = enqueue @layers.diffpush(@rules[tag], tag)
    def begin_sgr          = enqueue @layers.diffpush(nil, :@@sgr)
    def push_sgr(sgr_text) = enqueue @layers.diffpush(Layer.from Gouache.scan_sgr sgr_text)

    def end_sgr
      sgr_begun = @layers.reverse_each.find{ it.tag != nil }&.tag == :@@sgr
      enqueue @layers.diffpop_until{ it.top.tag == :@@sgr } if sgr_begun
      enqueue @layers.diffpop if @layers.top.tag == :@@sgr
      self
    end

    def close_tag
      top_is_tag = ->{ not it.top.tag in nil | :@@sgr }
      top_is_tag[@layers] or enqueue @layers.diffpop_until(&top_is_tag)
      top_is_tag[@layers] or raise "attempted to close tag without open tag"
      enqueue @layers.diffpop
    end

    def << s
      s = s.to_s
      return self if s.empty?
      flush
      @out << s
      self
    end

    private def flush
      return self unless @enabled
      return self unless @queue.any?
      @flushed = Layer.from Layer.from(@queue).diff(@flushed)
      sgr = @flushed.to_sgr(fallback: true)
      @queue.clear
      return self if sgr.empty?
      @got_sgr = true
      @out << CSI << sgr << ?m
      self
    end

    def emit!
      return @out if @out.frozen?     # already emitted
      @out << CSI << "0m" if @got_sgr # this replaces the final flush. if no sgr emitted, don't bother resetting
      @out.freeze
    end

    alias to_s emit!


    def pretty_print(pp)
      fmt_layer = ->l{ "   [ %s ] %s" % [l.map{ "%2s" % it.to_s }.join(" "), l.tag] }
      pp.group(1, "#<#{self.class}", ">") do
        pp.breakable
        pp.text "@layers =\n"
        pp.text @layers.map(&fmt_layer).join("\n")
        pp.breakable
        pp.text "@flushed =\n"
        pp.text fmt_layer[@flushed]
        pp.breakable
        pp.text "@queue = "
        pp.pp @queue
        pp.breakable
        pp.text "@out = "
        pp.pp @out
      end
    end

  end
end
