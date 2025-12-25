# frozen_string_literal: true
require_relative "base"
require_relative "layer"
require_relative "color"
require_relative "utils"

class Gouache
  class Stylesheet
    attr :layer_map

    def initialize styles, base:
      raise TypeError unless base in Stylesheet | nil
      @layer_map = base&.then{ it.layer_map.dup } || {} # styles computed into sgr code seqs spread into Layer instances for overlaying
      @styles    = styles&.dup || {}                    # hash with declarations in many formats; will clear this as we compute rules
      @sels      = []                                   # selector stack to avoid circular refs
      @styles.transform_keys!(&:to_sym)
      compute_rule(@styles.first.first) until @styles.empty?
    end

    def merge(*styles) = self.class.new(styles.inject(&:merge), base: self)

    using RegexpWrap  # enable .w below. wrap it in \A\z
    D8           = /1?\d?\d|2[0-4]\d|25[0-5]/
    D24          = /1?\d|2[0-3]/
    RX_INT       = /(?:#{D8})/.w
    RX_SGR       = /[\d;]+/.w
    RX_SEL       = /[a-z]\w*[?!]?/i.w
    RU_BASIC     = RangeUnion.new 39, 49, 30..37, 40..47, 90..97, 100..107 # sgr basic ranges
    RX_BASIC     = / (?: 3|4|9|10 ) [0-7] | [34]9  /x.w                    # same as above but for strings
    RU_SGR_NC    = RangeExclusion.new 0..107, RU_BASIC, 38, 48             # no-color, valid SGRs
    RX_EXT_COLOR = /([34]8) ; (?: 5; (#{D8}) | 2; (#{D8}) ; (#{D8}) ; (#{D8}) )/x.w
    RX_FN_CUBE   = /(on)?#[0-5]{3}/.w
    RX_FN_HEX    = /(on)?#(\h{6})/.w
    RX_FN_RGB    = /(on_)? rgb  \(\s* (#{D8})  \s*,\s* (#{D8}) \s*,\s* (#{D8}) \s*\)/x.w
    RX_FN_256    = /(on_)? 256  \(\s* (#{D8})  \s* \)/x.w
    RX_FN_GRAY   = /(on_)? gray \(\s* (#{D24}) \s* \)/x.w

    private def compute_decl(x)
      role = ->{ $1 ? 48 : 38 }
      Layer.from case x
      in nil          then []
      in Color        then x
      in Layer        then x
      in Symbol       then compute_rule(x)
      in Array        then x.flat_map{ compute_decl it }.partition{ Color === it }.then{|cs,rs| [*Color.merge(*cs).flatten.compact, *rs] }
      in RU_BASIC     then Color.sgr x
      in RX_BASIC     then Color.sgr x
      in RX_EXT_COLOR then Color.sgr x
      in RX_FN_HEX    then Color.new role: role[], rgb: $2
      in RX_FN_RGB    then Color.new role: role[], rgb: $~[2..].map(&:to_i)
      in RX_FN_CUBE   then Color.new role: role[], cube: x.scan(/\d/).map(&:to_i)
      in RX_FN_GRAY   then Color.new role: role[], gray: $2.to_i
      in RX_FN_256    then Color.sgr [role[], 5, $2]*?;
      in RU_SGR_NC    then x
      in RX_INT       then compute_decl(x.to_i)
      in RX_SGR       then Gouache.scan_sgr(x).map{ compute_decl it }
      in RX_SEL       then compute_rule(x.to_sym)
      end
    end

    private def compute_rule(sym)
      return @layer_map[sym] if @layer_map.key?(sym) && !@styles.key?(sym)
      raise "circular reference for '#{sym}'" if @sels.member? sym
      @sels << sym
      @layer_map[sym] = compute_decl(@styles.delete sym)
      @sels.delete sym
      @layer_map[sym]
    end

    def key?(key) = @layer_map.key?(key.to_sym)
    def [](tag)   = @layer_map[tag.to_sym]

    # for inspection purposes mainly
    def tags = @layer_map.keys
    def to_h
      @layer_map.transform_values do |decl|
        decl.compact.uniq.map do |slot|
          next slot.to_sgr if slot.is_a? Color
          slot
        end.then{ it.size == 1 ? it[0] : it }
      end
    end

    BASE = new BASE_STYLES, base: nil
  end
end
