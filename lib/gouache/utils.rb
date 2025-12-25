class Gouache

  module RegexpWrap
    refine Regexp do
      def w = /\A#{self}\z/ # wrap it in \A\z
    end
  end

  class RangeUnion
    def initialize *xs
      @ranges = xs.map do |x|
        case x
        in Range   then x
        in Numeric then x..x
        end
      end
    end

    def member? x
      @ranges.any?{ it.member? x }
    end

    alias === member?
  end

end
