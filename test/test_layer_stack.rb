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

  def test_stack_diffpop_until_tag_with_tagged_layer
    layer1 = Gouache::Layer.from(1)
    layer2 = Gouache::Layer.from(31)
    layer3 = Gouache::Layer.from(4)

    @stack.diffpush(layer1, :test)
    @stack.diffpush(layer2)
    @stack.diffpush(layer3)
    assert_equal 4, @stack.size

    result = @stack.diffpop_until_tag

    # Should pop back to the tagged layer (layer1)
    assert_equal 2, @stack.size
    assert_kind_of Array, result
  end

  def test_stack_diffpop_until_tag_without_tagged_layer
    layer1 = Gouache::Layer.from(1)  # no tag
    layer2 = Gouache::Layer.from(31) # no tag
    layer3 = Gouache::Layer.from(4)  # no tag

    @stack.diffpush(layer1)
    @stack.diffpush(layer2)
    @stack.diffpush(layer3)
    assert_equal 4, @stack.size

    @stack.diffpop_until_tag

    # Should pop all the way to base since no tags
    assert_equal 1, @stack.size
    assert @stack.base?
  end

  def test_stack_diffpop_until_tag_complex_scenario
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
    @stack.diffpop_until_tag
    assert_equal 5, @stack.size

    # Now top is tagged2 - diffpop_until_tag should return early (no pop)
    result = @stack.diffpop_until_tag
    assert_equal 5, @stack.size  # Should stay the same
    assert_equal [], result      # Should return empty array

    # Use regular diffpop to pop the tagged layer
    @stack.diffpop
    assert_equal 4, @stack.size

    # Now pop until tagged1
    @stack.diffpop_until_tag
    assert_equal 2, @stack.size
  end

  def test_stack_diffpop_until_tag_conditional_logic
    # Test early return when top is already tagged
    tagged = Gouache::Layer.from(1)
    @stack.diffpush(tagged, :stop)

    result = @stack.diffpop_until_tag
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

    @stack.diffpop_until_tag
    assert_equal 2, @stack.size  # Should stop at tagged layer

    # Test popping all untagged to base
    @stack = Gouache::LayerStack.new
    untagged1 = Gouache::Layer.from(1)   # no tag
    untagged2 = Gouache::Layer.from(31)  # no tag

    @stack.diffpush(untagged1)
    @stack.diffpush(untagged2)

    @stack.diffpop_until_tag
    assert_equal 1, @stack.size  # Should pop all the way to base
    assert @stack.base?
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
end
