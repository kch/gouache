require_relative "layer_stack"
require_relative "stylesheet"

class Gouache
  class Emitter

    def initialize(instance:)
      @tags    = []             # used for sanity checking so sgr doesn't cross tag boundaries, can't close unopen tag, etc
      @rules   = instance.rules # stylesheet
      @layers  = LayerStack.new # each tag or bare sgr emitted generates a layer
      @flushed = @layers.base   # keep layer state after each flush so next flush can diff against it
      @queue   = []             # accumulate sgr params to emit until we have text to style (we collapse to minimal set then)
      @got_sgr = false          # did we emit sgr at all? used to determine if reset in the end
      @out     = +""
    end

    def open_tag(tag)
      raise "open_tag called with sgr on top of stack" if @tags.size > 0 && @tags.last.nil?
      @tags << tag
      @queue << @layers.diffpush(@rules[tag], tag)
      self
    end

    def close_tag
      raise "close_tag called without open tag on top of stack" if @tags.pop.nil?
      @queue << @layers.diffpop
      self
    end

    def push_sgr(sgr_text)
      @tags << nil
      @queue << @layers.diffpush(Layer.from Gouache.scan_sgr sgr_text)
      self
    end

    def pop_sgr
      raise "pop_sgr called on empty stack" if @tags.empty?
      raise "pop_sgr called with open tag on top of stack" unless @tags.pop.nil?
      @queue << @layers.diffpop_until_tag
      self
    end

    def << s
      s = s.to_s
      return self if s.empty?
      flush
      @out << s
      self
    end

    private def flush
      return self unless @queue.any?
      sgr = Layer.from(@queue).diff(@flushed)
      @flushed = Layer.from(sgr)
      @queue.clear
      return self unless sgr.any?
      @got_sgr = true
      @out << CSI << sgr*?; << ?m
      self
    end

    def emit!
      return @out if @out.frozen?     # already emitted
      @out << CSI << "0m" if @got_sgr # this replaces the final flush. if no sgr emitted, don't bother resetting
      @out.freeze
    end

    alias to_s emit!

  end
end
