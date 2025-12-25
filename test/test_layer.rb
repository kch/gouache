# frozen_string_literal: true

require_relative "test_helper"

class TestLayer < Minitest::Test
  include TestTermHelpers

  def setup
    setup_term_isolation

    @layer = Gouache::Layer.empty
    @fg_pos = Gouache::Layer::RANGES.for(31).first
    @bg_pos = Gouache::Layer::RANGES.for(42).first
    @italic_pos = Gouache::Layer::RANGES.for(3).first
    @underline_pos = Gouache::Layer::RANGES.for(4).first
    @bold_pos = Gouache::Layer::RANGES.for(1).first
    @dim_pos = Gouache::Layer::RANGES.for(2).first
  end

  def teardown
    teardown_term_isolation
  end

  def test_layer_empty
    layer = Gouache::Layer.empty
    assert_equal 11, layer.length
    assert layer.all?(&:nil?)
  end

  def test_layer_empty_is_different_instances
    layer1 = Gouache::Layer.empty
    layer2 = Gouache::Layer.empty
    refute_same layer1, layer2
    assert_equal layer1, layer2
  end

  def test_layer_from_sgr_codes
    layer = Gouache::Layer.from([1, 31, 42])
    refute layer[@fg_pos].nil?  # fg
    refute layer[@bg_pos].nil?  # bg
    refute layer[@bold_pos].nil?  # bold
  end

  def test_layer_from_sgr_codes_varargs
    layer = Gouache::Layer.from(1, 31, 42)
    refute layer[@fg_pos].nil?  # fg
    refute layer[@bg_pos].nil?  # bg
    refute layer[@bold_pos].nil?  # bold
  end

  def test_layer_from_bold
    layer = Gouache::Layer.from([1])
    assert_equal 1, layer[@bold_pos]
  end

  def test_layer_from_bold_varargs
    layer = Gouache::Layer.from(1)
    assert_equal 1, layer[@bold_pos]
  end

  def test_layer_from_dim
    layer = Gouache::Layer.from([2])
    assert_equal 2, layer[@dim_pos]
  end

  def test_layer_from_bold_and_dim_mixed
    layer = Gouache::Layer.from([1, 2])
    assert_equal 1, layer[@bold_pos]
    assert_equal 2, layer[@dim_pos]
  end

  def test_layer_from_foreground_colors
    layer = Gouache::Layer.from([31])  # red
    assert_equal 31, layer[@fg_pos]

    layer = Gouache::Layer.from([91])  # bright red
    assert_equal 91, layer[@fg_pos]

    layer = Gouache::Layer.from([39])  # reset fg
    assert_equal 39, layer[@fg_pos]
  end

  def test_layer_from_background_colors
    layer = Gouache::Layer.from([42])  # green bg
    assert_equal 42, layer[@bg_pos]

    layer = Gouache::Layer.from([102])  # bright green bg
    assert_equal 102, layer[@bg_pos]

    layer = Gouache::Layer.from([49])  # reset bg
    assert_equal 49, layer[@bg_pos]
  end

  def test_layer_from_italic
    layer = Gouache::Layer.from([3])
    assert_equal 3, layer[@italic_pos]

    layer = Gouache::Layer.from([23])  # reset italic
    assert_equal 23, layer[@italic_pos]
  end

  def test_layer_from_underline
    layer = Gouache::Layer.from([4])
    assert_equal 4, layer[@underline_pos]

    layer = Gouache::Layer.from([21])  # double underline
    assert_equal 21, layer[@underline_pos]

    layer = Gouache::Layer.from([24])  # reset underline
    assert_equal 24, layer[@underline_pos]
  end

  def test_to_sgr_with_fallback_delegation
    # Test that Layer.to_sgr delegates to Color.to_sgr with fallback
    color = Gouache::Color.rgb(255, 0, 0)
    layer = Gouache::Layer.from(color)

    # Without fallback
    assert_equal "38;2;255;0;0", layer.to_sgr

    # With fallback - should delegate to Color
    assert_equal "38;2;255;0;0", layer.to_sgr(fallback: :truecolor)
    assert_match(/^38;5;\d+$/, layer.to_sgr(fallback: :_256))
    assert_equal "91", layer.to_sgr(fallback: :basic)

    # With fallback: true - should use Term.color_level
    Gouache::Term.stub :color_level, :basic do
      assert_equal "91", layer.to_sgr(fallback: true)
    end
  end

  def test_layer_from_multiple_codes
    layer = Gouache::Layer.from([1, 31, 4, 42])
    assert_equal 1, layer[@bold_pos]   # bold
    assert_equal 31, layer[@fg_pos]  # red fg
    assert_equal 4, layer[@underline_pos]   # underline
    assert_equal 42, layer[@bg_pos]  # green bg
  end

  def test_layer_from_multiple_codes_varargs
    layer = Gouache::Layer.from(1, 31, 4, 42)
    assert_equal 1, layer[@bold_pos]   # bold
    assert_equal 31, layer[@fg_pos]  # red fg
    assert_equal 4, layer[@underline_pos]   # underline
    assert_equal 42, layer[@bg_pos]  # green bg
  end

  def test_layer_overlay_with_nil
    result = @layer.overlay(nil)
    assert_equal @layer, result
    refute_same @layer, result  # should be a dup
  end

  def test_layer_overlay_nil_inherits_values
    # Test that overlaying nil on a layer with values inherits the underlayer values
    base = Gouache::Layer.from(1, 31)  # bold red
    result = base.overlay(nil)

    # Result should inherit bold and red from base layer
    assert_equal 1, result[@bold_pos]
    assert_equal 31, result[@fg_pos]
    assert_equal base, result
    refute_same base, result
  end

  def test_layer_overlay_basic
    base = Gouache::Layer.from([1, 31])    # bold red
    overlay = Gouache::Layer.from([4, 32]) # underline green

    result = base.overlay(overlay)
    assert_equal 1, result[@bold_pos]   # bold preserved
    assert_equal 32, result[@fg_pos]  # green overrides red
    assert_equal 4, result[@underline_pos]   # underline added
  end

  def test_layer_overlay_with_nils
    base = Gouache::Layer.from([1, 31])
    overlay = Gouache::Layer.empty
    overlay[@underline_pos] = 4  # just underline

    result = base.overlay(overlay)
    assert_equal 1, result[@bold_pos]   # bold preserved
    assert_equal 31, result[@fg_pos]  # red preserved
    assert_equal 4, result[@underline_pos]   # underline added
  end

  def test_layer_diff_simple
    base = Gouache::Layer.from([0, 1, 31])      # bold red on BASE
    target = Gouache::Layer.from([0, 1, 31, 4]) # bold red underline on BASE

    diff = target.diff(base)
    assert_equal [4], diff     # underline from target
  end

  def test_layer_diff_none_to_bold
    base = Gouache::Layer.from([0])       # BASE - no bold/dim
    target = Gouache::Layer.from([0, 1])  # bold

    diff = target.diff(base)
    assert_equal [22, 1], diff    # reset then bold from target
  end

  def test_layer_diff_none_to_dim
    base = Gouache::Layer.from([0])       # BASE - no bold/dim
    target = Gouache::Layer.from([0, 2])  # dim

    diff = target.diff(base)
    assert_equal [22, 2], diff   # reset then dim from target
  end

  def test_layer_diff_bold_to_none
    base = Gouache::Layer.from([0, 1])    # bold
    target = Gouache::Layer.from([0])     # BASE - no bold/dim

    diff = base.diff(target)
    assert_equal [22, 1], diff   # reset then bold from base
  end

  def test_layer_diff_dim_to_none
    base = Gouache::Layer.from([0, 2])    # dim
    target = Gouache::Layer.from([0])     # BASE - no bold/dim

    diff = base.diff(target)
    assert_equal [22, 2], diff   # reset then dim from base
  end

  def test_layer_diff_bold_to_dim
    base = Gouache::Layer.from([0, 1])    # bold
    target = Gouache::Layer.from([0, 2])  # dim

    diff = base.diff(target)
    assert_equal [22, 1], diff   # reset then bold from base
  end

  def test_layer_diff_dim_to_bold
    base = Gouache::Layer.from([0, 2])    # dim
    target = Gouache::Layer.from([0, 1])  # bold

    diff = base.diff(target)
    assert_equal [22, 2], diff   # reset then dim from base
  end

  def test_layer_diff_none_to_bold_dim
    base = Gouache::Layer.from([0])              # BASE - no bold/dim
    target = Gouache::Layer.from([0, 1, 2])  # both bold and dim

    diff = target.diff(base)
    assert_equal [1, 2], diff   # both from target
  end

  def test_layer_diff_bold_dim_to_none
    base = Gouache::Layer.from([0, 1, 2])    # both bold and dim
    target = Gouache::Layer.from([0])        # BASE - no bold/dim

    diff = base.diff(target)
    assert_equal [1, 2], diff   # both from base
  end

  def test_layer_diff_bold_to_bold_dim
    base = Gouache::Layer.from([0, 1])       # bold only
    target = Gouache::Layer.from([0, 1, 2])  # bold and dim

    diff = target.diff(base)
    assert_equal [1, 2], diff   # both from target
  end

  def test_layer_diff_dim_to_bold_dim
    base = Gouache::Layer.from([0, 2])       # dim only
    target = Gouache::Layer.from([0, 1, 2])  # bold and dim

    diff = target.diff(base)
    assert_equal [1, 2], diff   # both from target
  end

  def test_layer_diff_bold_dim_to_bold
    base = Gouache::Layer.from([0, 1, 2])    # both bold and dim
    target = Gouache::Layer.from([0, 1])     # bold only

    diff = base.diff(target)
    assert_equal [1, 2], diff   # both from base
  end

  def test_layer_diff_bold_dim_to_dim
    base = Gouache::Layer.from([0, 1, 2])    # both bold and dim
    target = Gouache::Layer.from([0, 2])     # dim only

    diff = base.diff(target)
    assert_equal [1, 2], diff   # both from base
  end

  def test_layer_diff_empty_case
    layer1 = Gouache::Layer.from([0])
    layer2 = Gouache::Layer.from([0])

    diff = layer1.diff(layer2)
    assert_equal [], diff
  end

  def test_layer_to_sgr_basic
    layer = Gouache::Layer.from([1, 31, 4])
    sgr = layer.to_sgr
    assert_includes sgr, "1"
    assert_includes sgr, "31"
    assert_includes sgr, "4"
  end

  def test_layer_to_sgr_with_nils
    layer = Gouache::Layer.from([31, 1])
    sgr = layer.to_sgr
    assert_includes sgr, "1"
    assert_includes sgr, "31"
  end

  def test_layer_to_sgr_empty
    layer = Gouache::Layer.empty
    sgr = layer.to_sgr
    assert_equal "", sgr
  end

  def test_layer_range_functionality
    # Test that LayerRange properly categorizes SGR codes
    fg_range = Gouache::Layer::RANGES[:fg]  # foreground colors

    assert fg_range.member?(31)  # red
    assert fg_range.member?(39)  # reset
    assert fg_range.member?(91)  # bright red
    refute fg_range.member?(41)  # not foreground (background)
  end

  def test_base_layer_values
    base = Gouache::Layer::BASE
    assert_equal 39, base[0]  # fg reset
    assert_equal 49, base[1]  # bg reset
    assert_equal 23, base[2]  # italic reset
    assert_equal 22, base[9]  # bold reset
    assert_equal 22, base[10] # dim reset (same as bold)
  end

  def test_base_layer_properties
    base = Gouache::Layer::BASE
    assert_equal Gouache::Layer::RANGES.length, base.length
    assert base.none?(&:nil?), "BASE should contain no nils"
    # BASE can be used as starting point with from(0)
    updated = Gouache::Layer.from([0, 1, 31])
    assert_equal 1, updated[@bold_pos]  # bold
    assert_equal 31, updated[@fg_pos] # red fg
    assert_equal 22, updated[@dim_pos] # dim reset preserved
  end

  def test_ranges_for_method
    # Test that RANGES.for works correctly
    assert_equal [@bold_pos], Gouache::Layer::RANGES.for(1)
    assert_equal [@dim_pos], Gouache::Layer::RANGES.for(2)
    assert_equal [@fg_pos], Gouache::Layer::RANGES.for(31)
    assert_equal [@bg_pos], Gouache::Layer::RANGES.for(42)
    assert_nil Gouache::Layer::RANGES.for(999)  # invalid code
  end

  def test_ranges_for_method_multiple_matches
    # Test code that matches multiple ranges (22 resets both bold and dim)
    positions = Gouache::Layer::RANGES.for(22)
    assert_includes positions, @bold_pos
    assert_includes positions, @dim_pos
    assert_equal 2, positions.length
  end

  def test_ranges_for_method_returns_nil_for_no_matches
    # Test that no matches returns nil, not empty array
    result = Gouache::Layer::RANGES.for(999)
    assert_nil result
    refute_equal [], result
  end

  # RGB/256-color string tests
  def test_layer_from_with_rgb_color_strings
    layer = Gouache::Layer.from(["38;5;123"])  # 256-color fg
    assert_equal "38;5;123", layer[@fg_pos]

    layer = Gouache::Layer.from(["48;2;255;128;0"])  # RGB bg
    assert_equal "48;2;255;128;0", layer[@bg_pos]
  end

  def test_layer_from_rgb_color_strings_go_to_correct_slots
    layer = Gouache::Layer.from(["38;5;200", "48;5;100"])  # 256-color fg and bg
    assert_equal "38;5;200", layer[@fg_pos]  # fg slot
    assert_equal "48;5;100", layer[@bg_pos]  # bg slot

    layer = Gouache::Layer.from(["38;2;255;0;0", "48;2;0;255;0"])  # RGB fg and bg
    assert_equal "38;2;255;0;0", layer[@fg_pos]  # fg slot
    assert_equal "48;2;0;255;0", layer[@bg_pos]  # bg slot
  end

  def test_layer_overlay_with_rgb_colors
    base = Gouache::Layer.from([1, "38;5;100"])        # bold + 256-color fg
    overlay = Gouache::Layer.from(["38;2;255;0;0", 4]) # RGB fg + underline

    result = base.overlay(overlay)
    assert_equal 1, result[@bold_pos]              # bold preserved
    assert_equal "38;2;255;0;0", result[@fg_pos] # RGB fg overrides 256-color
    assert_equal 4, result[@underline_pos]              # underline added
  end

  def test_layer_diff_with_rgb_colors
    base = Gouache::Layer.from([0, "38;5;100"])   # 256-color fg
    target = Gouache::Layer.from([0, "38;2;255;0;0"]) # RGB fg

    diff = base.diff(target)
    assert_equal ["38;5;100"], diff     # 256-color from base
  end

  def test_layer_diff_rgb_to_simple_color
    base = Gouache::Layer.from([0, "38;2;255;0;0"])  # RGB red
    target = Gouache::Layer.from([0, 31])            # simple red

    diff = base.diff(target)
    assert_equal ["38;2;255;0;0"], diff     # RGB from base
  end

  def test_layer_to_sgr_with_rgb_colors
    layer = Gouache::Layer.from([1, "38;5;123", "48;2;255;128;0"])
    sgr = layer.to_sgr
    assert_includes sgr, "1"
    assert_includes sgr, "38;5;123"
    assert_includes sgr, "48;2;255;128;0"
  end

  def test_layer_to_sgr_mixed_types_sorting
    layer = Gouache::Layer.from([31, "38;5;200", 1])  # mix integer and string - 38 wins over 31 in fg slot
    sgr = layer.to_sgr
    refute_includes sgr, "31"
    assert_includes sgr, "38;5;200"
    assert_includes sgr, "1"
  end

  def test_layer_prepare_sgr_sorting
    # Test the class method prepare_sgr handles mixed types
    mixed_array = [31, "38;5;200", 1, nil, 22]
    result = Gouache::Layer.prepare_sgr(mixed_array)

    # Should put 22 first, then rest: [22, 31, "38;5;200", 1]
    assert_equal 22, result[0]
    assert_includes result, "38;5;200"
    assert_includes result, 31
    assert_includes result, 1
  end

  def test_layer_range_with_rgb_strings
    fg_range = Gouache::Layer::RANGES[:fg]  # foreground colors
    bg_range = Gouache::Layer::RANGES[:bg]  # background colors

    # RGB/256-color strings should be recognized by their first number
    assert fg_range.member?("38;5;123".to_i)      # 38 -> foreground
    assert fg_range.member?("38;2;255;0;0".to_i)  # 38 -> foreground
    assert bg_range.member?("48;5;123".to_i)      # 48 -> background
    assert bg_range.member?("48;2;0;255;0".to_i)  # 48 -> background
  end

  def test_layer_from_with_empty_array
    layer = Gouache::Layer.from([])
    assert layer.all?(&:nil?)
  end

  def test_layer_overlay_with_self
    layer = Gouache::Layer.from([1, 31])
    result = layer.overlay(layer)
    assert_equal layer, result
    refute_same layer, result
  end

  def test_layer_overlay_with_non_layer_raises_type_error
    layer = Gouache::Layer.from([1, 31])
    assert_raises(TypeError) { layer.overlay("not a layer") }
  end

  def test_layer_diff_with_identical_non_base_layers
    layer1 = Gouache::Layer.from([0, 1, 31, 4])  # bold red underline
    layer2 = Gouache::Layer.from([0, 1, 31, 4])  # same

    diff = layer1.diff(layer2)
    assert_equal [], diff
  end

  def test_layer_from_no_args
    layer = Gouache::Layer.from([])
    assert_equal Gouache::Layer.empty, layer
  end

  def test_layer_from_nil
    layer = Gouache::Layer.from([nil])
    assert_equal Gouache::Layer.empty, layer
  end

  def test_layer_from_empty_array
    layer = Gouache::Layer.from([])
    assert_equal Gouache::Layer.empty, layer
  end
  def test_layer_from_with_zero_resets_to_base
    layer = Gouache::Layer.from([0])
    assert_equal Gouache::Layer::BASE, layer
  end

  def test_layer_from_with_zero_resets_to_base_varargs
    layer = Gouache::Layer.from(0)
    assert_equal Gouache::Layer::BASE, layer
  end

  def test_layer_from_with_zero_then_codes
    layer = Gouache::Layer.from([0, 1, 31])
    assert_equal 1, layer[@bold_pos]   # bold applied after BASE
    assert_equal 31, layer[@fg_pos]  # red fg applied
  end

  def test_layer_from_with_zero_then_codes_varargs
    layer = Gouache::Layer.from(0, 1, 31)
    assert_equal 1, layer[@bold_pos]   # bold applied after BASE
    assert_equal 31, layer[@fg_pos]  # red fg applied
  end

  def test_layer_from_with_zero_in_middle_resets
    layer = Gouache::Layer.from([1, 31, 0, 2, 32])  # bold red, reset, dim green
    assert_equal 2, layer[@dim_pos]   # dim applied after reset
    assert_equal 32, layer[@fg_pos]  # green applied after reset
    assert_equal 22, layer[@bold_pos] # bold reset value from BASE
  end

  def test_layer_from_with_zero_in_middle_resets_varargs
    layer = Gouache::Layer.from(1, 31, 0, 2, 32)  # bold red, reset, dim green
    assert_equal 2, layer[@dim_pos]   # dim applied after reset
    assert_equal 32, layer[@fg_pos]  # green applied after reset
    assert_equal 22, layer[@bold_pos] # bold reset value from BASE
  end

  def test_layer_from_zero_replaces_with_base
    layer = Gouache::Layer.from([1, 31])  # bold red
    assert_equal 1, layer[@bold_pos]
    assert_equal 31, layer[@fg_pos]

    layer = Gouache::Layer.from([1, 31, 0, 4])  # bold red, then reset to BASE, then underline
    assert_equal 22, layer[@bold_pos]    # BASE bold reset value
    assert_equal 39, layer[@fg_pos]      # BASE fg reset value
    assert_equal 4, layer[@underline_pos] # underline applied after reset
  end



  def test_layer_range_initialization
    # Test with ranges and integers
    range = Gouache::Layer::LayerRange.new([30..39, 90..97, 39], label: :fg, index: 0)
    assert_equal 39, range.off
    assert_equal :fg, range.label
    assert_equal 0, range.index
  end

  def test_layer_range_initialization_single_values
    # Test with only single values
    range = Gouache::Layer::LayerRange.new([1, 22], label: :bold, index: 9)
    assert_equal 22, range.off
    assert_equal :bold, range.label
    assert_equal 9, range.index
  end

  def test_layer_range_member_method_integration
    # Integration test - LayerRange uses RangeUnion internally
    range = Gouache::Layer::LayerRange.new([30..39, 90..97, 39], label: :fg, index: 0)

    assert range.member?(31)
    assert range.member?(91)
    refute range.member?(29)
    refute range.member?(40)
  end

  def test_layer_range_off_attribute
    range1 = Gouache::Layer::LayerRange.new([30..39, 90..97, 39], label: :fg, index: 0)
    assert_equal 39, range1.off

    range2 = Gouache::Layer::LayerRange.new([1, 22], label: :bold, index: 9)
    assert_equal 22, range2.off

    range3 = Gouache::Layer::LayerRange.new([4, 21, 24], label: :underline, index: 8)
    assert_equal 24, range3.off
  end

  def test_layer_range_case_equality_alias
    range = Gouache::Layer::LayerRange.new([30..39, 90..97, 39], label: :fg, index: 0)

    assert range === 31
    assert range === 91
    refute range === 29
    refute range === 40
  end


  def test_layer_from_with_invalid_sgr_codes
    # Invalid SGR codes should be ignored (RANGES.for returns nil)
    layer = Gouache::Layer.from([1, 999, 31])  # 999 is invalid
    assert_equal 1, layer[@bold_pos]
    assert_equal 31, layer[@fg_pos]
    # Position for 999 should remain nil since it's invalid
    assert layer.compact.length < layer.length  # some positions still nil
  end

  def test_layer_from_with_non_numeric_strings
    # Test .to_i behavior with non-numeric strings
    layer = Gouache::Layer.from(["abc", "31", "bold"])  # "abc" -> 0, "bold" -> 0
    assert_equal "31", layer[@fg_pos]
    # "abc".to_i == 0, "bold".to_i == 0 don't match any ranges, so get dropped
    assert_nil layer[@bold_pos]  # invalid codes get dropped
  end

  def test_layer_diff_when_last_element_not_array
    # Test diff when diff[-1] is not an Array (shouldn't call prepare_sgr)
    base = Gouache::Layer.from([0, 31])     # fg only
    target = Gouache::Layer.from([0, 32])   # different fg

    diff = base.diff(target)
    assert_equal [31], diff  # fg from base
  end

  def test_layer_diff_array_replacement_logic
    # Test the array replacement logic explicitly for bold/dim
    base = Gouache::Layer.from([0])         # BASE only
    target = Gouache::Layer.from([0, 1, 2]) # BASE + bold + dim

    diff = target.diff(base)
    # Bold and dim both get added - prepare_sgr puts any 22 first, then rest
    assert_includes diff, 1
    assert_includes diff, 2
    assert_equal 2, diff.length  # just the two codes needed
  end

  def test_layer_to_sgr_with_mixed_nil_and_values
    # Test to_sgr with layer containing nil values mixed with valid codes
    layer = Gouache::Layer.empty
    layer[@bold_pos] = 1
    layer[@fg_pos] = 31
    # Other positions remain nil

    sgr = layer.to_sgr
    assert_includes sgr, "1"
    assert_includes sgr, "31"
  end

  def test_layer_overlay_with_invalid_layer_like_object
    layer = Gouache::Layer.from([1, 31])

    # Test with object that's not nil or Layer
    assert_raises(TypeError) { layer.overlay("string") }
    assert_raises(TypeError) { layer.overlay(123) }
    assert_raises(TypeError) { layer.overlay([1, 2, 3]) }
  end


end
