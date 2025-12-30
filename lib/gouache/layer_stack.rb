# frozen_string_literal: true

require_relative "layer"
require_relative "layer_proxy"

class Gouache

  module LayerTags
    attr_accessor :tag
  end

  class LayerStack < Array
    alias top last
    alias base first
    def base? = size == 1
    def under = self[-2]

    def initialize
      super [Layer::BASE.dup.extend(LayerTags).freeze]
    end

    def diffpush layer, effects=nil, tag:nil
      self << top.overlay(layer)
      top.extend LayerTags
      top.tag = tag
      effects&.each do
        it.arity in 1..2 or raise ArgumentError
        it.(*[top, under].take(it.arity).map{ LayerProxy.new it })
      end
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
