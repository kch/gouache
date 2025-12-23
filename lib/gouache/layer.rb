class Gouache

  class Layer < Array
    class LayerRange
      attr :label, :index, :off

      def initialize(xs, label:, index:)
        @label  = label
        @index  = index
        @off    = xs.last
        @ranges = xs.map{ Range === it ? it : it..it }
      end

      def [](x) = @ranges.any?{ it.include? x }
    end

    RANGES = { # ends as [LayerRange, ...] using the hash values; keys get used for label
      fg:        [30..39, 90..97, 39],   # fg
      bg:        [40..49, 100..107, 49], # bg
      italic:    [ 3, 23],               # italic
      blink:     [ 5, 25],               # blink
      inverse:   [ 7, 27],               # inverse
      hidden:    [ 8, 28],               # hidden
      strike:    [ 9, 29],               # strike
      overline:  [53, 55],               # overline
      underline: [ 4, 21, 24],           # underline, double_underline
      bold:      [ 1, 22],               # bold
      dim:       [ 2, 22],               # dim
    }.zip(0..).map do |(k, xs), i|
      LayerRange.new xs, index: i, label: k
    end

    def RANGES.for(x) = filter_map{|r| r.index if r[x] }.then{ it if it.any? }

    BASE = new(RANGES.map(&:off)).freeze

    # special handling for dim/bold
    # dim/bold turn on independently but are both turned off by 22
    # off code goes first so any on code actually applies
    def self.prepare_sgr(xs) = xs.compact.uniq.then{ [*it.delete(22), *it] }

    def self.empty = new(RANGES.length, nil)

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
