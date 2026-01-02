# frozen_string_literal: true

require_relative "base"
require_relative "color"
require_relative "utils"

class Gouache
  class Stylesheet
    attr :styles, :layers, :effects

    def initialize styles, base:
      raise TypeError unless base in Stylesheet | nil
      base_styles = (base&.styles||{}).transform_keys(&:to_sym)
      styles      = (styles||{}).transform_keys(&:to_sym)
      @styles     = base_styles.merge(styles){|k,a,b| [*a, *b] }
      @computed   = Set[]  # selectors already computed
      @computing  = Set[]  # selector stack to avoid circular refs
      @effects    = Hash.new{|h,k| compute_rule(k.to_sym); h[k.to_sym] }  # computes on-demand and merges styles from base when doing it
      @layers     = Hash.new{|h,k| compute_rule(k.to_sym); h[k.to_sym] }  # same
    end

    def merge(*styles) = self.class.new(styles.inject(&:merge), base: self)

    using RegexpWrap  # enable .w below. wrap it in \A\z
    D8           = Gouache::D8  # 0..255 string
    D24          = /1?\d|2[0-3]/
    NNF          = /\.\d+|\d+(?:\.\d+)?/ # non-negative float
    RX_INT       = /(?:#{D8})/.w
    RX_SGR       = /[\d;]+/.w
    RX_SEL       = /[a-z]\w*[?!]?/i.w
    RU_BASIC     = Color::RU_BASIC
    RX_BASIC     = Color::RX_BASIC
    RX_256       = Color::RX_256
    RX_RGB       = Color::RX_RGB
    RU_SGR_NC    = RangeExclusion.new 0..107, RU_BASIC, 38, 48, 58 # non-color, likely valid SGRs
    RX_FN_CUBE   = /(on|over)?#[0-5]{3}/.w
    RX_FN_HEX    = /(on|over)?#(\h{6})/.w
    RX_FN_RGB    = /(on_|over_)? rgb  \(\s* (#{D8})  \s*,\s* (#{D8}) \s*,\s* (#{D8}) \s*\)/x.w
    RX_FN_256    = /(on_|over_)? 256  \(\s* (#{D8})  \s* \)/x.w
    RX_FN_GRAY   = /(on_|over_)? gray \(\s* (#{D24}) \s* \)/x.w
    RX_FN_OKLCH  = /(on_|over_)? oklch\(\s* (#{NNF}) \s*,\s* (#{NNF}(?:max)?|max) \s*,\s* (#{NNF}) \s*\)/x.w

    private def compute_decl(x)
      role = ->{ { on: 48, over: 58, nil => 38 }[$1&.chomp(?_)&.to_sym] }
      case x
      in nil          then []
      in Proc         then x
      in Color        then x
      in Layer        then raise # technically harmless but if a layer ends up here we did smth wrong
      in Symbol       then compute_rule(x)
      in Array        then x.flat_map{ compute_decl it }
      in RU_BASIC     then Color.sgr x
      in RX_BASIC     then Color.sgr x
      in RX_256       then Color.sgr x
      in RX_RGB       then Color.sgr x
      in RX_FN_HEX    then Color.new role: role[], rgb: $2
      in RX_FN_RGB    then Color.new role: role[], rgb: $~[2..].map(&:to_i)
      in RX_FN_CUBE   then Color.new role: role[], cube: x.scan(/\d/).map(&:to_i)
      in RX_FN_GRAY   then Color.new role: role[], gray: $2.to_i
      in RX_FN_256    then Color.sgr [role[], 5, $2]*?;
      in RX_FN_OKLCH  then Color.new role: role[], oklch: $~[2..].map{|s| s =~ /max/ ? s : s.to_f }
      in RU_SGR_NC    then x
      in RX_INT       then compute_decl(x.to_i)
      in RX_SGR       then Gouache.scan_sgr(x).map{ compute_decl it }
      in RX_SEL       then compute_decl(x.to_sym)
      end
    end

    private def compute_rule(sym)
      return @styles[sym] if @computed.member?(sym)
      raise "circular reference for '#{sym}'" if @computing.member? sym
      @computing << sym
      styles          = [*compute_decl(@styles[sym])]
      @styles[sym]    = styles
      effects, styles = styles.partition{ it in Proc }
      colors, styles  = styles.partition{ it in Color }
      colors          = Color.merge(*colors).flatten.compact
      @layers[sym]    = Layer.from(*colors, *styles)
      @effects[sym]   = effects
      @computing.delete sym
      @computed << sym
      @styles[sym]
    end

    def tag?(key) = @styles.key?(key.to_sym)
    def tags      = @styles.keys

    BASE = new BASE_STYLES, base: nil
  end
end
