# frozen_string_literal: true

require_relative "test_helper"

class TestRefinement < Minitest::Test
  @@go = Gouache.new
  using @@go.refinement

  def test_refinement_returns_module
    go = Gouache.new
    result = go.refinement
    assert_instance_of Module, result
  end

  def test_string_gets_color_methods
    result = "hello".red
    assert_instance_of String, result
    assert result.include?("hello")
  end

  def test_string_gets_blue_method
    result = "world".blue
    assert_instance_of String, result
    assert result.include?("world")
  end

  def test_string_gets_unpaint_method
    styled = "\e[31mred text\e[0m"
    result = styled.unpaint
    assert_equal "red text", result
  end

  def test_string_gets_repaint_method
    result = "plain text".repaint
    assert_instance_of String, result
    assert result.include?("plain text")
  end

  def test_string_gets_wrap_method
    result = "text to wrap".wrap
    assert_instance_of String, result
    assert result.include?("text to wrap")
  end
end

class TestRefinementCustomStyles < Minitest::Test
  @@go = Gouache.new(custom_style: 99)
  using @@go.refinement

  def test_custom_styles_work
    result = "text".custom_style
    assert_instance_of String, result
    assert result.include?("text")
  end
end

class TestRefinementDisabled < Minitest::Test
  @@go = Gouache.new.disable
  using @@go.refinement

  def test_disabled_produces_plain_text
    result = "styled".red
    assert_equal "styled", result
  end
end

class TestRefinementEnabled < Minitest::Test
  @@go = Gouache.new.enable
  using @@go.refinement

  def test_enabled_produces_styled_text
    result = "text".red
    refute_equal "text", result
    assert result.include?("text")
  end
end

class TestRefinementMain < Minitest::Test
  using Gouache.refinement

  def test_main_refinement_works
    result = "text".red
    assert_instance_of String, result
    assert result.include?("text")
  end
end

class TestRefinementOverride < Minitest::Test
  # First refinement with custom style and enabled
  @@go1 = Gouache.new(x: [:red, :bold]).enable
  using @@go1.refinement

  # Second refinement with disabled instance
  @@go2 = Gouache.new.disable
  using @@go2.refinement

  def test_refinement_override_behavior
    # Methods from first refinement (x) still work since not overridden
    result_x = "test".x
    refute_equal "test", result_x
    assert result_x.include?("test")

    # Methods from second refinement override first (red becomes plain)
    result_red = "test".red
    assert_equal "test", result_red
  end

  def test_custom_method_survives_override
    # Custom method x should still produce styled output from first refinement
    result = "custom".x
    assert result.include?("custom")
    refute_equal "custom", result
  end

  def test_standard_method_gets_overridden
    # Standard method red gets overridden by second refinement (disabled)
    result = "standard".red
    assert_equal "standard", result
  end
end
