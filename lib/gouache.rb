require_relative "gouache/base"
require_relative "gouache/layer"
require_relative "gouache/layer_stack"
require_relative "gouache/stylesheet"

class Gouache
  WRAP_OPEN  = "\e]971;1\e\\"
  WRAP_CLOSE = "\e]971;2\e\\"

  class << self
    def scan_sgr(s) = s.scan(/([34]8;(?:5;\d+|2(?:;\d+){3}))|(\d+)/).map{|s,d| s ? s : d.to_i }
  end

end
