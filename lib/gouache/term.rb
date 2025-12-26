# frozen_string_literal: true

require "io/console"
require_relative "color_utils"

class Gouache
  module Term
    extend self

    RG_BASIC = (0..15)
    RG_CUBE  = (16..231)
    RG_GRAY  = (232..255)

    ANSI16 = [ # default fallback, xterm defaults
      [0,   0,   0],     # 0 black
      [205, 0,   0],     # 1 red
      [0,   205, 0],     # 2 green
      [205, 205, 0],     # 3 yellow
      [0,   0,   238],   # 4 blue
      [205, 0,   205],   # 5 magenta
      [0,   205, 205],   # 6 cyan
      [229, 229, 229],   # 7 white
      [127, 127, 127],   # 8 bright black
      [255, 0,   0],     # 9 bright red
      [0,   255, 0],     # 10 bright green
      [255, 255, 0],     # 11 bright yellow
      [92,  92,  255],   # 12 bright blue
      [255, 0,   255],   # 13 bright magenta
      [0,   255, 255],   # 14 bright cyan
      [255, 255, 255],   # 15 bright white
      ].freeze

    def rgb8_from_ansi_cube(i)
      raise IndexError unless RG_CUBE.cover?(i)
      n = i - 16
      r = n / 36
      g = (n / 6) % 6
      b = n % 6
      c = ->x { x == 0 ? 0 : 55 + x * 40 }
      [r, g, b].map(&c)
    end

    def rgb8_from_the_grays(g)
      r1 = (0..23)  # 0-based gray index
      r2 = RG_GRAY  # ansi index
      g = g - r2.begin if r2.cover?(g)
      raise IndexError, "#{g}" unless r1.cover?(g)
      [8 + g*10] * 3
    end

    COLORS256 = (
      ANSI16 +
      RG_CUBE.map{ rgb8_from_ansi_cube it } +
      RG_GRAY.map{ rgb8_from_the_grays it }
      ).freeze

    def term_seq(*seq)
      buf = +""
      IO.console.raw do |tty|
        tty << seq.join
        tty.flush
        loop do
          break unless tty.wait_readable(0.05)
          buf << tty.read_nonblock(4096)
        rescue IO::WaitReadable, EOFError
        end
      end
      buf
    end

    OSC_RGB = %r_\e\]\d{1,2}(?:;(\d{1,3}))?;rgb:(\h{2})\h{2}?/(\h{2})\h{2}?/(\h{2})\h{2}?(?:\a|\e\\)_
    def scan_colors(s, len) = s.scan(OSC_RGB).to_h{|k,*rgb| [k&.to_i, rgb.map{ it&.to_i 16 }] }.then{ it.size == len ? it : nil }
    def scan_color(s)  = scan_colors(s, 1).values.first
    def osc(*xs)       = term_seq OSC, xs*?;, ST
    def rgb_for(n)     = scan_color osc(4, n, ??) # currently unused
    def fg_color       = (@fg_color ||= scan_color osc(10, ??))
    def bg_color       = (@bg_color ||= scan_color osc(11, ??))
    def colors         = (@colors   ||= COLORS256.dup.tap{ it[RG_BASIC] = basic_colors }.freeze)
    def basic_colors
      return @basic_colors if @basic_colors
      h = scan_colors(osc(4, *RG_BASIC.zip(Enumerator.produce{??})), RG_BASIC.size)
      @basic_colors = (h ? RG_BASIC.map{ h[it] or raise } : ANSI16.dup).freeze
    end

    def color_level=(level)
      raise ArgumentError unless level in :basic | :_256 | :truecolor | nil
      @color_level = level
    end

    def color_level
      return @color_level if @color_level
      return :truecolor if /truecolor/i =~ ENV["COLORTERM"]
      case ENV["TERM"]
      when /-256color$/                 then :_256
      when /^(xterm|screen|vt100|ansi)/ then :basic
      else :basic # assume basic
      # dumb term is handled by Gouache being disabled entirely
      end
    end

    @@color_indices = {}
    private def nearest_color(rgb, list)
      @@color_indices[rgb] ||= list.zip(0..).sort_by do |color, i|
        ColorUtils.oklab_distance_from_srgb8 rgb, color
      end.first.last # first of sort, last is index
    end

    def nearest16(rgb)  = nearest_color(rgb, basic_colors)
    def nearest256(rgb) = nearest_color(rgb, colors)

  end
end
