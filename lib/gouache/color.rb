# frozen_string_literal: true

require_relative "color_utils"
require_relative "term"
require_relative "utils"

class Gouache
  class Color
    using RegexpWrap  # enable .w below. wrap it in \A\z

    FG = 38      # foreground role
    BG = 48      # background role
    UL = 58      # underline color
    UNDERLINE_COLOR = UL # for layer proxy effects code
    ROLE = RangeUnion.new FG, BG, UL
    I8 = 0..255  # 8bit int range, for 256 colors and rgb channels
    IC = 0..5    # 216 color cube channel range
    RU_BASIC = RangeUnion.new 39, 49, 59, 30..37, 40..47, 90..97, 100..107 # sgr basic ranges
    RX_BASIC = / (?: 3|4|9|10 ) [0-7] | [345]9              /x.w # sgr basic ranges as string
    D8       = / 1?\d?\d | 2[0-4]\d | 25[0-5]               /x   # 0..255 string
    RX_256   = / ([345]8) ; 5 ; (#{D8})                     /x.w # sgr 256 color
    RX_RGB   = / ([345]8) ; 2 ; (#{D8}) ; (#{D8}) ; (#{D8}) /x.w # sgr truecolor
    RX_HEX   = / \#? (\h\h) (\h\h) (\h\h)                   /x.w # hex syntax for truecolor

    def initialize(**kva)
      # very unforgiving as public use
      case kva
      in sgr: 39 | 49 | 59 | 30..37 | 40..47 | 90..97 | 100..107 => n then @sgr_basic = n
      in sgr: RX_BASIC => s                                      then @sgr_basic = s.to_i
      in sgr: RX_256   => s                                      then @sgr = s; @role, @_256 = $~[1..].map(&:to_i)
      in sgr: RX_RGB   => s                                      then @sgr = s; @role, *@rgb = $~[1..].map(&:to_i)
      in role: ROLE => rl, rgb: [I8, I8, I8] => rgb              then @role = rl; @rgb = rgb
      in role: ROLE => rl, rgb: RX_HEX                           then @role = rl; @rgb = $~[1..].map{it.to_i(16)}
      in role: ROLE => rl, oklch: [0..1, 0.., Numeric] => lch    then @role = rl; @oklch = lch
      in role: ROLE => rl, gray: 0..23 => gray                   then @role = rl; @_256 = 232 + gray
      in role: ROLE => rl, cube: [IC => r, IC => g, IC => b]     then @role = rl; @_256 = 16 + 36*r + 6*g + b
      in __private: [rl, sgr, _256, rgb, oklch]                  then @role, @sgr_basic, @_256, @rgb, @oklch = rl, sgr, _256, rgb, oklch
      else raise ArgumentError, kva.inspect
      end
      raise ArgumentError, kva.inspect unless @role in ROLE | nil
    end

    def self.maybe_color(sgr, &b)
      return sgr unless sgr in RU_BASIC | RX_BASIC | RX_256 | RX_RGB | Color
      color = Color === sgr ? sgr : Color.sgr(sgr)
      color.then(&(b||:itself))
    end

    private_class_method def self.parse_rgb(args)
      case args
      in [ I8 => r, I8 => g, I8 => b ] then [r,g,b]
      in [[I8 => r, I8 => g, I8 => b]] then [r,g,b]
      in [RX_HEX]                      then $~[1..].map{it.to_i(16)}
      else raise ArgumentError, args.inspect
      end
    end

    # constructors for styles
    def self.sgr(sgr)          = new(sgr:)
    def self.ansi(sgr)         = new(sgr:)
    def self.rgb(*rgb)         = new(role: FG, rgb: parse_rgb(rgb))
    def self.on_rgb(*rgb)      = new(role: BG, rgb: parse_rgb(rgb))
    def self.over_rgb(*rgb)    = new(role: UL, rgb: parse_rgb(rgb))
    def self.hex(hs)           = new(role: FG, rgb: hs)
    def self.on_hex(hs)        = new(role: BG, rgb: hs)
    def self.over_hex(hs)      = new(role: UL, rgb: hs)
    def self.cube(r,g,b)       = new(role: FG, cube: [r,g,b])
    def self.on_cube(r,g,b)    = new(role: BG, cube: [r,g,b])
    def self.over_cube(r,g,b)  = new(role: UL, cube: [r,g,b])
    def self.gray(n)           = new(role: FG, gray: n)
    def self.on_gray(n)        = new(role: BG, gray: n)
    def self.over_gray(n)      = new(role: UL, gray: n)
    def self.oklch(l,c,h)      = new(role: FG, oklch: [l,c,h])
    def self.on_oklch(l,c,h)   = new(role: BG, oklch: [l,c,h])
    def self.over_oklch(l,c,h) = new(role: UL, oklch: [l,c,h])

    def role
      @role || case @sgr_basic
      in /\A38;/ | 39 | 30..37 | 90..97   then FG
      in /\A48;/ | 49 | 40..47 | 100..107 then BG
      in /\A58;/ | 59                     then UL
      end
    end

    def rgb
      @rgb ||= case
      when @oklch then ColorUtils.srgb8_from_oklch @oklch
      when @_256  then Term.colors[@_256]
      when (n = @sgr_basic)
        case n
        in 39 | 59  then Term.fg_color                # fg default, underline default color
        in 49       then Term.bg_color                # bg default
        in 30..37   then Term.colors[n - 30]          # fg basic color
        in 40..47   then Term.colors[n - 30 - 10]     # bg basic color
        in 90..97   then Term.colors[n - 90 + 8]      # fg bright color
        in 100..107 then Term.colors[n - 90 - 10 + 8] # bg bright color
        end
      else raise
      end
    end

    def oklch = @oklch || ColorUtils.oklch_from_srgb8(rgb)

    def sgr
      @sgr ||= case
      when @oklch     then [role, 2, *rgb]*?;
      when @rgb       then [role, 2, *rgb]*?;
      when @_256      then [role, 5, @_256]*?;
      when @sgr_basic then @sgr_basic
      else raise
      end
    end

    def _256 = @_256 || Term.nearest256(rgb)

    def basic
      return 59 if role == UL
      return @sgr_basic if @sgr_basic
      i = Term.nearest16(rgb)     # get the nearest to rgb
      x =  30 + i                 # go to 30 range for system colors
      x += 60 - 8 if i > 7        # jump to 90 range for bright (≥8), -offset
      x += 10 if role == 48       # jump to background ranges if bg
      x                           # a plain basic color sgr
    end

    def to_sgr(fallback: false)
      return sgr unless fallback
      fallback = Term.color_level if fallback == true # allow passing the fallback level explicity or true to determine from Term
      case [fallback, role]
      in :truecolor, _ then sgr
      in :_256, _      then (!@_256 && !@rgb && !@okkch && @sgr_basic) || [role, 5, @_256 || _256]*?;
      in :basic, UL    then @sgr_basic || [role, 5, Term.nearest16(rgb)]*?;
      in :basic, _     then basic
      end
    end

    def to_s(...) = to_sgr(...).to_s

    def change_role(new_role)
      return self unless new_role != role
      sgr_basic = @sgr_basic + { FG => -10, BG => 10 }[new_role] if @sgr_basic && new_role != UL
      sgr_basic = UL if @sgr_basic in FG | UL && new_role == UL
      rgb_ = @rgb
      rgb_ = rgb if new_role == UL && ![@_256, @rgb, @oklch].any? && sgr_basic != UL
      Color.new __private: [new_role, sgr_basic, @_256, rgb_, @oklch]
    end

    def self.merge(*colors) = colors.group_by(&:role).transform_values{|cs| cs.inject(&:merge) }.values_at(FG, BG, UL)

    def merge(other)
      raise ArgumentError, "different roles" if role != other.role
      merge_vars = ->{ [@role, @sgr_basic, @_256, @rgb, @oklch] }
      Color.new __private: merge_vars[].zip(other.instance_exec(&merge_vars)).map{ _1 || _2 }
    end

    def to_i = sgr.to_i

    def apply_deltas(xs, ds)
      raise ArgumentError unless ds in [Numeric | [Numeric], Numeric | [Numeric], Numeric | [Numeric]]
      xs.zip(ds).map{|x,d| (d in [d_]) ? d_ : x + d }
    end

    def oklch_shift(*ds)
      l, c, h = apply_deltas(oklch, ds)
      Color.new role:, oklch: [l.clamp(0.0, 1.0), [0.0, c].max, h]
    end

    def rgb_shift(*ds)
      Color.new role:, rgb: apply_deltas(rgb, ds).map{ it.clamp(0, 255).round }
    end

    def == x
      case x
      in Color   then sgr == x.sgr
      in Integer then sgr == x
      in String  then sgr.to_s == x
      else super
      end
    end

  end
end
