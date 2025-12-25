# frozen_string_literal: true

require "test_helper"

class TestColor < Minitest::Test
  include TestTermHelpers

  def setup
    setup_term_isolation
  end

  def teardown
    teardown_term_isolation
  end

  def test_rgb_constructor
    color = Gouache::Color.rgb(255, 0, 0)
    assert_equal [255, 0, 0], color.rgb
  end

  def test_on_rgb_constructor
    color = Gouache::Color.on_rgb(0, 255, 0)
    assert_equal [0, 255, 0], color.rgb
    assert_equal "48;2;0;255;0", color.sgr
  end

  def test_hex_constructor
    color = Gouache::Color.hex("ff0000")
    assert_equal [255, 0, 0], color.rgb
  end

  def test_on_hex_constructor
    color = Gouache::Color.on_hex("00ff00")
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
    Gouache::Term.stub :color_level, :truecolor do
      color = Gouache::Color.rgb(255, 128, 64)
      assert_equal "38;2;255;128;64", color.to_sgr(fallback: true)
    end
  end

  def test_to_sgr_with_fallback_256
    Gouache::Term.stub :color_level, :_256 do
      color = Gouache::Color.rgb(255, 0, 0)
      result = color.to_sgr(fallback: true)
      assert_match(/^38;5;\d+$/, result)
    end
  end

  def test_to_sgr_with_fallback_basic
    Gouache::Term.stub :color_level, :basic do
      # Test near-red foreground - should find nearest match to bright red
      color = Gouache::Color.rgb(254, 0, 0)
      result = color.to_sgr(fallback: true)
      assert_equal 91, result  # should map to ANSI bright red

      # Test background color
      color = Gouache::Color.on_rgb(254, 0, 0)
      result = color.to_sgr(fallback: true)
      assert_equal 101, result  # should map to ANSI bright red background
    end
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

    Gouache::Term.stub :color_level, :basic do
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
    assert_equal 2, result.length
    assert_kind_of Gouache::Color, result[0]
    assert_nil result[1]  # no background colors
  end

  def test_merge_class_method_mixed_roles
    colors = [
      Gouache::Color.rgb(255, 0, 0),      # fg
      Gouache::Color.on_cube(0, 5, 0),    # bg
      Gouache::Color.sgr(31),             # fg
      Gouache::Color.sgr(42)              # bg
    ]

    fg, bg = Gouache::Color.merge(*colors)
    assert_kind_of Gouache::Color, fg
    assert_kind_of Gouache::Color, bg
    assert_equal 38, fg.role
    assert_equal 48, bg.role
  end

  def test_merge_class_method_empty
    result = Gouache::Color.merge()
    assert_equal [nil, nil], result
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
end
