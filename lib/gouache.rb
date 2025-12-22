require_relative "gouache/base"
require_relative "gouache/layer"
require_relative "gouache/layer_stack"
require_relative "gouache/stylesheet"
require_relative "gouache/emitter"
require_relative "gouache/builder"
require_relative "gouache/wrap"

class Gouache
  OSC        = "\e]"
  CSI        = "\e["
  ST         = "\e\\"
  CODE       = "971"
  WRAP_OPEN  = [OSC, CODE, 1, ST].join
  WRAP_CLOSE = [OSC, CODE, 2, ST].join

  attr :rules

  using Wrap

  class << self
    def scan_sgr(s) = s.scan(/([34]8;(?:5;\d+|2(?:;\d+){3}))|(\d+)/).map{|s,d| s ? s : d.to_i }

    def wrap(s) = s.wrap
    alias embed wrap
  end

  def initialize(styles:{}, io:nil, enabled:nil, **kvstyles)
    @io = io
    @enabled = enabled
    @rules = Stylesheet::BASE.merge(styles, kvstyles)
  end

  def method_missing(m, ...)
    Builder::Proxy.for(self, m, ...) || super
  end

  def [](*args, &b)
    if b then call(*args, &b) else Builder.compile(args, instance: self) end
  end

  def call(...)
    raise ArgumentError unless block_given?
    Builder::Proxy.for(self, nil, ...)
  end

  def wrap(s) = s.wrap
  alias embed wrap

end
