# frozen_string_literal: true

require_relative "test_helper"

class TestLayerStack < Minitest::Test
  def setup
    @stack = Gouache::LayerStack.new
  end

  def test_stack_initialization
    assert_equal 1, @stack.size
    assert_equal Gouache::Layer::BASE, @stack.first
    assert @stack.base?
  end

  def test_stack_aliases
    assert_equal @stack.first, @stack.base
    assert_same @stack.first, @stack.base

    layer = Gouache::Layer.from(1, 31)
    @stack.diffpush(layer)

    assert_equal @stack.last, @stack.top
    assert_same @stack.last, @stack.top
  end

  def test_stack_base_predicate
    assert @stack.base?

    @stack.diffpush(Gouache::Layer.from(1))
    refute @stack.base?

    @stack.diffpop
    assert @stack.base?
  end

  def test_stack_under_method
    # When only base exists, under should be nil
    assert_nil @stack.under

    layer1 = Gouache::Layer.from(1)
    @stack.diffpush(layer1)
    assert_equal @stack.base, @stack.under

    layer2 = Gouache::Layer.from(31)
    @stack.diffpush(layer2)
    assert_equal @stack[-2], @stack.under
  end

  def test_stack_diffpush_simple
    layer = Gouache::Layer.from(4)  # underline

    open_sgr = @stack.diffpush(layer)

    assert_equal 2, @stack.size
    refute @stack.base?
    assert_includes open_sgr, 4
  end

  def test_stack_diffpush_overlay_behavior
    bold = Gouache::Layer.from(1)
    red = Gouache::Layer.from(31)

    @stack.diffpush(bold)
    @stack.diffpush(red)

    # Top should be overlay of BASE + bold + red
    top = @stack.top
    bold_pos = Gouache::Layer::RANGES.for(1).first
    fg_pos = Gouache::Layer::RANGES.for(31).first

    assert_equal 1, top[bold_pos]
    assert_equal 31, top[fg_pos]
  end

  def test_stack_diffpush_freezes_layer
    layer = Gouache::Layer.from(1, 31)
    refute layer.frozen?

    @stack.diffpush(layer)

    assert @stack.top.frozen?
  end

  def test_stack_diffpop_simple
    layer = Gouache::Layer.from(4)  # underline

    @stack.diffpush(layer)
    close_sgr = @stack.diffpop

    assert_equal 1, @stack.size
    assert @stack.base?
    assert_includes close_sgr, 24  # underline reset
  end

  def test_stack_diffpop_on_base_only
    result = @stack.diffpop

    assert_equal Gouache::Layer::BASE.to_sgr, result
    assert_equal 1, @stack.size
    assert @stack.base?
  end

  def test_stack_diffpop_multiple_pops_on_base
    # Multiple pops on base should keep working
    result1 = @stack.diffpop
    result2 = @stack.diffpop

    assert_equal Gouache::Layer::BASE.to_sgr, result1
    assert_equal Gouache::Layer::BASE.to_sgr, result2
    assert_equal 1, @stack.size
    assert @stack.base?
  end

  def test_stack_push_pop_sequence
    bold = Gouache::Layer.from(1)
    red = Gouache::Layer.from(31)
    underline = Gouache::Layer.from(4)

    # Build stack
    @stack.diffpush(bold)
    @stack.diffpush(red)
    @stack.diffpush(underline)
    assert_equal 4, @stack.size

    # Pop back down
    @stack.diffpop
    assert_equal 3, @stack.size
    @stack.diffpop
    assert_equal 2, @stack.size
    @stack.diffpop
    assert_equal 1, @stack.size
    assert @stack.base?
  end

  def test_stack_diffpop_until_with_tagged_layer
    layer1 = Gouache::Layer.from(1)
    layer2 = Gouache::Layer.from(31)
    layer3 = Gouache::Layer.from(4)

    @stack.diffpush(layer1, :test)
    @stack.diffpush(layer2)
    @stack.diffpush(layer3)
    assert_equal 4, @stack.size

    result = @stack.diffpop_until{ it.top.tag }

    # Should pop back to the tagged layer (layer1)
    assert_equal 2, @stack.size
    assert_kind_of Array, result
  end

  def test_stack_diffpop_until_without_tagged_layer
    layer1 = Gouache::Layer.from(1)  # no tag
    layer2 = Gouache::Layer.from(31) # no tag
    layer3 = Gouache::Layer.from(4)  # no tag

    @stack.diffpush(layer1)
    @stack.diffpush(layer2)
    @stack.diffpush(layer3)
    assert_equal 4, @stack.size

    @stack.diffpop_until{ it.top.tag }

    # Should pop all the way to base since no tags
    assert_equal 1, @stack.size
    assert @stack.base?
  end

  def test_stack_diffpop_until_complex_scenario
    # BASE -> tagged1 -> untagged1 -> untagged2 -> tagged2 -> untagged3
    tagged1 = Gouache::Layer.from(1)
    untagged1 = Gouache::Layer.from(31)
    untagged2 = Gouache::Layer.from(4)
    tagged2 = Gouache::Layer.from(2)
    untagged3 = Gouache::Layer.from(32)

    @stack.diffpush(tagged1, :first)
    @stack.diffpush(untagged1)
    @stack.diffpush(untagged2)
    @stack.diffpush(tagged2, :second)
    @stack.diffpush(untagged3)
    assert_equal 6, @stack.size

    # Pop from untagged3 - should go to tagged2
    @stack.diffpop_until{ it.top.tag }
    assert_equal 5, @stack.size

    # Now top is tagged2 - diffpop_until should return early (no pop)
    result = @stack.diffpop_until{ it.top.tag }
    assert_equal 5, @stack.size  # Should stay the same
    assert_equal [], result      # Should return empty array

    # Use regular diffpop to pop the tagged layer
    @stack.diffpop
    assert_equal 4, @stack.size

    # Now pop until tagged1
    @stack.diffpop_until{ it.top.tag }
    assert_equal 2, @stack.size
  end

  def test_stack_diffpop_until_conditional_logic
    # Test early return when top is already tagged
    tagged = Gouache::Layer.from(1)
    @stack.diffpush(tagged, :stop)

    result = @stack.diffpop_until{ it.top.tag }
    assert_equal 2, @stack.size  # Should not pop anything
    assert_equal [], result      # Should return empty array

    # Test popping untagged layers until tagged or base
    @stack = Gouache::LayerStack.new
    tagged1 = Gouache::Layer.from(1)
    untagged1 = Gouache::Layer.from(31)  # no tag
    untagged2 = Gouache::Layer.from(4)   # no tag

    @stack.diffpush(tagged1, :bottom)
    @stack.diffpush(untagged1)
    @stack.diffpush(untagged2)
    assert_equal 4, @stack.size

    @stack.diffpop_until{ it.top.tag }
    assert_equal 2, @stack.size  # Should stop at tagged layer

    # Test popping all untagged to base
    @stack = Gouache::LayerStack.new
    untagged1 = Gouache::Layer.from(1)   # no tag
    untagged2 = Gouache::Layer.from(31)  # no tag

    @stack.diffpush(untagged1)
    @stack.diffpush(untagged2)

    @stack.diffpop_until{ it.top.tag }
    assert_equal 1, @stack.size  # Should pop all the way to base
    assert @stack.base?
  end

  def test_stack_diffpop_until_custom_condition
    # Test using diffpop_until with a condition other than tag
    layer1 = Gouache::Layer.from(1)   # bold
    layer2 = Gouache::Layer.from(31)  # red fg
    layer3 = Gouache::Layer.from(4, 32)   # underline + green fg
    layer4 = Gouache::Layer.from(2, 33)   # dim + yellow fg

    @stack.diffpush(layer1)
    @stack.diffpush(layer2)
    @stack.diffpush(layer3)
    @stack.diffpush(layer4)
    before_size = @stack.size

    # Pop until we find a layer with red foreground (31)
    result = @stack.diffpop_until{ it.top[0] == 31 }
    after_size = @stack.size
    assert_equal before_size - 2, after_size  # Should reduce by 2
    assert_kind_of Array, result
  end

  def test_stack_empty_layer_handling
    empty_layer = Gouache::Layer.empty

    open_sgr = @stack.diffpush(empty_layer)

    assert_kind_of Array, open_sgr
    assert_equal 2, @stack.size
  end

  def test_stack_diff_returns_correct_codes
    bold = Gouache::Layer.from(1)

    # Push should return codes to get to new state
    open_codes = @stack.diffpush(bold)
    assert_includes open_codes, 22  # reset
    assert_includes open_codes, 1   # bold

    # Pop should return codes to get back to previous state
    close_codes = @stack.diffpop
    assert_includes close_codes, 22  # reset back to base
  end

  def test_layer_tag_attribute
    layer = Gouache::Layer.from(1, 31)
    @stack.diffpush(layer, :test)

    # Tagged layer in stack has tag
    assert_equal :test, @stack.top.tag

    # Layer is frozen after push
    assert @stack.top.frozen?
  end

  def test_layer_tag_independent_of_layer_data
    layer1 = Gouache::Layer.from(1)
    layer2 = Gouache::Layer.from(1)

    @stack.diffpush(layer1, :first)
    @stack.diffpush(layer2, :second)

    # Tags are independent
    assert_equal :first, @stack[-2].tag
    assert_equal :second, @stack.top.tag

    # Layer data is still equal (excluding tag)
    assert_equal @stack[-2].to_a, @stack.top.to_a
  end

  def test_base_layer_frozen_and_nil_tag
    # Base layer should be frozen
    assert @stack.base.frozen?

    # Base layer should have nil tag
    assert_nil @stack.base.tag
  end

  def test_stack_bold_dim_basic_transitions
    bold = Gouache::Layer.from(1)
    dim = Gouache::Layer.from(2)

    # Push bold
    open_sgr = @stack.diffpush(bold)
    assert_equal [22, 1], open_sgr

    # Push dim on top of bold
    open_sgr = @stack.diffpush(dim)
    assert_equal [1, 2], open_sgr

    # Pop back to bold
    close_sgr = @stack.diffpop
    assert_equal [22, 1], close_sgr
  end

  def test_stack_bold_dim_with_intermediate_layers
    bold = Gouache::Layer.from(1)
    red = Gouache::Layer.from(31)
    underline = Gouache::Layer.from(4)
    dim = Gouache::Layer.from(2)

    # Build: BASE -> bold -> red -> underline -> dim
    @stack.diffpush(bold)
    @stack.diffpush(red)
    @stack.diffpush(underline)
    @stack.diffpush(dim)
    assert_equal 5, @stack.size

    # Pop dim, should go back to bold+red+underline
    close_sgr = @stack.diffpop
    assert_equal [22, 1], close_sgr

    # Pop underline, should keep bold+red
    close_sgr = @stack.diffpop
    assert_equal [24], close_sgr
  end

  def test_stack_bold_other_stuff_dim_sequence
    bold = Gouache::Layer.from(1)
    red = Gouache::Layer.from(31)
    italic = Gouache::Layer.from(3)
    underline = Gouache::Layer.from(4)
    dim = Gouache::Layer.from(2)

    # Push bold -> red -> italic -> underline -> dim
    @stack.diffpush(bold)
    @stack.diffpush(red)
    @stack.diffpush(italic)
    @stack.diffpush(underline)
    @stack.diffpush(dim)
    assert_equal 6, @stack.size

    # Start popping - dim should trigger reset+reapply
    close_sgr = @stack.diffpop
    assert_equal [22, 1], close_sgr

    # Pop underline - no reset needed
    close_sgr = @stack.diffpop
    assert_equal [24], close_sgr

    # Pop italic - no reset needed
    close_sgr = @stack.diffpop
    assert_equal [23], close_sgr

    # Pop red - no reset needed
    close_sgr = @stack.diffpop
    assert_equal [39], close_sgr

    # Pop bold - should reset
    close_sgr = @stack.diffpop
    assert_equal [22], close_sgr
  end

  def test_stack_dim_bold_alternating
    dim = Gouache::Layer.from(2)
    bold = Gouache::Layer.from(1)
    red = Gouache::Layer.from(31)

    # Push dim
    @stack.diffpush(dim)
    open_sgr = @stack.diffpush(red)
    assert_equal [31], open_sgr

    # Push bold over dim+red
    open_sgr = @stack.diffpush(bold)
    assert_equal [1, 2], open_sgr

    # Pop bold
    close_sgr = @stack.diffpop
    assert_equal [22, 2], close_sgr
  end

  def test_stack_bold_dim_combined_layer
    bold_dim = Gouache::Layer.from(1, 2)  # both bold and dim

    # Push combined bold+dim
    open_sgr = @stack.diffpush(bold_dim)
    assert_equal [1, 2], open_sgr

    # Pop back to base
    close_sgr = @stack.diffpop
    assert_equal [22], close_sgr
  end

  def test_stack_complex_bold_dim_scenario
    # Complex scenario: bold -> other -> dim -> other -> back to bold
    bold = Gouache::Layer.from(1)
    green = Gouache::Layer.from(32)
    italic = Gouache::Layer.from(3)
    dim = Gouache::Layer.from(2)
    blue = Gouache::Layer.from(34)
    underline = Gouache::Layer.from(4)

    # Build complex stack
    @stack.diffpush(bold)      # bold
    @stack.diffpush(green)     # bold+green
    @stack.diffpush(italic)    # bold+green+italic
    @stack.diffpush(dim)       # bold+green+italic+dim
    @stack.diffpush(blue)      # bold+green+italic+dim+blue
    @stack.diffpush(underline) # bold+green+italic+dim+blue+underline
    assert_equal 7, @stack.size

    # Pop underline - simple removal
    close_sgr = @stack.diffpop
    assert_equal [24], close_sgr

    # Pop blue - color change
    close_sgr = @stack.diffpop
    assert_equal [32], close_sgr

    # Pop dim - should trigger reset+reapply since bold remains
    close_sgr = @stack.diffpop
    assert_equal [22, 1], close_sgr
  end
end
