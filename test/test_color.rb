# frozen_string_literal: true

require "test_helper"

class TestColor < Minitest::Test

  def test_rgb_constructor
    # Separate arguments
    color = Gouache::Color.rgb(255, 0, 0)
    assert_equal [255, 0, 0], color.rgb

    # Array argument
    color = Gouache::Color.rgb([255, 0, 0])
    assert_equal [255, 0, 0], color.rgb

    # Hex string with #
    color = Gouache::Color.rgb("#ff0000")
    assert_equal [255, 0, 0], color.rgb

    # Hex string without #
    color = Gouache::Color.rgb("ff0000")
    assert_equal [255, 0, 0], color.rgb
  end

  def test_on_rgb_constructor
    # Separate arguments
    color = Gouache::Color.on_rgb(0, 255, 0)
    assert_equal [0, 255, 0], color.rgb
    assert_equal "48;2;0;255;0", color.sgr

    # Array argument
    color = Gouache::Color.on_rgb([0, 255, 0])
    assert_equal [0, 255, 0], color.rgb
    assert_equal "48;2;0;255;0", color.sgr

    # Hex string with #
    color = Gouache::Color.on_rgb("#00ff00")
    assert_equal [0, 255, 0], color.rgb
    assert_equal "48;2;0;255;0", color.sgr

    # Hex string without #
    color = Gouache::Color.on_rgb("00ff00")
    assert_equal [0, 255, 0], color.rgb
    assert_equal "48;2;0;255;0", color.sgr
  end

  def test_hex_constructor
    # Without # prefix
    color = Gouache::Color.hex("ff0000")
    assert_equal [255, 0, 0], color.rgb

    # With # prefix
    color = Gouache::Color.hex("#ff0000")
    assert_equal [255, 0, 0], color.rgb
  end

  def test_on_hex_constructor
    # Without # prefix
    color = Gouache::Color.on_hex("00ff00")
    assert_equal [0, 255, 0], color.rgb
    assert_equal "48;2;0;255;0", color.sgr

    # With # prefix
    color = Gouache::Color.on_hex("#00ff00")
    assert_equal [0, 255, 0], color.rgb
    assert_equal "48;2;0;255;0", color.sgr
  end

  def test_sgr_conversion
    color = Gouache::Color.rgb(255, 0, 0)
    assert_equal "38;2;255;0;0", color.sgr
  end

  def test_sgr_constructor
    color = Gouache::Color.sgr("38;2;255;128;64")
    assert_equal [255, 128, 64], color.rgb
    assert_equal "38;2;255;128;64", color.sgr

    # Test underline color SGR sequences
    color = Gouache::Color.sgr("58;2;255;128;64")
    assert_equal [255, 128, 64], color.rgb
    assert_equal "58;2;255;128;64", color.sgr
    assert_equal 58, color.role

    # Test underline 256-color SGR sequences
    color = Gouache::Color.sgr("58;5;196")
    assert_equal 196, color._256
    assert_equal "58;5;196", color.sgr
    assert_equal 58, color.role
  end

  def test_ansi_constructor_alias
    # ansi is an alias for sgr
    color1 = Gouache::Color.ansi("38;2;255;128;64")
    color2 = Gouache::Color.sgr("38;2;255;128;64")

    assert_equal color1.rgb, color2.rgb
    assert_equal color1.sgr, color2.sgr
    assert_equal color1.role, color2.role

    # Test with basic SGR codes
    color3 = Gouache::Color.ansi(31)
    color4 = Gouache::Color.sgr(31)

    assert_equal color3.basic, color4.basic
    assert_equal color3.role, color4.role
  end

  def test_cube_constructor
    color = Gouache::Color.cube(5, 0, 0)  # max red in 6x6x6 cube
    expected_sgr = "38;5;#{16 + 36*5 + 6*0 + 0}"  # 38;5;196
    assert_equal expected_sgr, color.sgr
  end

  def test_on_cube_constructor
    color = Gouache::Color.on_cube(0, 5, 0)  # max green in 6x6x6 cube
    expected_sgr = "48;5;#{16 + 36*0 + 6*5 + 0}"  # 48;5;46
    assert_equal expected_sgr, color.sgr
  end

  def test_gray_constructor
    color = Gouache::Color.gray(12)
    expected_sgr = "38;5;#{232 + 12}"  # 38;5;244
    assert_equal expected_sgr, color.sgr
  end

  def test_on_gray_constructor
    color = Gouache::Color.on_gray(8)
    expected_sgr = "48;5;#{232 + 8}"  # 48;5;240
    assert_equal expected_sgr, color.sgr
  end

  def test_oklch_constructor
    color = Gouache::Color.oklch(0.7, 0.15, 30)
    assert_equal [0.7, 0.15, 30], color.oklch
  end

  def test_on_oklch_constructor
    color = Gouache::Color.on_oklch(0.8, 0.1, 120)
    assert_equal [0.8, 0.1, 120], color.oklch
    assert_equal 48, color.role  # background
  end

  def test_over_rgb_constructor
    # Separate arguments
    color = Gouache::Color.over_rgb(255, 0, 0)
    assert_equal [255, 0, 0], color.rgb
    assert_equal "58;2;255;0;0", color.sgr
    assert_equal 58, color.role  # underline

    # Array argument
    color = Gouache::Color.over_rgb([0, 255, 0])
    assert_equal [0, 255, 0], color.rgb
    assert_equal "58;2;0;255;0", color.sgr

    # Hex string with #
    color = Gouache::Color.over_rgb("#0000ff")
    assert_equal [0, 0, 255], color.rgb
    assert_equal "58;2;0;0;255", color.sgr

    # Hex string without #
    color = Gouache::Color.over_rgb("ff00ff")
    assert_equal [255, 0, 255], color.rgb
    assert_equal "58;2;255;0;255", color.sgr
  end

  def test_over_hex_constructor
    # Without # prefix
    color = Gouache::Color.over_hex("ff0000")
    assert_equal [255, 0, 0], color.rgb
    assert_equal "58;2;255;0;0", color.sgr
    assert_equal 58, color.role

    # With # prefix
    color = Gouache::Color.over_hex("#00ff00")
    assert_equal [0, 255, 0], color.rgb
    assert_equal "58;2;0;255;0", color.sgr
  end

  def test_over_cube_constructor
    color = Gouache::Color.over_cube(5, 0, 0)  # max red in 6x6x6 cube
    expected_sgr = "58;5;#{16 + 36*5 + 6*0 + 0}"  # 58;5;196
    assert_equal expected_sgr, color.sgr
    assert_equal 58, color.role
  end

  def test_over_gray_constructor
    color = Gouache::Color.over_gray(12)
    expected_sgr = "58;5;#{232 + 12}"  # 58;5;244
    assert_equal expected_sgr, color.sgr
    assert_equal 58, color.role
  end

  def test_over_oklch_constructor
    color = Gouache::Color.over_oklch(0.7, 0.15, 180)
    assert_equal [0.7, 0.15, 180], color.oklch
    assert_equal 58, color.role  # underline
  end

  def test_role_method
    # Test foreground colors
    color = Gouache::Color.rgb(255, 0, 0)
    assert_equal 38, color.role

    color = Gouache::Color.sgr("31")
    assert_equal 38, color.role

    # Test background colors
    color = Gouache::Color.on_rgb(0, 255, 0)
    assert_equal 48, color.role

    color = Gouache::Color.sgr("41")
    assert_equal 48, color.role

    # Test underline colors
    color = Gouache::Color.over_rgb(255, 0, 0)
    assert_equal 58, color.role

    color = Gouache::Color.sgr("58;5;196")
    assert_equal 58, color.role

    color = Gouache::Color.sgr("58;2;255;0;0")
    assert_equal 58, color.role
  end

  def test_256_method
    color = Gouache::Color.rgb(255, 0, 0)
    index = color._256
    assert_kind_of Integer, index
    assert_operator index, :>=, 0
    assert_operator index, :<, 256
  end

  def test_basic_method
    color = Gouache::Color.rgb(255, 0, 0)
    basic = color.basic
    assert_kind_of Integer, basic
    assert_operator basic, :>=, 30
    assert_operator basic, :<=, 107

    # Test underline colors return 59 for basic (over_default)
    underline_color = Gouache::Color.over_rgb(255, 0, 0)
    assert_equal 59, underline_color.basic

    # Test SGR 59 basic handling
    color59 = Gouache::Color.sgr(59)
    assert_equal 59, color59.basic
  end

  def test_to_i_method
    color = Gouache::Color.rgb(255, 0, 0)
    to_i_result = color.to_i
    sgr_result = color.to_sgr.to_i
    assert_equal sgr_result, to_i_result
    assert_kind_of Integer, to_i_result
  end

  def test_to_sgr_without_fallback
    color = Gouache::Color.rgb(255, 0, 0)
    assert_equal "38;2;255;0;0", color.to_sgr
  end

  def test_to_sgr_with_fallback_truecolor
    Gouache::Term.color_level = :truecolor
    color = Gouache::Color.rgb(255, 128, 64)
    assert_equal "38;2;255;128;64", color.to_sgr(fallback: true)
  end

  def test_to_sgr_with_fallback_256
    Gouache::Term.color_level = :_256
    color = Gouache::Color.rgb(255, 0, 0)
    result = color.to_sgr(fallback: true)
    assert_match(/^38;5;\d+$/, result)
  end

  def test_to_sgr_with_fallback_basic
    Gouache::Term.color_level = :basic
    # Test near-red foreground - should find nearest match to bright red
    color = Gouache::Color.rgb(254, 0, 0)
    result = color.to_sgr(fallback: true)
    assert_equal 91, result  # should map to ANSI bright red

    # Test background color
    color = Gouache::Color.on_rgb(254, 0, 0)
    result = color.to_sgr(fallback: true)
    assert_equal 101, result  # should map to ANSI bright red background
  end

  def test_to_sgr_with_fallback_basic_custom_colors
    # Test with custom basic colors to ensure stubbing works over our redefined method
    custom_colors = [
      [0, 0, 0],       # black - index 0
      [128, 0, 0],     # dark red - index 1
      [0, 128, 0],     # dark green - index 2
      [128, 128, 0],   # dark yellow - index 3
      [0, 0, 128],     # dark blue - index 4
      [128, 0, 128],   # dark magenta - index 5
      [0, 128, 128],   # dark cyan - index 6
      [192, 192, 192], # light gray - index 7
      [128, 128, 128], # dark gray - index 8
      [255, 0, 0],     # bright red - index 9
      [0, 255, 0],     # bright green - index 10
      [255, 255, 0],   # bright yellow - index 11
      [0, 0, 255],     # bright blue - index 12
      [255, 0, 255],   # bright magenta - index 13
      [0, 255, 255],   # bright cyan - index 14
      [255, 255, 255]  # white - index 15
    ]

    Gouache::Term.color_level = :basic
    Gouache::Term.stub :basic_colors, custom_colors do
      # Reset memoized colors to use stubbed basic_colors
      Gouache::Term.instance_variable_set(:@colors, nil)

      # Test that dark red [128,0,0] maps to normal red (30+1=31)
      color = Gouache::Color.rgb(128, 0, 0)
      result = color.to_sgr(fallback: true)
      assert_equal 31, result

      # Test that bright red [255,0,0] maps to bright red (90+1=91)
      color = Gouache::Color.rgb(255, 0, 0)
      result = color.to_sgr(fallback: true)
      assert_equal 91, result

      # Test background colors
      color = Gouache::Color.on_rgb(128, 0, 0)
      result = color.to_sgr(fallback: true)
      assert_equal 41, result  # dark red background

      color = Gouache::Color.on_rgb(255, 0, 0)
      result = color.to_sgr(fallback: true)
      assert_equal 101, result  # bright red background
    end
  end

  def test_to_sgr_with_direct_symbol_fallback_truecolor
    color = Gouache::Color.rgb(255, 128, 64)
    assert_equal "38;2;255;128;64", color.to_sgr(fallback: :truecolor)
  end

  def test_to_sgr_with_direct_symbol_fallback_256
    color = Gouache::Color.rgb(255, 0, 0)
    result = color.to_sgr(fallback: :_256)
    assert_match(/^38;5;\d+$/, result)
  end

  def test_to_sgr_with_direct_symbol_fallback_basic
    # Test with ANSI16 colors
    color = Gouache::Color.rgb(255, 0, 0)
    result = color.to_sgr(fallback: :basic)
    assert_equal 91, result  # bright red

    # Test background
    color = Gouache::Color.on_rgb(255, 0, 0)
    result = color.to_sgr(fallback: :basic)
    assert_equal 101, result  # bright red background

    # Test underline - should convert to 256-color format instead of basic
    color = Gouache::Color.over_rgb(255, 0, 0)
    result = color.to_sgr(fallback: :basic)
    assert_match(/^58;5;\d+$/, result)  # converts to 256-color format

    # Extract the color index and verify it's in the first 16 colors (0-15)
    color_index = result.match(/58;5;(\d+)/)[1].to_i
    assert_operator color_index, :>=, 0, "Color index should be >= 0"
    assert_operator color_index, :<=, 15, "Color index should be <= 15 (first 16 colors)"
  end

  def test_underline_basic_fallback_uses_first_16_colors
    # Test specific RGB colors with expected ANSI16 mappings based on proximity
    test_colors = [
      [[200, 0, 0], 1, "should map to red [205,0,0]"],
      [[0, 200, 0], 2, "should map to green [0,205,0]"],
      [[200, 200, 0], 3, "should map to yellow [205,205,0]"],
      [[0, 0, 230], 4, "should map to blue [0,0,238]"],
      [[200, 0, 200], 5, "should map to magenta [205,0,205]"],
      [[0, 200, 200], 6, "should map to cyan [0,205,205]"],
      [[240, 240, 240], 7, "should map to white [229,229,229]"],
      [[120, 120, 120], 8, "should map to bright black [127,127,127]"],
      [[250, 0, 0], 9, "should map to bright red [255,0,0]"],
      [[0, 250, 0], 10, "should map to bright green [0,255,0]"],
      [[250, 250, 0], 11, "should map to bright yellow [255,255,0]"],
      [[100, 100, 250], 12, "should map to bright blue [92,92,255]"],
      [[250, 0, 250], 13, "should map to bright magenta [255,0,255]"],
      [[0, 250, 250], 14, "should map to bright cyan [0,255,255]"],
      [[250, 250, 250], 15, "should map to bright white [255,255,255]"]
    ]

    test_colors.each do |rgb, expected_index, description|
      color = Gouache::Color.over_rgb(*rgb)
      result = color.to_sgr(fallback: :basic)

      # Should be in 58;5;n format
      assert_match(/^58;5;\d+$/, result, "#{description}")

      # Extract color index and verify it matches expected
      color_index = result.match(/58;5;(\d+)/)[1].to_i
      assert_equal expected_index, color_index, "RGB #{rgb} #{description}"
    end

    # Test over_default basic fallback returns "59"
    color_default = Gouache::Color.sgr(59)
    result = color_default.to_sgr(fallback: :basic)
    assert_equal 59, result, "SGR 59 should fallback to basic as '59'"
  end

  # Cross-constructor compatibility tests
  def test_rgb_method_works_from_all_constructors
    # From rgb constructor
    color1 = Gouache::Color.rgb(255, 128, 64)
    assert_equal [255, 128, 64], color1.rgb

    # From hex constructor
    color2 = Gouache::Color.hex("ff8040")
    assert_equal [255, 128, 64], color2.rgb

    # From sgr constructor
    color3 = Gouache::Color.sgr("38;2;255;128;64")
    assert_equal [255, 128, 64], color3.rgb

    # From oklch constructor (approximate)
    color4 = Gouache::Color.oklch(0.7, 0.15, 30)
    assert_equal 3, color4.rgb.size
    color4.rgb.each { |c| assert_operator c, :>=, 0; assert_operator c, :<=, 255 }
  end

  def test_oklch_method_works_from_all_constructors
    # From rgb constructor
    color1 = Gouache::Color.rgb(255, 0, 0)
    oklch1 = color1.oklch
    assert_equal 3, oklch1.size
    assert_operator oklch1[0], :>, 0  # lightness > 0
    assert_operator oklch1[1], :>, 0  # chroma > 0 for red

    # From hex constructor
    color2 = Gouache::Color.hex("ff0000")
    oklch2 = color2.oklch
    assert_equal oklch1, oklch2

    # From sgr constructor
    color3 = Gouache::Color.sgr("38;2;255;0;0")
    oklch3 = color3.oklch
    assert_equal oklch1, oklch3

    # From oklch constructor
    color4 = Gouache::Color.oklch(0.8, 0.2, 45)
    assert_equal [0.8, 0.2, 45], color4.oklch
  end

  def test_sgr_method_works_from_all_constructors
    # From rgb constructor
    color1 = Gouache::Color.rgb(100, 200, 50)
    assert_equal "38;2;100;200;50", color1.sgr

    # From hex constructor
    color2 = Gouache::Color.hex("64c832")
    assert_equal "38;2;100;200;50", color2.sgr

    # From sgr constructor
    color3 = Gouache::Color.sgr("38;2;100;200;50")
    assert_equal "38;2;100;200;50", color3.sgr

    # From oklch constructor
    color4 = Gouache::Color.oklch(0.6, 0.1, 180)
    sgr4 = color4.sgr
    assert_match(/^38;2;\d+;\d+;\d+$/, sgr4)
  end

  def test_to_sgr_method_works_from_all_constructors
    # From rgb constructor
    color1 = Gouache::Color.rgb(150, 75, 200)
    assert_equal "38;2;150;75;200", color1.to_sgr

    # From hex constructor
    color2 = Gouache::Color.hex("964bc8")
    assert_equal "38;2;150;75;200", color2.to_sgr

    # From sgr constructor
    color3 = Gouache::Color.sgr("38;2;150;75;200")
    assert_equal "38;2;150;75;200", color3.to_sgr

    # From oklch constructor
    color4 = Gouache::Color.oklch(0.5, 0.12, 270)
    sgr4 = color4.to_sgr
    assert_kind_of String, sgr4
    assert_match(/^38;2;\d+;\d+;\d+$/, sgr4)
  end

  def test_background_colors_work_across_constructors
    # Test that background constructors maintain role across all methods
    bg_color1 = Gouache::Color.on_rgb(255, 100, 0)
    assert_equal "48;2;255;100;0", bg_color1.sgr
    assert_equal "48;2;255;100;0", bg_color1.to_sgr

    bg_color2 = Gouache::Color.on_hex("ff6400")
    assert_equal "48;2;255;100;0", bg_color2.sgr
    assert_equal "48;2;255;100;0", bg_color2.to_sgr

    bg_color3 = Gouache::Color.on_oklch(0.7, 0.18, 50)
    assert_equal 48, bg_color3.role
    assert_equal 3, bg_color3.rgb.size

    sgr3 = bg_color3.sgr
    assert_match(/^48;2;\d+;\d+;\d+$/, sgr3)  # background role preserved
  end

  def test_underline_colors_work_across_constructors
    # Test that underline constructors maintain role across all methods
    ul_color1 = Gouache::Color.over_rgb(255, 100, 0)
    assert_equal "58;2;255;100;0", ul_color1.sgr
    assert_equal "58;2;255;100;0", ul_color1.to_sgr

    ul_color2 = Gouache::Color.over_hex("ff6400")
    assert_equal "58;2;255;100;0", ul_color2.sgr
    assert_equal "58;2;255;100;0", ul_color2.to_sgr

    ul_color3 = Gouache::Color.over_oklch(0.7, 0.18, 50)
    assert_equal 58, ul_color3.role
    assert_equal 3, ul_color3.rgb.size

    sgr3 = ul_color3.sgr
    assert_match(/^58;2;\d+;\d+;\d+$/, sgr3)  # underline role preserved
  end

  def test_roundtrip_consistency
    # Test that converting through different representations maintains consistency
    original_rgb = [180, 90, 240]

    # RGB -> HEX -> RGB
    color1 = Gouache::Color.rgb(*original_rgb)
    hex_string = "%02x%02x%02x" % original_rgb
    color2 = Gouache::Color.hex(hex_string)
    assert_equal original_rgb, color2.rgb

    # RGB -> OKLCH -> RGB (approximate due to color space conversion)
    oklch = color1.oklch
    color3 = Gouache::Color.oklch(*oklch)
    rgb_back = color3.rgb
    original_rgb.each_with_index do |expected, i|
      assert_in_delta expected, rgb_back[i], 2, "RGB roundtrip component #{i}"
    end

    # RGB -> SGR -> RGB
    sgr = color1.sgr
    color4 = Gouache::Color.sgr(sgr)
    assert_equal original_rgb, color4.rgb
  end

  def test_initialize_valid_cases
    # Test basic SGR ranges
    color = Gouache::Color.new(sgr: 31)
    assert_equal 31, color.sgr

    color = Gouache::Color.new(sgr: "38;5;196")
    assert_equal 38, color.role

    color = Gouache::Color.new(sgr: "38;2;255;128;64")
    assert_equal [255, 128, 64], color.rgb

    # Test SGR 59 (over_default)
    color = Gouache::Color.new(sgr: 59)
    assert_equal 59, color.sgr
    assert_equal 58, color.role

    # Test role + rgb
    color = Gouache::Color.new(role: 38, rgb: [255, 0, 0])
    assert_equal [255, 0, 0], color.rgb
    assert_equal 38, color.role

    # Test role + hex
    color = Gouache::Color.new(role: 48, rgb: "ff0000")
    assert_equal [255, 0, 0], color.rgb
    assert_equal 48, color.role

    # Test role + oklch
    color = Gouache::Color.new(role: 38, oklch: [0.7, 0.15, 30])
    assert_equal 38, color.role

    # Test role + gray
    color = Gouache::Color.new(role: 38, gray: 12)
    assert_equal 38, color.role

    # Test role + cube
    color = Gouache::Color.new(role: 48, cube: [5, 0, 0])
    assert_equal 48, color.role

    # Test underline role (58)
    color = Gouache::Color.new(role: 58, rgb: [255, 0, 0])
    assert_equal [255, 0, 0], color.rgb
    assert_equal 58, color.role

    color = Gouache::Color.new(role: 58, oklch: [0.8, 0.12, 60])
    assert_equal 58, color.role

    color = Gouache::Color.new(role: 58, gray: 15)
    assert_equal 58, color.role

    color = Gouache::Color.new(role: 58, cube: [3, 4, 2])
    assert_equal 58, color.role

    # Test underline SGR sequences
    color = Gouache::Color.new(sgr: "58;5;196")
    assert_equal 58, color.role

    color = Gouache::Color.new(sgr: "58;2;255;128;64")
    assert_equal [255, 128, 64], color.rgb
    assert_equal 58, color.role
  end

  def test_initialize_constraint_failures
    # Test invalid SGR values
    assert_raises(ArgumentError) do
      Gouache::Color.new(sgr: 999)
    end

    assert_raises(ArgumentError) do
      Gouache::Color.new(sgr: "invalid")
    end

    # Test invalid role values
    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 99, rgb: [255, 0, 0])
    end

    # Test invalid RGB values (out of 0..255 range)
    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, rgb: [256, 0, 0])
    end

    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, rgb: [-1, 0, 0])
    end

    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, rgb: [255, 0])  # not 3 elements
    end

    # Test invalid hex format
    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, rgb: "gghhii")  # invalid hex
    end

    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, rgb: "fff")  # too short
    end

    # Test invalid OKLCH values
    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, oklch: [1.5, 0.1, 30])  # lightness > 1
    end

    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, oklch: [0.7, -0.1, 30])  # negative chroma
    end

    # Test invalid gray range
    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, gray: 24)  # > 23
    end

    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, gray: -1)  # < 0
    end

    # Test invalid cube values
    assert_raises(ArgumentError) do
      Gouache::Color.new(role: 38, cube: [6, 0, 0])  # > 5 (cube is 6x6x6, so 0-5)
    end

    # Test no matching pattern
    assert_raises(ArgumentError) do
      Gouache::Color.new(invalid: true)
    end

    # Test empty arguments
    assert_raises(ArgumentError) do
      Gouache::Color.new
    end
  end

  def test_merge_instance_method_same_role
    color1 = Gouache::Color.rgb(255, 0, 0)    # has rgb
    color2 = Gouache::Color.cube(5, 0, 0)     # has _256
    color3 = Gouache::Color.sgr(31)           # has sgr

    merged = color1.merge(color2)
    assert_equal [255, 0, 0], merged.rgb
    assert_equal 196, merged._256

    merged = color2.merge(color3)
    assert_equal "38;5;196", merged.sgr
    assert_equal 196, merged._256
    assert_equal 31, merged.basic
  end

  def test_merge_instance_method_different_roles
    fg_color = Gouache::Color.rgb(255, 0, 0)
    bg_color = Gouache::Color.on_rgb(0, 255, 0)

    assert_raises(ArgumentError, "different roles") do
      fg_color.merge(bg_color)
    end
  end

  def test_merge_class_method_single_role
    colors = [
      Gouache::Color.rgb(255, 0, 0),
      Gouache::Color.cube(5, 0, 0),
      Gouache::Color.sgr(31)
    ]

    result = Gouache::Color.merge(*colors)
    assert_equal 3, result.length
    assert_kind_of Gouache::Color, result[0]
    assert_nil result[1]  # no background colors
    assert_nil result[2]  # no underline colors
  end

  def test_merge_class_method_mixed_roles
    colors = [
      Gouache::Color.rgb(255, 0, 0),      # fg
      Gouache::Color.on_cube(0, 5, 0),    # bg
      Gouache::Color.sgr(31),             # fg
      Gouache::Color.sgr(42)              # bg
    ]

    fg, bg, ul = Gouache::Color.merge(*colors)
    assert_kind_of Gouache::Color, fg
    assert_kind_of Gouache::Color, bg
    assert_nil ul  # no underline colors
    assert_equal 38, fg.role
    assert_equal 48, bg.role
  end

  def test_merge_class_method_empty
    result = Gouache::Color.merge()
    assert_equal [nil, nil, nil], result
  end

  def test_merge_class_method_with_underline_colors
    colors = [
      Gouache::Color.rgb(255, 0, 0),        # fg
      Gouache::Color.on_rgb(0, 255, 0),     # bg
      Gouache::Color.over_rgb(0, 0, 255),   # ul
      Gouache::Color.sgr(31),               # fg
      Gouache::Color.over_cube(5, 2, 1)     # ul
    ]

    fg, bg, ul = Gouache::Color.merge(*colors)
    assert_kind_of Gouache::Color, fg
    assert_kind_of Gouache::Color, bg
    assert_kind_of Gouache::Color, ul
    assert_equal 38, fg.role
    assert_equal 48, bg.role
    assert_equal 58, ul.role

    # Check merged underline has both representations
    assert_equal [0, 0, 255], ul.rgb
    assert_equal 209, ul._256  # cube(5,2,1) = 16 + 36*5 + 6*2 + 1
  end

  def test_merge_preserves_fallback_chain
    # Test that merge creates a color with multiple fallback options
    rgb_color = Gouache::Color.rgb(255, 128, 64)
    cube_color = Gouache::Color.cube(5, 2, 1)
    sgr_color = Gouache::Color.sgr(91)

    merged = rgb_color.merge(cube_color).merge(sgr_color)

    # Should have all three representations available
    assert_equal [255, 128, 64], merged.rgb
    assert_equal 209, merged._256  # cube(5,2,1) = 16 + 36*5 + 6*2 + 1
    assert_equal "38;2;255;128;64", merged.sgr
    assert_equal 91, merged.basic
  end

  def test_sgr_prefers_highest_representation
    # Test that .sgr method uses highest available representation
    color_with_all = Gouache::Color.rgb(255, 0, 0).merge(Gouache::Color.cube(5, 0, 0)).merge(Gouache::Color.sgr(31))

    # Should prefer RGB (highest) over 256-color or basic SGR
    assert_equal "38;2;255;0;0", color_with_all.sgr
  end

  def test_sgr_fallback_hierarchy
    # Test SGR fallback when higher representations not available
    sgr_only = Gouache::Color.sgr(31)
    assert_equal 31, sgr_only.sgr

    cube_and_sgr = Gouache::Color.cube(5, 0, 0).merge(Gouache::Color.sgr(31))
    assert_equal "38;5;196", cube_and_sgr.sgr
  end

  def test_to_sgr_respects_fallback_with_merged_colors
    # Test that to_sgr with fallback uses appropriate representation from merged color
    merged = Gouache::Color.rgb(255, 0, 0).merge(Gouache::Color.cube(5, 0, 0)).merge(Gouache::Color.sgr(31))

    # Without fallback - uses highest (RGB)
    assert_equal "38;2;255;0;0", merged.to_sgr

    # With fallback to basic - should use SGR representation from merge
    assert_equal 31, merged.to_sgr(fallback: :basic)

    # With fallback to 256 - should use 256-color representation from merge
    assert_equal "38;5;196", merged.to_sgr(fallback: :_256)

    # Test .basic method on merged color
    assert_equal 31, merged.basic
  end

  def test_to_sgr_with_symbol_fallback_on_merged_colors
    # Test merged color with all representations available
    merged = Gouache::Color.rgb(255, 128, 64).merge(Gouache::Color.cube(5, 0, 0)).merge(Gouache::Color.sgr(31))

    # Test each fallback symbol uses correct representation from merge
    assert_equal "38;2;255;128;64", merged.to_sgr(fallback: :truecolor)
    assert_equal "38;5;196", merged.to_sgr(fallback: :_256)
    assert_equal 31, merged.to_sgr(fallback: :basic)

    # Test merged color with only some representations
    partial_merged = Gouache::Color.cube(5, 0, 0).merge(Gouache::Color.sgr(31))
    assert_equal "38;5;196", partial_merged.to_sgr(fallback: :truecolor)  # falls back to best available
    assert_equal "38;5;196", partial_merged.to_sgr(fallback: :_256)
    assert_equal 31, partial_merged.to_sgr(fallback: :basic)
  end

  def test_sgr_basic_ranges_coverage
    # Test 39 (default fg) - integer and string
    color39 = Gouache::Color.sgr(39)
    assert_equal 39, color39.sgr

    color39_str = Gouache::Color.sgr("39")
    assert_equal 39, color39_str.sgr
    assert_equal color39.sgr, color39_str.sgr

    # Test 49 (default bg) - integer and string
    color49 = Gouache::Color.sgr(49)
    assert_equal 49, color49.sgr

    color49_str = Gouache::Color.sgr("49")
    assert_equal 49, color49_str.sgr
    assert_equal color49.sgr, color49_str.sgr

    # Test 59 (default underline color) - integer and string
    color59 = Gouache::Color.sgr(59)
    assert_equal 59, color59.sgr
    assert_equal 58, color59.role

    color59_str = Gouache::Color.sgr("59")
    assert_equal 59, color59_str.sgr
    assert_equal 58, color59_str.role
    assert_equal color59.sgr, color59_str.sgr

    # Test 30-37 (normal fg colors)
    (30..37).each do |n|
      color = Gouache::Color.sgr(n)
      assert_equal n, color.sgr
      assert_equal 38, color.role
    end

    # Test 40-47 (normal bg colors)
    (40..47).each do |n|
      color = Gouache::Color.sgr(n)
      assert_equal n, color.sgr
      assert_equal 48, color.role
    end

    # Test 90-97 (bright fg colors)
    (90..97).each do |n|
      color = Gouache::Color.sgr(n)
      assert_equal n, color.sgr
      assert_equal 38, color.role
    end

    # Test 100-107 (bright bg colors)
    (100..107).each do |n|
      color = Gouache::Color.sgr(n)
      assert_equal n, color.sgr
      assert_equal 48, color.role
    end

  end

  def test_equality_operator
    # Test Color == Color
    color1 = Gouache::Color.rgb(255, 0, 0)
    color2 = Gouache::Color.rgb(255, 0, 0)
    color3 = Gouache::Color.rgb(0, 255, 0)
    assert_equal color1, color2
    refute_equal color1, color3

    # Test Color == Integer (SGR value)
    basic_color = Gouache::Color.sgr(31)
    assert_equal basic_color, 31
    refute_equal basic_color, 32

    # Test Color == String (SGR string)
    rgb_color = Gouache::Color.rgb(255, 0, 0)
    assert_equal rgb_color, "38;2;255;0;0"
    refute_equal rgb_color, "38;2;0;255;0"

    # Test with other objects
    refute_equal color1, nil
    refute_equal color1, []
    refute_equal color1, "not_sgr"
  end

  def test_equality_operator_with_merged_colors
    # Test merged colors equality
    merged1 = Gouache::Color.rgb(255, 0, 0).merge(Gouache::Color.sgr(31))
    merged2 = Gouache::Color.rgb(255, 0, 0).merge(Gouache::Color.sgr(91))

    # Both should have same SGR (RGB takes precedence)
    assert_equal merged1, merged2
    assert_equal merged1, "38;2;255;0;0"
    assert_equal merged2, "38;2;255;0;0"

    # Test merged color with basic-only representation
    basic_merged = Gouache::Color.sgr(31).merge(Gouache::Color.cube(5, 0, 0))
    assert_equal basic_merged, "38;5;196"  # cube takes precedence
    # Cannot compare to integer since SGR is "38;5;196" (string with semicolon)
  end

  def test_to_sgr_invalid_fallback_symbols
    color = Gouache::Color.rgb(255, 0, 0)

    assert_raises(NoMatchingPatternError) do
      color.to_sgr(fallback: :invalid)
    end

    assert_raises(NoMatchingPatternError) do
      color.to_sgr(fallback: :rainbow)
    end
  end

  def test_merge_conflicting_roles_error
    fg_color1 = Gouache::Color.rgb(255, 0, 0)
    fg_color2 = Gouache::Color.rgb(0, 255, 0)
    bg_color = Gouache::Color.on_rgb(0, 0, 255)

    # Same roles should merge fine
    merged_fg = fg_color1.merge(fg_color2)
    assert_kind_of Gouache::Color, merged_fg

    # Different roles should raise error
    assert_raises(ArgumentError, "different roles") do
      fg_color1.merge(bg_color)
    end

    assert_raises(ArgumentError, "different roles") do
      bg_color.merge(fg_color1)
    end
  end

  def test_change_role_method
    # Test changing foreground to background for basic SGR colors
    fg_red = Gouache::Color.sgr(31)  # foreground red
    bg_red = fg_red.change_role(48)  # change to background

    assert_equal 48, bg_red.role
    assert_equal 41, bg_red.basic  # 31 + 10 = 41
    assert_equal bg_red, Gouache::Color.sgr(41)

    # Test changing background to foreground
    bg_green = Gouache::Color.sgr(42)  # background green
    fg_green = bg_green.change_role(38)  # change to foreground

    assert_equal 38, fg_green.role
    assert_equal 32, fg_green.basic  # 42 - 10 = 32
    assert_equal fg_green, Gouache::Color.sgr(32)

    # Test with bright colors
    bright_fg = Gouache::Color.sgr(91)  # bright red foreground
    bright_bg = bright_fg.change_role(48)  # change to background

    assert_equal 48, bright_bg.role
    assert_equal 101, bright_bg.basic  # 91 + 10 = 101
    assert_equal bright_bg, Gouache::Color.sgr(101)

    # Test no change when role is same
    original = Gouache::Color.sgr(31)
    unchanged = original.change_role(38)  # already foreground

    assert_same original, unchanged

    # Test with non-basic colors (RGB) - should preserve other attributes
    rgb_color = Gouache::Color.rgb(255, 128, 64)  # foreground
    bg_rgb_color = rgb_color.change_role(48)  # change to background

    assert_equal 48, bg_rgb_color.role
    assert_equal [255, 128, 64], bg_rgb_color.rgb
    assert_nil bg_rgb_color.instance_variable_get(:@sgr_basic)  # no basic SGR for RGB colors

    # Test with 256-color
    color_256 = Gouache::Color.sgr("38;5;196")  # 256-color foreground
    bg_256 = color_256.change_role(48)  # change to background

    assert_equal 48, bg_256.role
    assert_equal 196, bg_256._256
    assert_nil bg_256.instance_variable_get(:@sgr_basic)  # no basic SGR for 256-colors

    # Test with merged colors - merge different color representations
    fg_rgb = Gouache::Color.rgb(255, 0, 0)    # RGB red
    fg_cube = Gouache::Color.cube(5, 0, 0)    # cube red (same as RGB)
    merged_fg = fg_rgb.merge(fg_cube)         # merged foreground color

    bg_merged = merged_fg.change_role(48)     # change to background
    assert_equal 48, bg_merged.role
    assert_equal [255, 0, 0], bg_merged.rgb  # preserves RGB
    assert_equal 196, bg_merged._256          # preserves cube _256

    # Test another merged color combination
    fg_basic = Gouache::Color.sgr(31)         # basic red
    fg_256 = Gouache::Color.sgr("38;5;196")   # 256-color red
    merged_complex = fg_basic.merge(fg_256)

    bg_complex = merged_complex.change_role(48)
    assert_equal 48, bg_complex.role
    assert_equal 41, bg_complex.basic        # basic red background
    assert_equal 196, bg_complex._256         # preserves 256-color

    # Test changing to underline role
    fg_basic = Gouache::Color.sgr(31)         # basic red foreground
    ul_basic = fg_basic.change_role(58)       # change to underline

    assert_equal 58, ul_basic.role
    assert_equal 59, ul_basic.basic           # underline returns 59 (over_default)
    assert_equal [205, 0, 0], ul_basic.rgb    # RGB calculated from basic

    # Test changing RGB color to underline
    rgb_color = Gouache::Color.rgb(100, 150, 200)
    ul_rgb = rgb_color.change_role(58)

    assert_equal 58, ul_rgb.role
    assert_equal [100, 150, 200], ul_rgb.rgb
    assert_equal 59, ul_rgb.basic

    # Test changing 256-color to underline
    color_256 = Gouache::Color.sgr("38;5;196")
    ul_256 = color_256.change_role(58)

    assert_equal 58, ul_256.role
    assert_equal 196, ul_256._256
    assert_equal 59, ul_256.basic

    # Test UL-to-UL change_role edge case (sgr_basic = UL logic)
    ul_color = Gouache::Color.sgr(59)         # underline default color
    ul_same = ul_color.change_role(58)        # change from UL to UL

    assert_equal 58, ul_same.role
    assert_equal 59, ul_same.basic
    assert_same ul_color, ul_same             # should return self when no change needed
  end

  def test_to_i_method_extracts_sgr_prefix
    # to_i should extract the numeric prefix from SGR sequences
    bg_color = Gouache::Color.new(sgr: "48;5;123")
    assert_equal 48, bg_color.to_i

    # Also test with foreground 256-color for comparison
    fg_color = Gouache::Color.new(sgr: "38;5;123")
    assert_equal 38, fg_color.to_i
  end

  def test_to_s
    # to_s should be string version of to_sgr
    color = Gouache::Color.new(sgr: "38;2;255;128;64")
    assert_equal color.to_sgr.to_s, color.to_s

    # Test with fallback parameter
    assert_equal color.to_sgr(fallback: :_256).to_s, color.to_s(fallback: :_256)
    assert_equal color.to_sgr(fallback: :basic).to_s, color.to_s(fallback: :basic)
  end

  def test_to_s_simple_sgr_returns_string
    # to_s should return string for simple SGR codes like 31
    color = Gouache::Color.new(sgr: 31)
    assert_equal "31", color.to_s
  end

  def test_to_s_simple_sgr_with_fallbacks
    # to_s should return strings with all fallback variations
    color = Gouache::Color.new(sgr: 42)

    # No fallback
    assert_equal "42", color.to_s

    # fallback: false
    assert_equal "42", color.to_s(fallback: false)

    # fallback: true
    assert_equal "42", color.to_s(fallback: true)

    # fallback: :truecolor
    assert_equal "42", color.to_s(fallback: :truecolor)

    # fallback: :_256
    assert_equal "42", color.to_s(fallback: :_256)

    # fallback: :basic
    assert_equal "42", color.to_s(fallback: :basic)
  end

  def test_fallback_no_upconversion_basic_to_256
    # Fallback should not upconvert basic colors to 256-color
    basic_color = Gouache::Color.new(sgr: 42)  # basic green background

    # Should stay as basic when requesting basic fallback
    assert_equal 42, basic_color.to_sgr(fallback: :basic)

    # Should not upconvert to 256-color when requesting 256 fallback
    refute_equal "48;5;2", basic_color.to_sgr(fallback: :_256)
  end

  def test_fallback_no_upconversion_256_to_truecolor
    # Fallback should not upconvert 256-color to truecolor
    color_256 = Gouache::Color.new(sgr: "38;5;196")  # 256-color red

    # Should stay as 256-color when requesting truecolor fallback
    assert_equal "38;5;196", color_256.to_sgr(fallback: :truecolor)
  end

  def test_fallback_downconversion_only
    # Fallback should only provide downward conversion paths
    truecolor = Gouache::Color.new(sgr: "38;2;255;0;0")  # truecolor red

    # Should downconvert to 256-color
    result_256 = truecolor.to_s(fallback: :_256)
    assert result_256.start_with?("38;5;"), "Should downconvert to 256-color format"

    # Should downconvert to basic
    result_basic = truecolor.to_s(fallback: :basic)
    refute result_basic.include?(";"), "Basic fallback should not contain semicolons"

    # Test underline color special case - basic fallback converts to 256-color
    underline_truecolor = Gouache::Color.new(sgr: "58;2;255;0;0")  # underline truecolor red
    ul_basic = underline_truecolor.to_s(fallback: :basic)
    assert ul_basic.start_with?("58;5;"), "Underline basic fallback should convert to 256-color format"
    assert ul_basic.include?(";"), "Underline basic fallback should contain semicolons (256-color format)"
  end

  def test_oklch_shift_method
    color = Gouache::Color.oklch(0.7, 0.15, 180)

    # Test basic shifting
    shifted = color.oklch_shift(0.1, 0.05, 90)
    l, c, h = shifted.oklch
    assert_in_delta 0.8, l, 0.001
    assert_in_delta 0.2, c, 0.001
    assert_in_delta 270, h, 0.001

    # Test lightness clamping
    bright = color.oklch_shift(0.5, 0, 0)  # would be 1.2, should clamp to 1.0
    assert_equal 1.0, bright.oklch[0]

    dark = color.oklch_shift(-1.0, 0, 0)   # would be -0.3, should clamp to 0.0
    assert_equal 0.0, dark.oklch[0]

    # Test chroma clamping (no negative values)
    low_chroma = color.oklch_shift(0, -0.3, 0)  # would be -0.15, should clamp to 0.0
    assert_equal 0.0, low_chroma.oklch[1]

    # Test role preservation
    bg_color = Gouache::Color.on_oklch(0.5, 0.1, 120)
    shifted_bg = bg_color.oklch_shift(0.1, 0, 60)
    assert_equal Gouache::Color::BG, shifted_bg.role
  end

  def test_fallback_sgr_rgb_merge_prefers_conversion_to_256
    # Color with SGR and RGB but no 256 part should fallback to 256 by converting RGB, not using SGR
    sgr_color = Gouache::Color.sgr(31)
    rgb_color = Gouache::Color.rgb(1, 2, 3)
    merged = sgr_color.merge(rgb_color)

    # Should convert RGB to 256-color, not fall back to SGR basic
    result = merged.to_s(fallback: :_256)
    assert result.start_with?("38;5;"), "Should convert RGB to 256-color format, got: #{result}"
    refute_equal "31", result, "Should not fall back to SGR basic"
  end

  def test_rgb_shift_method
    color = Gouache::Color.rgb(100, 150, 200)

    # Test basic shifting
    shifted = color.rgb_shift(50, -25, 30)
    assert_equal [150, 125, 230], shifted.rgb

    # Test clamping at upper bound
    bright = color.rgb_shift(200, 200, 200)  # would exceed 255
    assert_equal [255, 255, 255], bright.rgb

    # Test clamping at lower bound
    dark = color.rgb_shift(-200, -200, -250)  # would go below 0
    assert_equal [0, 0, 0], dark.rgb

    # Test role preservation
    bg_color = Gouache::Color.on_rgb(50, 100, 150)
    shifted_bg = bg_color.rgb_shift(10, 20, 30)
    assert_equal Gouache::Color::BG, shifted_bg.role
    assert_equal [60, 120, 180], shifted_bg.rgb
  end

  def test_oklch_shift_with_wrapped_absolute_values
    color = Gouache::Color.oklch(0.7, 0.15, 180)

    # Test absolute replacement with wrapped values
    shifted = color.oklch_shift([0.5], [0.3], [270])
    l, c, h = shifted.oklch
    assert_in_delta 0.5, l, 0.001  # absolute replacement, not 0.7 + 0.5
    assert_in_delta 0.3, c, 0.001  # absolute replacement, not 0.15 + 0.3
    assert_in_delta 270, h, 0.001  # absolute replacement, not 180 + 270

    # Test mixed delta and absolute
    mixed = color.oklch_shift(0.1, [0.25], 45)  # delta, absolute, delta
    l2, c2, h2 = mixed.oklch
    assert_in_delta 0.8, l2, 0.001   # 0.7 + 0.1 (delta)
    assert_in_delta 0.25, c2, 0.001  # 0.25 (absolute)
    assert_in_delta 225, h2, 0.001   # 180 + 45 (delta)

    # Test with clamping on absolute values
    clamped = color.oklch_shift([1.5], [-0.1], [400])
    l3, c3, h3 = clamped.oklch
    assert_equal 1.0, l3  # clamped from 1.5 to 1.0
    assert_equal 0.0, c3  # clamped from -0.1 to 0.0
    assert_in_delta 400, h3, 0.001  # hue not clamped, wraps naturally
  end

  def test_rgb_shift_with_wrapped_absolute_values
    color = Gouache::Color.rgb(100, 150, 200)

    # Test absolute replacement with wrapped values
    shifted = color.rgb_shift([50], [75], [250])
    assert_equal [50, 75, 250], shifted.rgb

    # Test mixed delta and absolute
    mixed = color.rgb_shift(25, [100], -50)  # delta, absolute, delta
    assert_equal [125, 100, 150], mixed.rgb  # 100+25, 100, 200-50

    # Test with clamping on absolute values
    clamped = color.rgb_shift([300], [-10], [500])
    assert_equal [255, 0, 255], clamped.rgb  # all clamped to valid range
  end

  def test_rgb_shift_with_floats_returns_integers
    color = Gouache::Color.rgb(100, 150, 200)

    # Test that float deltas get converted to integers
    shifted = color.rgb_shift(10.7, -25.3, 30.9)
    r, g, b = shifted.rgb
    assert_instance_of Integer, r
    assert_instance_of Integer, g
    assert_instance_of Integer, b
    assert_equal [111, 125, 231], [r, g, b]  # rounded values

    # Test with wrapped float absolutes
    absolute = color.rgb_shift([50.6], [75.2], [250.8])
    r2, g2, b2 = absolute.rgb
    assert_instance_of Integer, r2
    assert_instance_of Integer, g2
    assert_instance_of Integer, b2
    assert_equal [51, 75, 251], [r2, g2, b2]  # rounded values
  end

  def test_oklch_shift_with_invalid_arguments
    color = Gouache::Color.oklch(0.7, 0.15, 180)

    # Test invalid argument types
    assert_raises(ArgumentError) { color.oklch_shift("bad", 0, 0) }
    assert_raises(ArgumentError) { color.oklch_shift(0, nil, 0) }
    assert_raises(ArgumentError) { color.oklch_shift(0, 0, {}) }

    # Test invalid wrapped array structure
    assert_raises(ArgumentError) { color.oklch_shift([1, 2], 0, 0) }  # multiple elements
    assert_raises(ArgumentError) { color.oklch_shift([], 0, 0) }      # empty array
    assert_raises(ArgumentError) { color.oklch_shift(0, 0, ["bad"]) } # non-numeric in array

    # Test wrong number of arguments
    assert_raises(ArgumentError) { color.oklch_shift(0, 0) }          # too few
    assert_raises(ArgumentError) { color.oklch_shift(0, 0, 0, 0) }    # too many
  end

  def test_rgb_shift_with_invalid_arguments
    color = Gouache::Color.rgb(100, 150, 200)

    # Test invalid argument types
    assert_raises(ArgumentError) { color.rgb_shift("bad", 0, 0) }
    assert_raises(ArgumentError) { color.rgb_shift(0, true, 0) }
    assert_raises(ArgumentError) { color.rgb_shift(0, 0, []) }        # empty array

    # Test invalid wrapped array structure
    assert_raises(ArgumentError) { color.rgb_shift([10, 20], 0, 0) }  # multiple elements
    assert_raises(ArgumentError) { color.rgb_shift(0, ["text"], 0) }  # non-numeric in array
    assert_raises(ArgumentError) { color.rgb_shift(0, 0, [nil]) }     # nil in array

    # Test wrong number of arguments
    assert_raises(ArgumentError) { color.rgb_shift(0) }               # too few
    assert_raises(ArgumentError) { color.rgb_shift(0, 0, 0, 0, 0) }   # too many
  end


end
