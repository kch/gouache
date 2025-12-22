class Gouache
  module Wrap
    refine String do

      def has_sgr? = match?(/\e\[[;\d]*m/)
      def wrapped? = start_with?(WRAP_OPEN) && end_with?(WRAP_CLOSE)
      def wrap!    = [WRAP_OPEN, self, WRAP_CLOSE].join
      def wrap     = has_sgr? && !wrapped? ? wrap! : self

    end
  end
end
