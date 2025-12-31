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

    layer = Gouache::Layer.from(1)
    @stack.diffpush(layer, [effect])

    refute_nil called_with
    assert_instance_of Gouache::LayerProxy, called_with[0]
    assert_instance_of Gouache::LayerProxy, called_with[1]
  end

  def test_effect_receives_correct_top_layer
    effect = proc do |top, under|
      assert_equal 1, top.__layer[Gouache::Layer::RANGES[:bold].index]  # bold position
      assert_equal 31, top.__layer[Gouache::Layer::RANGES[:fg].index] # fg red position
    end

    bold_red = Gouache::Layer.from(1, 31)
    @stack.diffpush(bold_red)

    @stack.diffpush(nil, [effect])
  end

  def test_effect_receives_correct_under_layer
    effect = proc do |top, under|
      assert_equal 1, under.__layer[Gouache::Layer::RANGES[:bold].index]  # bold in under layer
      assert_equal 31, under.__layer[Gouache::Layer::RANGES[:fg].index] # fg red in under layer
    end

    bold_red = Gouache::Layer.from(1, 31)
    @stack.diffpush(bold_red)

    @stack.diffpush(nil, [effect])
  end

  def test_effect_can_modify_top_layer
    effect = proc do |top, under|
      top.italic = true
      top.fg = 32  # green
    end

    base_layer = Gouache::Layer.from(1)  # bold
    @stack.diffpush(base_layer)

    @stack.diffpush(nil, [effect])

    top = @stack.top
    assert_equal 3, top[Gouache::Layer::RANGES[:italic].index]   # italic position
    assert_equal 32, top[Gouache::Layer::RANGES[:fg].index]  # fg position
    assert_equal 1, top[Gouache::Layer::RANGES[:bold].index]   # bold still there
  end

  def test_multiple_effects_called_in_order
    call_order = []
    effect1 = proc { |top, under| call_order << :first }
    effect2 = proc { |top, under| call_order << :second }

    layer = Gouache::Layer.from(1)
    @stack.diffpush(layer, [effect1, effect2])

    assert_equal [:first, :second], call_order
  end

  def test_effect_with_no_under_layer_on_base
    effect = proc do |top, under|
      assert_instance_of Gouache::LayerProxy, top
      assert_instance_of Gouache::LayerProxy, under
      # under should be base layer
      assert_equal Gouache::Layer::BASE, under.__layer
    end

    layer = Gouache::Layer.from(1)
    @stack.diffpush(layer, [effect])
  end

  def test_effects_called_only_when_layer_has_effects
    call_count = 0
    effect = proc { |top, under| call_count += 1 }

    # Layer without effects
    no_effect_layer = Gouache::Layer.from(1, 31)
    @stack.diffpush(no_effect_layer)
    assert_equal 0, call_count

    # Layer with effects
    layer = Gouache::Layer.from(4)
    @stack.diffpush(layer, [effect])
    assert_equal 1, call_count
  end

  def test_effect_with_nil_layer
    effect_called = false
    effect = proc { |top, under| effect_called = true }

    @stack.diffpush(nil, [effect])

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

    @stack.diffpush(nil, [effect])

    top = @stack.top
    assert_equal 1, top[Gouache::Layer::RANGES[:bold].index]   # bold
    assert_equal 23, top[Gouache::Layer::RANGES[:italic].index]  # italic off
    assert_equal 4, top[Gouache::Layer::RANGES[:underline].index]   # underline (because under was bold)

    # bg should be red (copied from under.fg)
    bg_color = top[Gouache::Layer::RANGES[:bg].index]
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

    @stack.diffpush(nil, [effect])

    top = @stack.top
    assert_equal 2, top[Gouache::Layer::RANGES[:dim].index]  # dim
    assert_equal 23, top[Gouache::Layer::RANGES[:italic].index]  # italic off
    assert_equal 24, top[Gouache::Layer::RANGES[:underline].index]  # underline off
    assert_equal 32, top[Gouache::Layer::RANGES[:fg].index]  # fg green (copied)
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

    # Test that effects were processed by examining stylesheet
    effects = go.stylesheet.effects[:with_effects]
    assert_equal [bold_effect, color_copy_effect, dim_effect], effects

    # Test layer has SGR codes applied
    layer = go.stylesheet.layers[:with_effects]
    assert_equal 32, layer[Gouache::Layer::RANGES[:fg].index]  # green fg
    assert_equal 4, layer[Gouache::Layer::RANGES[:underline].index]   # underline
    assert_equal 3, layer[Gouache::Layer::RANGES[:italic].index]   # italic
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

  def test_effect_arity_constraints
    # Effects with wrong arity should raise ArgumentError
    zero_arity_effect = proc { "no args" }
    three_arity_effect = proc { |top, under, extra| "too many args" }

    layer = Gouache::Layer.from(1)

    assert_raises(ArgumentError) { @stack.diffpush(layer, [zero_arity_effect]) }
    assert_raises(ArgumentError) { @stack.diffpush(layer, [three_arity_effect]) }
  end

  def test_effect_valid_arity_one
    # Effects with arity 1 should work (only top layer)
    call_count = 0
    one_arity_effect = proc { |top| call_count += 1; top.bold = true }

    layer = Gouache::Layer.from(31)
    @stack.diffpush(layer, [one_arity_effect])

    assert_equal 1, call_count
    assert_equal 1, @stack.top[Gouache::Layer::RANGES[:bold].index]  # bold should be set
  end

  def test_effect_valid_arity_two
    # Effects with arity 2 should work (top and under layers)
    call_count = 0
    two_arity_effect = proc { |top, under| call_count += 1; top.italic = true }

    layer = Gouache::Layer.from(32)
    @stack.diffpush(layer, [two_arity_effect])

    assert_equal 1, call_count
    assert_equal 3, @stack.top[Gouache::Layer::RANGES[:italic].index]  # italic was set
  end

  def test_base_effects_dim_off
    # Test dim_off effect
    result = Gouache[:bold, :dim, "text", :dim_off, "more"]
    assert_equal "\e[1;2mtext\e[22;1mmore\e[0m", result
  end

  def test_base_effects_bold_off
    # Test bold_off effect
    result = Gouache[:bold, :dim, "text", :bold_off, "more"]
    assert_equal "\e[1;2mtext\e[22;2mmore\e[0m", result
  end

  def test_base_effects_combined_sequence
    # Test the example sequence from the diff
    result = Gouache[:bold, :dim, "start", :dim_off, "middle", :bold_off, "end"]
    assert_equal "\e[1;2mstart\e[22;1mmiddle\e[22mend\e[0m", result
  end

  def test_base_effects_with_other_styles
    # Test base effects interact properly with other styles
    result = Gouache[:red, :bold, :dim, "start", :dim_off, :italic, "middle", :bold_off, "end"]
    assert result.include?("start")
    assert result.include?("middle")
    assert result.include?("end")
    # Should contain proper SGR sequences for transitions
    assert result.include?("\e["), "Should contain escape sequences"
  end

  def test_base_effects_bright
    # Test bright effect converts normal colors (30-37) to bright colors (90-97)
    result = Gouache[:red, "normal", :bright, "bright"]
    assert_equal "\e[31mnormal\e[91mbright\e[0m", result

    # Test with other normal colors
    result = Gouache[:blue, "blue", :bright, "bright blue"]
    assert_equal "\e[34mblue\e[94mbright blue\e[0m", result
  end

  def test_base_effects_unbright
    # Test unbright effect converts bright colors (90-97) to normal colors (30-37)
    result = Gouache[Gouache::Color.sgr(91), "bright", :unbright, "normal"]
    assert_equal "\e[91mbright\e[31mnormal\e[0m", result

    # Test with bright blue
    result = Gouache[Gouache::Color.sgr(94), "bright", :unbright, "normal"]
    assert_equal "\e[94mbright\e[34mnormal\e[0m", result
  end

  def test_base_effects_bright_off_alias
    # Test bright_off is alias for unbright
    result = Gouache[Gouache::Color.sgr(92), "bright", :bright_off, "normal"]
    assert_equal "\e[92mbright\e[32mnormal\e[0m", result
  end

  def test_base_effects_bright_no_effect_on_non_colors
    # Test bright effect has no effect on non-standard colors or backgrounds
    result = Gouache[Gouache::Color.sgr(42), "bg", :bright, "still bg"]
    assert_equal "\e[42mbgstill bg\e[0m", result
  end

  def test_base_effects_bright_with_rgb_colors
    # Test bright effect only affects basic ANSI colors, not RGB
    rgb_color = Gouache::Color.rgb(255, 0, 0)
    result = Gouache[rgb_color, "rgb", :bright, "still rgb"]
    expected = "\e[38;2;255;0;0mrgbstill rgb\e[0m"
    assert_equal expected, result
  end

  def test_base_effects_unbright_no_effect_on_normal_colors
    # Test unbright has no effect on normal colors (30-37)
    result = Gouache[:red, "normal", :unbright, "still normal"]
    assert_equal "\e[31mnormalstill normal\e[0m", result
  end

  def test_base_effects_bright_unbright_roundtrip
    # Test bright then unbright returns to original color
    result = Gouache[:green, "start", :bright, "bright", :unbright, "back"]
    assert_equal "\e[32mstart\e[92mbright\e[32mback\e[0m", result
  end

  def test_base_effects_bright_with_dim
    # Test bright effect with dim on - should emit dim_off
    result = Gouache[:red, :dim, "dimmed", :bright, "bright"]
    assert_equal "\e[22;31;2mdimmed\e[22;91mbright\e[0m", result
  end

  def test_base_effects_bright_with_stylesheet_indirection
    # Test bright effect with Color object via stylesheet - should work
    go = Gouache.new(bright_color: Gouache::Color.sgr(91))
    result = go[:red, "normal", :bright, "bright", :bright_color, "styled"]
    assert_equal "\e[31mnormal\e[91mbrightstyled\e[0m", result
  end

  def test_base_effects_unbright_with_stylesheet_indirection
    # Test unbright effect with Color object via stylesheet - should work
    go = Gouache.new(normal_color: Gouache::Color.sgr(31))
    result = go[Gouache::Color.sgr(91), "bright", :unbright, "normal", :normal_color, "styled"]
    assert_equal "\e[91mbright\e[31mnormalstyled\e[0m", result
  end

end
