# frozen_string_literal: true

require_relative "test_helper"

class TestLayerProxy < Minitest::Test

  def setup
    super
    @layer = Gouache::Layer.empty
    @proxy = Gouache::LayerProxy.new(@layer)
  end

  def test_initialization
    assert_same @layer, @proxy.__layer
  end

  def test_fg_reader_with_string
    @layer[Gouache::Layer::RANGES[:fg].index] = "red"
    assert_equal "red", @proxy.fg
  end

  def test_fg_reader_with_color_object
    color = Gouache::Color.rgb(255, 0, 0)
    @layer[Gouache::Layer::RANGES[:fg].index] = color
    result = @proxy.fg
    assert_same color, result
  end

  def test_fg_reader_with_integer_wrapped_as_color
    @layer = Gouache::Layer.from(31)
    @proxy = Gouache::LayerProxy.new(@layer)
    result = @proxy.fg
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::FG, result.role
  end

  def test_fg_reader_with_nil
    @layer[Gouache::Layer::RANGES[:fg].index] = nil
    assert_nil @proxy.fg
  end

  def test_fg_setter_with_color
    color = Gouache::Color.rgb(255, 0, 0)
    @proxy.fg = color
    assert_equal color, @layer[Gouache::Layer::RANGES[:fg].index]
  end

  def test_fg_setter_with_string
    @proxy.fg = "38;2;255;0;0"
    result = @layer[Gouache::Layer::RANGES[:fg].index]
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::FG, result.role
  end

  def test_fg_setter_with_integer
    @proxy.fg = 31
    result = @layer[Gouache::Layer::RANGES[:fg].index]
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::FG, result.role
  end

  def test_fg_setter_with_nil
    @proxy.fg = nil
    assert_nil @layer[Gouache::Layer::RANGES[:fg].index]
  end

  def test_fg_setter_role_reassignment
    bg_color = Gouache::Color.on_rgb(255, 0, 0)
    assert_equal Gouache::Color::BG, bg_color.role

    @proxy.fg = bg_color
    result = @layer[Gouache::Layer::RANGES[:fg].index]
    assert_equal Gouache::Color::FG, result.role
    assert_equal [255, 0, 0], result.rgb
  end

  def test_bg_reader_with_string
    @layer[Gouache::Layer::RANGES[:bg].index] = "blue"
    assert_equal "blue", @proxy.bg
  end

  def test_bg_reader_with_color_object
    color = Gouache::Color.on_rgb(0, 0, 255)
    @layer[Gouache::Layer::RANGES[:bg].index] = color
    result = @proxy.bg
    assert_same color, result
  end

  def test_bg_reader_with_integer_wrapped_as_color
    @layer = Gouache::Layer.from(41)
    @proxy = Gouache::LayerProxy.new(@layer)
    result = @proxy.bg
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::BG, result.role
  end

  def test_bg_reader_with_nil
    @layer[Gouache::Layer::RANGES[:bg].index] = nil
    assert_nil @proxy.bg
  end

  def test_bg_setter_with_color
    color = Gouache::Color.on_rgb(0, 0, 255)
    @proxy.bg = color
    assert_equal color, @layer[Gouache::Layer::RANGES[:bg].index]
  end

  def test_bg_setter_with_string
    @proxy.bg = "48;2;0;0;255"
    result = @layer[Gouache::Layer::RANGES[:bg].index]
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::BG, result.role
  end

  def test_bg_setter_role_reassignment
    fg_color = Gouache::Color.rgb(0, 255, 0)
    assert_equal Gouache::Color::FG, fg_color.role

    @proxy.bg = fg_color
    result = @layer[Gouache::Layer::RANGES[:bg].index]
    assert_equal Gouache::Color::BG, result.role
    assert_equal [0, 255, 0], result.rgb
  end

  def test_underline_color_reader_with_string
    @layer[Gouache::Layer::RANGES[:underline_color].index] = "red underline"
    assert_equal "red underline", @proxy.underline_color
  end

  def test_underline_color_reader_with_color_object
    color = Gouache::Color.over_rgb(255, 128, 0)
    @layer[Gouache::Layer::RANGES[:underline_color].index] = color
    result = @proxy.underline_color
    assert_same color, result
  end

  def test_underline_color_reader_with_integer_wrapped_as_color
    ul_color = Gouache::Color.over_rgb(255, 0, 0)
    @layer = Gouache::Layer.from(ul_color)
    @proxy = Gouache::LayerProxy.new(@layer)
    result = @proxy.underline_color
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::UL, result.role
  end

  def test_underline_color_reader_with_nil
    @layer[Gouache::Layer::RANGES[:underline_color].index] = nil
    assert_nil @proxy.underline_color
  end

  def test_underline_color_setter_with_color
    color = Gouache::Color.over_rgb(255, 128, 0)
    @proxy.underline_color = color
    assert_equal color, @proxy.underline_color
  end

  def test_underline_color_setter_with_string
    @proxy.underline_color = "58;2;255;128;0"
    result = @proxy.underline_color
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::UL, result.role
  end

  def test_underline_color_setter_with_integer
    @proxy.underline_color = 31  # basic red, will be converted to underline role
    result = @proxy.underline_color
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::UL, result.role
    assert_equal [205, 0, 0], result.rgb  # ANSI16 red RGB values
  end

  def test_underline_color_setter_with_nil
    @proxy.underline_color = nil
    assert_nil @proxy.underline_color
  end

  def test_underline_color_setter_role_reassignment
    fg_color = Gouache::Color.rgb(255, 165, 0)
    assert_equal Gouache::Color::FG, fg_color.role

    @proxy.underline_color = fg_color
    result = @proxy.underline_color
    assert_equal Gouache::Color::UL, result.role
    assert_equal [255, 165, 0], result.rgb
  end

  def test_italic_setter_truthy
    @proxy.italic = true
    assert_equal 3, @layer[Gouache::Layer::RANGES[:italic].index]
  end

  def test_italic_setter_falsy
    @proxy.italic = false
    assert_equal 23, @layer[Gouache::Layer::RANGES[:italic].index]
  end

  def test_italic_predicate_true
    @layer[Gouache::Layer::RANGES[:italic].index] = 3
    assert @proxy.italic?
  end

  def test_italic_predicate_false_with_off_value
    @layer[Gouache::Layer::RANGES[:italic].index] = 23
    refute @proxy.italic?
  end

  def test_italic_predicate_false_with_nil
    @layer[Gouache::Layer::RANGES[:italic].index] = nil
    refute @proxy.italic?
  end

  def test_bold_setter_and_predicate
    @proxy.bold = true
    assert_equal 1, @layer[Gouache::Layer::RANGES[:bold].index]
    assert @proxy.bold?

    @proxy.bold = false
    assert_equal 22, @layer[Gouache::Layer::RANGES[:bold].index]
    refute @proxy.bold?
  end

  def test_underline_setter_truthy
    @proxy.underline = true
    assert_equal 4, @layer[Gouache::Layer::RANGES[:underline].index]
  end

  def test_underline_setter_falsy
    @proxy.underline = false
    assert_equal 24, @layer[Gouache::Layer::RANGES[:underline].index]
  end

  def test_underline_predicate
    @layer[Gouache::Layer::RANGES[:underline].index] = 4
    assert @proxy.underline?

    @layer[Gouache::Layer::RANGES[:underline].index] = 21
    refute @proxy.underline?

    @layer[Gouache::Layer::RANGES[:underline].index] = 24
    refute @proxy.underline?
  end

  def test_double_underline_setter
    @proxy.double_underline = true
    assert_equal 21, @layer[Gouache::Layer::RANGES[:underline].index]

    @proxy.double_underline = false
    assert_equal 24, @layer[Gouache::Layer::RANGES[:underline].index]
  end

  def test_double_underline_predicate
    @layer[Gouache::Layer::RANGES[:underline].index] = 21
    assert @proxy.double_underline?

    @layer[Gouache::Layer::RANGES[:underline].index] = 4
    refute @proxy.double_underline?

    @layer[Gouache::Layer::RANGES[:underline].index] = 24
    refute @proxy.double_underline?
  end

  def test_all_boolean_style_methods_exist
    %w[italic blink inverse hidden strike overline bold dim].each do |method|
      assert_respond_to @proxy, "#{method}="
      assert_respond_to @proxy, "#{method}?"
    end
  end

  def test_underline_special_methods_exist
    assert_respond_to @proxy, :underline=
    assert_respond_to @proxy, :double_underline=
    assert_respond_to @proxy, :underline?
    assert_respond_to @proxy, :double_underline?
  end

end
