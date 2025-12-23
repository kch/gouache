# frozen_string_literal: true
require_relative "base"
require_relative "layer"

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

    using Module.new {
      refine Regexp do
        def w = /\A#{self}\z/ # wrap it in \A\z. tiny helper so below looks more readable
      end
    }

    D256     = /1?\d?\d|2[0-4]\d|25[0-5]/
    D24      = /1?\d|2[0-3]/
    RX_INT   = /(?:#{D256})/.w
    RX_SGR   = /[\d;]+/.w
    RX_HEX8  = /(on)?#[0-5]{3}/.w
    RX_HEX24 = /(on)?#\h{6}/.w
    RX_RGB24 = /(on_)?rgb\(\s*(#{D256})\s*,\s*(#{D256})\s*,\s*(#{D256})\s*\)/.w
    RX_256   = /(on_)?256\(\s*(#{D256})\s*\)/.w
    RX_GRAY  = /(on_)?gray\(\s*(#{D24})\s*\)/.w
    RX_SEL   = /\w+[?!]?/.w

    private def compute_decl(x)
      fbg = ->*a{ (a.empty? ? $1 : a[0]) ? 48 : 38 }
      Layer.from case x
      in nil      then []
      in Layer    then x
      in Array    then x.flat_map{ compute_decl it }
      in Symbol   then compute_rule(x)
      in 1..107   then x
      in RX_INT   then x.to_i
      in RX_SGR   then Gouache.scan_sgr(x)
      in RX_RGB24 then [fbg[], 2, $2, $3, $4]*?;
      in RX_HEX24 then on=$1; x.scan(/\h\h/).map{it.to_i(16)}.then{ [fbg[on], 2, *it]*?; }
      in RX_HEX8  then on=$1; x.scan(/\d/).map(&:to_i).then{|r,g,b| [fbg[on], 5, 16 + 36*r + 6*g + b]*?; }
      in RX_256   then [fbg[], 5, $2]*?;
      in RX_GRAY  then [fbg[], 5, 232 + $2.to_i]*?;
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

    def key?(key) = @layer_map.key?(key.to_sym)

    def [](*sels) = @layer_map.values_at(*sels.flatten.map(&:to_sym)).compact.inject(Layer.empty, &:overlay)

    def to_h = @layer_map.transform_values{ it.compact.uniq.then{ it.size == 1 ? it[0] : it } }

    def tags = @layer_map.keys

    BASE = new BASE_STYLES, base: nil
  end
end
