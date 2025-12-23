# frozen_string_literal: true
require_relative "base"
require_relative "layer"
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
    D256     = /1?\d?\d|2[0-4]\d|25[0-5]/
    D24      = /1?\d|2[0-3]/
    RX_INT   = /(?:#{D256})/.w
    RX_SGR   = /[\d;]+/.w
    RX_HEX8  = /(on)?#[0-5]{3}/.w
    RX_HEX24 = /(on)?#\h{6}/.w
    RX_RGB24 = /(on_)?rgb\(\s*(#{D256})\s*,\s*(#{D256})\s*,\s*(#{D256})\s*\)/.w
    RX_256   = /(on_)?256\(\s*(#{D256})\s*\)/.w
    RX_GRAY  = /(on_)?gray\(\s*(#{D24})\s*\)/.w
    RX_COLOR = /(?<role>[34]8);(?:5;(?<n>#{D256})|2;(?<r>#{D256});(?<g>#{D256});(?<b>#{D256}))/.w
    RX_SEL   = /\w+[?!]?/.w

    private def compute_decl(x)
      role = ->*a{ (a.empty? ? $1 : a[0]) ? 48 : 38 }
      Layer.from case x
      in nil      then []
      in Layer    then x
      in Array    then x.flat_map{ compute_decl it }
      in Symbol   then compute_rule(x)
      in 0..107   then x
      in RX_INT   then x.to_i
      in RX_RGB24 then compute_color [role[], 2, $2, $3, $4]*?;
      in RX_HEX24 then on=$1; compute_color x.scan(/\h\h/).map{it.to_i(16)}.then{ [role[on], 2, *it]*?; }
      in RX_HEX8  then on=$1; compute_color x.scan(/\d/).map(&:to_i).then{|r,g,b| [role[on], 5, 16 + 36*r + 6*g + b]*?; }
      in RX_256   then compute_color [role[], 5, $2]*?;
      in RX_GRAY  then compute_color [role[], 5, 232 + $2.to_i]*?;
      in RX_COLOR then compute_color x
      in RX_SGR   then Gouache.scan_sgr(x).map{ compute_decl it }
      in RX_SEL   then compute_rule(x.to_sym)
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

    def compute_color sgr
      RX_COLOR.match(sgr).named_captures(symbolize_names:true) => role:, n:, r:, g:, b: # we always get either n or rgb
      rgb = [r,g,b].map(&:to_i) if r
      n = n&.to_i
      case Term.color_level
      in :truecolor then sgr
      in :_256      then [role, 5, n || Term.nearest256(rgb)]*?;
      in :basic
        rgb ||= Term.colors[n]      # get the rgb for a 256 value, when not rgb already
        i = Term.nearest16(rgb)     # here available_colors is only the basic 16; get the nearest to rgb
        x =  30 + i                 # go to 30 range for system colors
        x += 60 - 8 if i > 7        # jump to 90 range for bright, -offset
        x += 10 if role == "48"     # jump to backgroung ranges if bg
        x                           # a plain basic color sgr
      end
    end

    def key?(key) = @layer_map.key?(key.to_sym)
    def [](tag)   = @layer_map[tag.to_sym]

    # for inspection purposes mainly
    def to_h = @layer_map.transform_values{ it.compact.uniq.then{ it.size == 1 ? it[0] : it } }
    def tags = @layer_map.keys

    BASE = new BASE_STYLES, base: nil
  end
end
