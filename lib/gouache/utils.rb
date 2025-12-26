# frozen_string_literal: true

class Gouache

  module RegexpWrap
    refine Regexp do
      def w = /\A#{self}\z/ # wrap it in \A\z
    end
  end

  class RangeExclusion
    def initialize range, *excludes
      @range = range
      @excludes = RangeUnion.new(*excludes)
    end

    def member?(x) = @range.member?(x) && !@excludes.member?(x)
    alias === member?
  end

  class RangeUnion
    def initialize *xs
      @ranges = xs.map do |x|
        case x
        in RangeUnion then x
        in Range      then x
        in Numeric    then x..x
        end
      end
    end

    def member?(x) = @ranges.any?{ it.member? x }
    alias === member?
  end

end
