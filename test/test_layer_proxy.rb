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

  def test_fg_reader
    @layer[0] = "red"
    assert_equal "red", @proxy.fg
  end

  def test_fg_setter_with_color
    color = Gouache::Color.rgb(255, 0, 0)
    @proxy.fg = color
    assert_equal color, @layer[0]
  end

  def test_fg_setter_with_string
    @proxy.fg = "38;2;255;0;0"
    result = @layer[0]
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::FG, result.role
  end

  def test_fg_setter_with_integer
    @proxy.fg = 31
    result = @layer[0]
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::FG, result.role
  end

  def test_fg_setter_with_nil
    @proxy.fg = nil
    assert_nil @layer[0]
  end

  def test_fg_setter_role_reassignment
    bg_color = Gouache::Color.on_rgb(255, 0, 0)
    assert_equal Gouache::Color::BG, bg_color.role

    @proxy.fg = bg_color
    result = @layer[0]
    assert_equal Gouache::Color::FG, result.role
    assert_equal [255, 0, 0], result.rgb
  end

  def test_bg_reader
    @layer[1] = "blue"
    assert_equal "blue", @proxy.bg
  end

  def test_bg_setter_with_color
    color = Gouache::Color.on_rgb(0, 0, 255)
    @proxy.bg = color
    assert_equal color, @layer[1]
  end

  def test_bg_setter_with_string
    @proxy.bg = "48;2;0;0;255"
    result = @layer[1]
    assert_instance_of Gouache::Color, result
    assert_equal Gouache::Color::BG, result.role
  end

  def test_bg_setter_role_reassignment
    fg_color = Gouache::Color.rgb(0, 255, 0)
    assert_equal Gouache::Color::FG, fg_color.role

    @proxy.bg = fg_color
    result = @layer[1]
    assert_equal Gouache::Color::BG, result.role
    assert_equal [0, 255, 0], result.rgb
  end

  def test_italic_setter_truthy
    @proxy.italic = true
    assert_equal 3, @layer[2]
  end

  def test_italic_setter_falsy
    @proxy.italic = false
    assert_equal 23, @layer[2]
  end

  def test_italic_predicate_true
    @layer[2] = 3
    assert @proxy.italic?
  end

  def test_italic_predicate_false_with_off_value
    @layer[2] = 23
    refute @proxy.italic?
  end

  def test_italic_predicate_false_with_nil
    @layer[2] = nil
    refute @proxy.italic?
  end

  def test_bold_setter_and_predicate
    @proxy.bold = true
    assert_equal 1, @layer[9]
    assert @proxy.bold?

    @proxy.bold = false
    assert_equal 22, @layer[9]
    refute @proxy.bold?
  end

  def test_underline_setter_truthy
    @proxy.underline = true
    assert_equal 4, @layer[8]
  end

  def test_underline_setter_falsy
    @proxy.underline = false
    assert_equal 24, @layer[8]
  end

  def test_underline_predicate
    @layer[8] = 4
    assert @proxy.underline?

    @layer[8] = 21
    refute @proxy.underline?

    @layer[8] = 24
    refute @proxy.underline?
  end

  def test_double_underline_setter
    @proxy.double_underline = true
    assert_equal 21, @layer[8]

    @proxy.double_underline = false
    assert_equal 24, @layer[8]
  end

  def test_double_underline_predicate
    @layer[8] = 21
    assert @proxy.double_underline?

    @layer[8] = 4
    refute @proxy.double_underline?

    @layer[8] = 24
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
