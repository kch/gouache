# frozen_string_literal: true

class Gouache
  class LayerProxy

    Layer::RANGES.each do |k, r|
      if k in :fg | :bg | :underline_color
        define_method(k) { Color.maybe_color @layer[r.index] }
        define_method("#{k}=") do |v|
          @layer[r.index] = Color.maybe_color(v){ it.change_role(Color.const_get(k.to_s.upcase)) }
        end
      else # not fg bg:
        define_method("#{k}=") {|v| @layer[r.index] = v ? r.on : r.off }
        if k != :underline
          define_method("#{k}?") { not @layer[r.index] in nil | ^(r.off) }
        else # is underline:
          define_method(:double_underline=) { @layer[r.index] = it ? 21 : r.off }
          define_method(:underline?)        { @layer[r.index] ==  4 }
          define_method(:double_underline?) { @layer[r.index] == 21 }
        end # if k underline
      end # if k fg bg
    end # RANGES.each

    def initialize(layer) = (@layer = layer)
    def __layer = @layer

  end # LayerProxy
end # Gouache
