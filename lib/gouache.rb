# frozen_string_literal: true

require_relative "gouache/version"
require_relative "gouache/base"
require_relative "gouache/layer"
require_relative "gouache/layer_stack"
require_relative "gouache/stylesheet"
require_relative "gouache/emitter"
require_relative "gouache/builder"
require_relative "gouache/wrap"
require_relative "gouache/term"
require_relative "gouache/color"
require_relative "gouache/layer_proxy"
require "forwardable"

class Gouache
  OSC        = "\e]"
  CSI        = "\e["
  ST         = "\e\\"
  CODE       = "971" # meaningless magic number
  WRAP_SEQ   = [OSC, CODE].join
  WRAP_OPEN  = [OSC, CODE, 1, ST].join
  WRAP_CLOSE = [OSC, CODE, 2, ST].join
  RX_ESC_LA  = /(?=\e)/
  RX_SGR     = /#{Regexp.escape(CSI)}[;\d]*m/
  RX_UNPAINT = Regexp.union RX_SGR, WRAP_OPEN, WRAP_CLOSE
  D8         = / 1?\d?\d | 2[0-4]\d | 25[0-5] /x  # 0..255 string
  RX_SGR_SEQ = /(?<=^|;|\[)(?: ( [345]8 ;  (?: 5 ; #{D8} | 2 (?: ; #{D8} ){3} ))  |  (#{D8}) )(?=;|m|$)/x

  attr :rules

  class << self
    using Wrap
    def scan_sgr(s) = s.scan(RX_SGR_SEQ).map{|s,d| s ? s : d.to_i }
    def unpaint(s)  = s.gsub(RX_UNPAINT, "")
    def wrap(s)     = s.wrap
    alias embed wrap

    extend Forwardable
    def_delegators "::Gouache::MAIN", :enable, :disable, :reopen, :enabled?, :puts, :print, :refinement

    def method_missing(m, ...)   = Builder::Proxy.for(MAIN, m, ...) || super
    def [](*args, **styles, &b)  = (styles.empty? ? MAIN : MAIN.dup(styles:))[*args, &b]
    def new(*args, **kvargs, &b) = (go = super and block_given? ? go.(&b) : go)
  end

  def initialize(styles:{}, io:nil, enabled:nil, **kvstyles)
    @io      = io
    @enabled = enabled
    @rules   = Stylesheet::BASE.merge(styles, kvstyles)
  end

  MAIN = new # global instance

  def dup(styles: nil)
    go = self.class.new(io: @io, enabled: @enabled)
    go.instance_variable_set(:@rules, @rules.merge(styles))
    go
  end

  def io         = @io || $stdout
  def enable     = tap{ @enabled = true }
  def disable    = tap{ @enabled = false }
  def enabled?   = !@enabled.nil? ? @enabled : io.tty? && ENV["TERM"] != "dumb"
  def reopen(io) = tap{ @io = io }
  def puts(*x)   = io.puts(*x.map{  printable it })
  def print(*x)  = io.print(*x.map{ printable it })

  private def printable(x)
    return x unless x.is_a? String
    return unpaint(x) unless enabled?
    return repaint(x) if x.include?(WRAP_SEQ)
    return x
  end

  def mk_emitter = Emitter.new(instance: self)
  def repaint(s) = !enabled? ? unpaint(s) : mk_emitter.tap{ Builder.safe_emit_sgr(s, emitter: it) }.emit!
  def unpaint(s) = self.class.unpaint(s)
  def wrap(s)    = self.class.wrap(s)
  alias embed wrap

  def method_missing(m, ...) = Builder::Proxy.for(self, m, ...) || super
  def [](*args, &b)          = b ? call(args, &b) : Builder.compile(args, instance: self)

  def call(...)
    raise ArgumentError unless block_given?
    Builder::Proxy.for(self, nil, ...)
  end

  def refinement
    instance = self
    style_methods = instance.rules.tags
    other_methods = %i[ unpaint repaint wrap ]
    Module.new do
      refine String do
        style_methods.each{|m| define_method(m) { instance[m, self] } unless method_defined? m }
        other_methods.each{|m| define_method(m) { instance.send m, self } unless method_defined? m }
      end
    end
  end

end
