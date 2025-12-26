# frozen_string_literal: true

require_relative "test_helper"

class TestEffects < Minitest::Test

  def setup
    super
    @stack = Gouache::LayerStack.new
  end

  def test_effect_called_with_layer_proxies
    called_with = nil
    effect = proc { |top, under| called_with = [top, under] }

    layer = Gouache::Layer.from(1, effect)
    @stack.diffpush(layer)

    refute_nil called_with
    assert_instance_of Gouache::LayerProxy, called_with[0]
    assert_instance_of Gouache::LayerProxy, called_with[1]
  end

  def test_effect_receives_correct_top_layer
    effect = proc do |top, under|
      assert_equal 1, top.__layer[9]  # bold position
      assert_equal 31, top.__layer[0] # fg red position
    end

    bold_red = Gouache::Layer.from(1, 31)
    @stack.diffpush(bold_red)

    layer_with_effect = Gouache::Layer.from(effect)
    @stack.diffpush(layer_with_effect)
  end

  def test_effect_receives_correct_under_layer
    effect = proc do |top, under|
      assert_equal 1, under.__layer[9]  # bold in under layer
      assert_equal 31, under.__layer[0] # fg red in under layer
    end

    bold_red = Gouache::Layer.from(1, 31)
    @stack.diffpush(bold_red)

    layer_with_effect = Gouache::Layer.from(effect)
    @stack.diffpush(layer_with_effect)
  end

  def test_effect_can_modify_top_layer
    effect = proc do |top, under|
      top.italic = true
      top.fg = 32  # green
    end

    base_layer = Gouache::Layer.from(1)  # bold
    @stack.diffpush(base_layer)

    effect_layer = Gouache::Layer.from(effect)
    @stack.diffpush(effect_layer)

    top = @stack.top
    assert_equal 3, top[2]   # italic position
    assert_equal 32, top[0]  # fg position
    assert_equal 1, top[9]   # bold still there
  end

  def test_multiple_effects_called_in_order
    call_order = []
    effect1 = proc { |top, under| call_order << :first }
    effect2 = proc { |top, under| call_order << :second }

    layer = Gouache::Layer.from(effect1, effect2, 1)
    @stack.diffpush(layer)

    assert_equal [:first, :second], call_order
  end

  def test_effect_with_no_under_layer_on_base
    effect = proc do |top, under|
      assert_instance_of Gouache::LayerProxy, top
      assert_instance_of Gouache::LayerProxy, under
      # under should be base layer
      assert_equal Gouache::Layer::BASE, under.__layer
    end

    layer_with_effect = Gouache::Layer.from(1, effect)
    @stack.diffpush(layer_with_effect)
  end

  def test_effects_called_only_when_layer_has_effects
    call_count = 0
    effect = proc { |top, under| call_count += 1 }

    # Layer without effects
    no_effect_layer = Gouache::Layer.from(1, 31)
    @stack.diffpush(no_effect_layer)
    assert_equal 0, call_count

    # Layer with effects
    effect_layer = Gouache::Layer.from(effect, 4)
    @stack.diffpush(effect_layer)
    assert_equal 1, call_count
  end

  def test_effect_with_nil_layer
    effect_called = false
    effect = proc { |top, under| effect_called = true }

    layer = Gouache::Layer.from(effect)
    @stack.diffpush(layer)

    assert effect_called
  end

  def test_effects_interact_with_layer_proxy_methods
    effect = proc do |top, under|
      # Test boolean style methods
      top.bold = true
      top.italic = false

      # Test color methods
      under_fg = under.fg
      if under_fg
        top.bg = under_fg  # copy fg to bg with role change
      end

      # Test predicate methods
      if under.bold?
        top.underline = true
      end
    end

    base = Gouache::Layer.from(1, 31)  # bold red
    @stack.diffpush(base)

    effect_layer = Gouache::Layer.from(effect)
    @stack.diffpush(effect_layer)

    top = @stack.top
    assert_equal 1, top[9]   # bold
    assert_equal 23, top[2]  # italic off
    assert_equal 4, top[8]   # underline (because under was bold)

    # bg should be red (copied from under.fg)
    bg_color = top[1]
    assert_instance_of Gouache::Color, bg_color
    assert_equal Gouache::Color::BG, bg_color.role
  end

  def test_effect_complex_layer_manipulation
    effect = proc do |top, under|
      # Complex effect: make text dimmer version of under layer
      if under.bold?
        top.dim = true
      end

      # Copy colors but make them dimmer
      if under_fg = under.fg
        top.fg = under_fg
      end

      # Remove some styles
      top.italic = false
      top.underline = false
    end

    rich_layer = Gouache::Layer.from(1, 3, 4, 32)  # bold, italic, underline, green
    @stack.diffpush(rich_layer)

    effect_layer = Gouache::Layer.from(effect)
    @stack.diffpush(effect_layer)

    top = @stack.top
    assert_equal 2, top[10]  # dim
    assert_equal 23, top[2]  # italic off
    assert_equal 24, top[8]  # underline off
    assert_equal 32, top[0]  # fg green (copied)
  end

  def test_full_pipeline_stylesheet_to_stack_with_effects
    # Effects to test
    bold_effect = proc { |top, under| top.bold = true }
    color_copy_effect = proc { |top, under|
      if under.fg
        top.bg = under.fg  # copy fg color to bg
      end
    }
    dim_effect = proc { |top, under| top.dim = true if under.bold? }

    # Create Gouache instance with styles containing effects
    go = Gouache.new(
      base_layer: [1, 31],  # bold red
      with_effects: [
        bold_effect,
        32,                    # green fg
        color_copy_effect,     # copy under fg to top bg
        [4, dim_effect],       # underline + dim effect
        3                      # italic
      ]
    )

    # Test compilation - effects should execute during rendering
    result = go[:base_layer, "base", :with_effects, "styled"]

    # Should contain escape sequences
    assert_includes result, "\e["
    assert_includes result, "base"
    assert_includes result, "styled"

    # Verify the result contains expected SGR codes by checking substrings
    # The exact sequence will depend on layer stack diff calculations
    assert result.length > "basestyled".length  # Has escape codes

    # Test that effects were processed by examining intermediate layer
    rules = go.instance_variable_get(:@rules)
    layer = rules[:with_effects]

    # Layer should have the effects stored
    assert_equal [bold_effect, color_copy_effect, dim_effect], layer.effects

    # Layer should have SGR codes applied
    assert_equal 32, layer[0]  # green fg
    assert_equal 4, layer[8]   # underline
    assert_equal 3, layer[2]   # italic
  end

  def test_effects_actual_emitted_sequences
    # Test that effects produce correct SGR sequences in final output
    color_copy_effect = proc { |top, under|
      if under.fg
        top.bg = under.fg  # copy red fg to bg
      end
    }
    bold_effect = proc { |top, under| top.bold = true }

    go = Gouache.new(
      base: [31],           # red fg
      with_effect: [
        color_copy_effect,  # should copy red to bg
        bold_effect,        # should add bold
        3                   # italic
      ]
    )

    result = go[:base, "text", :with_effect, "styled"]

    # Check exact emitted string from effects pipeline
    expected = "\e[31mtext\e[22;41;3;1mstyled\e[0m"
    assert_equal expected, result
  end

end
