require_relative "gouache/base"
require_relative "gouache/layer"
require_relative "gouache/layer_stack"
require_relative "gouache/stylesheet"
require_relative "gouache/emitter"

class Gouache
  OSC        = "\e]"
  CSI        = "\e["
  ST         = "\e\\"
  CODE       = "971"
  WRAP_OPEN  = [OSC, CODE, 1, ST].join
  WRAP_CLOSE = [OSC, CODE, 2, ST].join

  attr :rules

  class << self
    def scan_sgr(s) = s.scan(/([34]8;(?:5;\d+|2(?:;\d+){3}))|(\d+)/).map{|s,d| s ? s : d.to_i }
  end

  def initialize(styles:{}, io:nil, enabled:nil, **kvstyles)
    @io = io
    @enabled = enabled
    @rules = Stylesheet::BASE.merge(styles, kvstyles)
  end

end
