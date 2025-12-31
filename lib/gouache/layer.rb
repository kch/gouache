# frozen_string_literal: true

require_relative "utils"
require_relative "color"

class Gouache

  class Layer < Array

    class LayerRange < RangeUnion
      attr :label, :index, :off, :on

      def initialize(xs, label:, index:)
        @label = label
        @index = index
        @off   = xs.last
        @on    = xs.first if xs.first.is_a? Integer
        super(*xs)
        freeze
      end
    end

    RANGES = { # ends as { k: LayerRange, ... }; keys get used for label too
      fg:              [30..39, 90..97, 39],
      bg:              [40..49, 100..107, 49],
      underline_color: [58, 59], # affects underline + double_underline
      italic:          [ 3, 23],
      blink:           [ 5, 25],
      inverse:         [ 7, 27],
      hidden:          [ 8, 28],
      strike:          [ 9, 29],
      overline:        [53, 55],
      underline:       [ 4, 21, 24], # underline + double_underline
      bold:            [ 1, 22],
      dim:             [ 2, 22],
    }.zip(0..).to_h do |(k, xs), i|
      [k, LayerRange.new(xs, index: i, label: k)]
    end

    # return array of RANGE indices that cover sgr code x
    def RANGES.indices_for(x) = values.filter_map{|r| r.index if r.member? x }.then{ it if it.any? }
    RANGES.freeze

    BASE = new(RANGES.values.map{ Color.maybe_color it.off }).freeze

    # transforms xs into a valid array of sgr codes
    # special handling for dim/bold:
    # - dim/bold turn on independently but are both turned off by 22
    # - so we move 22 in front, off code goes first so any on code that follows actually applies
    # also convert Color to sgr
    def self.prepare_sgr(xs, fallback: false)
      xs = xs.compact.uniq
      sgr22 = xs.delete(22)
      xs.map!{ it.respond_to?(:to_sgr) ? it.to_sgr(fallback:) : it }
      [*sgr22, *xs]
    end

    def self.empty = new(RANGES.size, nil)

    # create a new layer from the given sgr codes or Color objs
    def self.from(*sgr_codes)
      layer = empty
      sgr_codes.flatten.each do |sgr|
        case sgr
        in nil
        in 0 then layer.replace BASE
        in Color | String | Integer
          RANGES.indices_for(sgr.to_i)&.each{|i| layer[i] = sgr }
        end
      end
      layer
    end

    # return a new layer with 'top' applied on top of 'self'
    def overlay(top)
      case top
      in nil   then overlay Layer.empty
      in Layer then Layer.new zip(top).map{ _2 || _1 }
      in _     then raise TypeError, "must be a Layer"
      end
    end

    # return array of sgr codes to turn on self after other
    def diff(other)
      # special case: last 2 elems are bold/dim, we skip them here and handle next
      diff = self[...-2].zip(other[...-2]).filter_map{|a,b| a if a != b }

      # compare dim/bold as unit as both are turned off by SGR 22
      bd_old = other[-2..]
      bd_new = self[-2..]
      diff.concat case [bd_old, bd_new]
      in ^bd_new  , ^bd_old  then []                 # same, no change
      in [ _,   _],[nil,nil] then []                 # falltrhough, no change
      in [ _,   _], [22, 22] then [22]               # all off
      in [nil,nil], [ _,  _] then bd_new - [nil]     # maybe something on
      in [22,  22], [ _,  _] then bd_new - [nil, 22] # maybe something on
      in [ _,   _], [ 1,  2] then [1, 2] - bd_old    # all on
      in [ _,   2], [ 1,nil] then [1, 2] - bd_old    # all on
      in [ 1,   _], [nil, 2] then [1, 2] - bd_old    # all on
      in [ _,   2], [ 1, 22] then [22, 1]            # (bold?)dim -> bold
      in [ 1,   _], [22,  2] then [22, 2]            # bold(dim?) -> dim
      end
    end

    # return array of codes to emit for layer
    def to_sgr(fallback: false) = self.class.prepare_sgr(self, fallback:)*?;

  end
end
