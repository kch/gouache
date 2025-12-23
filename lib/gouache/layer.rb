class Gouache

  class Layer < Array
    class LayerRange
      attr :label, :index, :off

      def initialize(xs, label:, index:)
        @label  = label
        @index  = index
        @off    = xs.last
        @ranges = xs.map{ Range === it ? it : it..it }
        freeze
      end

      def member?(x) = @ranges.any?{ it.member? x }
      alias === member?
    end

    RANGES = { # ends as { k: LayerRange, ... }; keys get used for label too
      fg:        [30..39, 90..97, 39],
      bg:        [40..49, 100..107, 49],
      italic:    [ 3, 23],
      blink:     [ 5, 25],
      inverse:   [ 7, 27],
      hidden:    [ 8, 28],
      strike:    [ 9, 29],
      overline:  [53, 55],
      underline: [ 4, 21, 24], # underline + double_underline
      bold:      [ 1, 22],
      dim:       [ 2, 22],
    }.zip(0..).to_h do |(k, xs), i|
      [k, LayerRange.new(xs, index: i, label: k)]
    end

    # return array of RANGE indices that cover sgr code x
    def RANGES.for(x) = values.filter_map{|r| r.index if r.member? x }.then{ it if it.any? }
    RANGES.freeze

    BASE = new(RANGES.values.map(&:off)).freeze

    # special handling for dim/bold
    # dim/bold turn on independently but are both turned off by 22
    # off code goes first so any on code actually applies
    def self.prepare_sgr(xs) = xs.compact.uniq.then{ [*it.delete(22), *it] }

    def self.empty = new(RANGES.size, nil)

    # create a new layer from the given sgr codes
    def self.from(*sgr_codes)
      layer = empty
      sgr_codes.flatten.each do |sgr|
        case sgr
        in 0 then layer.replace BASE
        in _ then RANGES.for(sgr.to_i)&.each{|i| layer[i] = sgr }
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

    # return sgr codes to turn on self after other
    def diff(other)
      # special case: last 2 elems are bold/dim, compare as unit as both are turned off by SGR 22
      group22 = ->a{ [*a[...-2], a[-2..]] }  # => [..., [bold, dim]]
      diff = group22[self].zip(group22[other]).filter_map{|a,b| a if a != b }
      diff[-1, 1] = self.class.prepare_sgr diff[-1] if diff[-1] in Array
      diff
    end

    # return array of codes to emit for layer
    def to_sgr = self.class.prepare_sgr self

  end
end
