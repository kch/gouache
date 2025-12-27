# frozen_string_literal: true

require_relative "utils"
require_relative "color"

class Gouache

  class Layer < Array
    attr_accessor :effects

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
      italic:          [ 3, 23],
      blink:           [ 5, 25],
      inverse:         [ 7, 27],
      hidden:          [ 8, 28],
      strike:          [ 9, 29],
      overline:        [53, 55],
      underline:       [ 4, 21, 24], # underline + double_underline
      underline_color: [58, 59],     # affects underline + double_underline
      bold:            [ 1, 22],
      dim:             [ 2, 22],
    }.zip(0..).to_h do |(k, xs), i|
      [k, LayerRange.new(xs, index: i, label: k)]
    end

    # return array of RANGE indices that cover sgr code x
    def RANGES.for(x) = values.filter_map{|r| r.index if r.member? x }.then{ it if it.any? }
    RANGES.freeze

    BASE = new(RANGES.values.map(&:off).tap do |base|
      %i[ fg bg underline_color ].each do |k|
        i = RANGES[k].index
        base[i] = Color.sgr base[i]
      end
    end).freeze

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

    # create a new layer from the given sgr codes
    def self.from(*sgr_codes)
      layer = empty
      effects, sgr_codes = sgr_codes.flatten.partition { it in Proc }
      sgr_codes.each do |sgr|
        case sgr
        in 0 then layer.replace BASE
        in _ then RANGES.for(sgr.to_i)&.each{|i| layer[i] = sgr }
        end
      end
      layer.effects = effects
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

    # return sgr codes to turn on self after other
    def diff(other)
      # special case: last 2 elems are bold/dim, compare as unit as both are turned off by SGR 22
      group22 = ->a{ [*a[...-2], a[-2..]] }  # => [..., [bold, dim]]
      diff = group22[self].zip(group22[other]).filter_map{|a,b| a if a != b }
      diff[-1, 1] = self.class.prepare_sgr diff[-1] if diff[-1] in Array
      diff
    end

    # return array of codes to emit for layer
    def to_sgr(fallback: false) = self.class.prepare_sgr(self, fallback:)*?;

  end
end
