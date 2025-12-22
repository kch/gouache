require_relative "layer"

class Gouache

  class LayerStack < Array

    using Module.new {
      refine Layer do
        attr_accessor :tag
      end
    }

    alias top last
    alias base first
    def base? = size == 1
    def under = self[-2]

    def initialize
      super [Layer::BASE]
    end

    def diffpush layer, tag=nil
      self << top.overlay(layer)
      top.tag = tag
      top.freeze
      top.diff(under)
    end

    def diffpop
      return base.to_sgr if base?
      oldpop = pop
      top.diff(oldpop)
    end

    # pops until but not including cond
    def diffpop_until(&cond)
      return [] if cond[self]
      oldtop = top
      pop until base? || cond[self]
      top.diff(oldtop)
    end

  end
end
