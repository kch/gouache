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
    D8           = Color::D8
    D24          = /1?\d|2[0-3]/
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

    private def compute_decl(x)
      Layer.from _compute_decl(x)
    end

    private def _compute_decl(x)
      role = ->{ { on: 48, over: 58, nil => 38 }[$1&.chomp(?_)&.to_sym] }
      case x
      in nil          then []
      in Proc         then x
      in Color        then x
      in Layer        then x
      in Symbol       then compute_rule(x)
      in Array        then x.flat_map{ _compute_decl it }.partition{ Color === it }
                            .then{|cs,rs| [*Color.merge(*cs).flatten.compact, *rs] }
      in RU_BASIC     then Color.sgr x
      in RX_BASIC     then Color.sgr x
      in RX_256       then Color.sgr x
      in RX_RGB       then Color.sgr x
      in RX_FN_HEX    then Color.new role: role[], rgb: $2
      in RX_FN_RGB    then Color.new role: role[], rgb: $~[2..].map(&:to_i)
      in RX_FN_CUBE   then Color.new role: role[], cube: x.scan(/\d/).map(&:to_i)
      in RX_FN_GRAY   then Color.new role: role[], gray: $2.to_i
      in RX_FN_256    then Color.sgr [role[], 5, $2]*?;
      in RU_SGR_NC    then x
      in RX_INT       then _compute_decl(x.to_i)
      in RX_SGR       then Gouache.scan_sgr(x).map{ _compute_decl it }
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

    def tag?(key) = @layer_map.key?(key.to_sym)
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
