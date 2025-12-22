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
  RX_ESC_LA  = /(?=\e)/
  RX_SGR     = /#{Regexp.escape(CSI)}[;\d]*m/
  RX_UNPAINT = Regexp.union RX_SGR, WRAP_OPEN, WRAP_CLOSE

  attr :rules

  class << self
    using Wrap
    def scan_sgr(s) = s.scan(/([34]8;(?:5;\d+|2(?:;\d+){3}))|(\d+)/).map{|s,d| s ? s : d.to_i }
    def unpaint(s)  = s.gsub(RX_UNPAINT, "")
    def wrap(s)     = s.wrap
    alias embed wrap
  end

  def initialize(styles:{}, io:nil, enabled:nil, **kvstyles)
    @io      = io
    @enabled = enabled
    @rules   = Stylesheet::BASE.merge(styles, kvstyles)
  end

  def io         = @io || $stdout
  def enable     = tap{ @enabled = true }
  def disable    = tap{ @enabled = false }
  def enabled?   = @enabled.nil? ? io.tty? : @enabled
  def reopen(io) = tap{ @io = io }

  def puts(*x)   = io.puts(*x.map{  String === it ? repaint(it) : it })
  def print(*x)  = io.print(*x.map{ String === it ? repaint(it) : it })

  def mk_emitter = Emitter.new(instance: self)
  def repaint(s) = enabled? ? mk_emitter.tap{ Builder.safe_emit_sgr(s, emitter: it) }.emit! : unpaint(s)
  def unpaint(s) = self.class.unpaint(s)
  def wrap(s)    = self.class.wrap(s)
  alias embed wrap

  def method_missing(m, ...) = Builder::Proxy.for(self, m, ...) || super
  def [](*args, &b)          = b ? call(args, &b) : Builder.compile(args, instance: self)

  def call(...)
    raise ArgumentError unless block_given?
    Builder::Proxy.for(self, nil, ...)
  end

end
