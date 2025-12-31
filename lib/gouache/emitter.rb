# frozen_string_literal: true

require_relative "layer_stack"
require_relative "stylesheet"

class Gouache
  class Emitter

    def initialize(instance:)
      @ss       = instance.stylesheet # stylesheet
      @enabled  = instance.enabled?
      @eachline = instance.eachline
      @layers   = LayerStack.new # each tag or bare sgr emitted generates a layer
      @flushed  = @layers.base   # keep layer state after each flush so next flush can diff against it
      @queue    = []             # accumulate sgr params to emit until we have text to style (we collapse to minimal set then)
      @out      = +""
      @el_sepla = /(?=#{Regexp.escape @eachline})/  if @eachline # lookahead for eachline separator
      @el_sep   = /(?:#{Regexp.escape @eachline})+/ if @eachline # one or more eachline separators
      # special rule _base applies to all
      enqueue @layers.diffpush @ss.layers[:_base], @ss.effects[:_base] if @ss.tag? :_base
    end

    def enqueue(sgr)       = (@queue << sgr; self)
    def open_tag(tag)      = enqueue @layers.diffpush(@ss.layers[tag], @ss.effects[tag], tag: tag)
    def begin_sgr          = enqueue @layers.diffpush(nil, tag: :@@sgr)
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
      if @enabled && @eachline && s.include?(@eachline) && @layers.top != @layers.base
        emit_each_line s
      else
        @out << s
      end
      self
    end

    private def emit_each_line(s)
      ss  = StringScanner.new(s)
      while line = ss.scan_until(@el_sepla)
        self << line
        begin_sgr.push_sgr "0"
        self << ss.scan(@el_sep)
        end_sgr
      end
      self << ss.rest unless ss.eos?
    end

    private def flush
      return self unless @enabled
      return self unless @queue.any?
      @flushed = Layer.from Layer.from(@queue).diff(@flushed) # just the diffs for sgr
      sgr = @flushed.to_sgr(fallback: true)                   # use diff layer to emit sgr with fallback
      @flushed = @layers.top.overlay @flushed                 # full layer for next diff
      @queue.clear
      return self if sgr.empty?
      sgr = ?0 if @flushed == @layers.base
      @out << CSI << sgr << ?m
      self
    end

    def emit!
      return @emitted if @emitted
      @out << CSI << "0m" if @flushed != @layers.base # this replaces the final flush. if no sgr emitted, don't bother resetting
      @emitted, @out = @out, nil
      @emitted
    end

    alias to_s emit!

  end
end
