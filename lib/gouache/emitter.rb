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
      @got_sgr  = false          # did we emit sgr at all? used to determine if reset in the end
      @out      = +""
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
      if @enabled && @eachline && s.include?(@eachline) && (sgr = @layers.top.diff(@layers.base)).any?
        emit_each_line s, sgr
      else
        @out << s
      end
      self
    end

    private def emit_each_line(s, sgrs)
      ss    = StringScanner.new(s)
      sgr   = Layer.from(sgrs).to_sgr(fallback: true)
      sgr   = [CSI, sgr, ?m].join
      reset = [CSI, "0m"].join
      sepla = /(?=#{Regexp.escape @eachline})/
      sep   = /(?:#{Regexp.escape @eachline})+/
      while line = ss.scan_until(sepla)
        @out << line
        @out << reset
        @out << ss.scan(sep)
        @out << sgr unless ss.eos? # will enqueue instead below
      end
      if ss.eos?
        @got_sgr = false        # already emitted 0m, this prevents the extra 0 at emit!
        @flushed = @layers.base # we sent 0 so reset flushed
        enqueue sgrs            # enqueue the sgrs we didn't emit so they get consolidated on next flush
      else
        @out << ss.rest
      end
    end

    private def flush
      return self unless @enabled
      return self unless @queue.any?
      @flushed = Layer.from Layer.from(@queue).diff(@flushed) # just the diffs for sgr
      sgr = @flushed.to_sgr(fallback: true)                   # use diff layer to emit sgr with fallback
      @flushed = @layers.top.overlay @flushed                 # full layer for next diff
      @queue.clear
      return self if sgr.empty?
      @got_sgr = true
      @out << CSI << sgr << ?m
      self
    end

    def emit!
      return @emitted if @emitted
      @out << CSI << "0m" if @got_sgr # this replaces the final flush. if no sgr emitted, don't bother resetting
      @emitted, @out = @out, nil
      @emitted
    end

    alias to_s emit!

  end
end
