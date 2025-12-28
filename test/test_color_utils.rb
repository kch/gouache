# frozen_string_literal: true

require "test_helper"

class TestColorUtils < Minitest::Test
  def test_srgb8_to_oklab_roundtrip
    # Test basic colors roundtrip
    [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255], [0, 0, 0], [128, 128, 128]].each do |rgb|
      oklab = Gouache::ColorUtils.oklab_from_srgb8(rgb)
      back = Gouache::ColorUtils.srgb8_from_oklab(oklab)
      assert_in_delta rgb[0], back[0], 1, "Red component failed roundtrip for #{rgb}"
      assert_in_delta rgb[1], back[1], 1, "Green component failed roundtrip for #{rgb}"
      assert_in_delta rgb[2], back[2], 1, "Blue component failed roundtrip for #{rgb}"
    end
  end

  def test_oklab_to_oklch_roundtrip
    # Test oklab/oklch conversions
    oklabs = [[1.0, 0.0, 0.0], [0.5, 0.1, -0.05], [0.8, -0.2, 0.15]]
    oklabs.each do |oklab|
      oklch = Gouache::ColorUtils.oklch_from_oklab(oklab)
      back = Gouache::ColorUtils.oklab_from_oklch(oklch)
      back.each_with_index do |val, i|
        assert_in_delta oklab[i], val, 0.001, "Component #{i} failed roundtrip for #{oklab}"
      end
    end
  end

  def test_white_d65
    # White D65 should be L=1, a≈0, b≈0
    white = [255, 255, 255]
    oklab = Gouache::ColorUtils.oklab_from_srgb8(white)
    assert_in_delta 1.0, oklab[0], 0.001, "White lightness"
    assert_in_delta 0.0, oklab[1], 0.001, "White a component"
    assert_in_delta 0.0, oklab[2], 0.001, "White b component"
  end

  def test_black
    # Black should be L≈0, a≈0, b≈0
    black = [0, 0, 0]
    oklab = Gouache::ColorUtils.oklab_from_srgb8(black)
    assert_in_delta 0.0, oklab[0], 0.001, "Black lightness"
    assert_in_delta 0.0, oklab[1], 0.001, "Black a component"
    assert_in_delta 0.0, oklab[2], 0.001, "Black b component"
  end

  def test_primary_colors_hue_signs
    # Red should have positive a
    red = Gouache::ColorUtils.oklab_from_srgb8([255, 0, 0])
    assert_operator red[1], :>, 0, "Red should have positive a"

    # Green should have negative a
    green = Gouache::ColorUtils.oklab_from_srgb8([0, 255, 0])
    assert_operator green[1], :<, 0, "Green should have negative a"

    # Blue should have negative b
    blue = Gouache::ColorUtils.oklab_from_srgb8([0, 0, 255])
    assert_operator blue[2], :<, 0, "Blue should have negative b"

    # Yellow should have positive b
    yellow = Gouache::ColorUtils.oklab_from_srgb8([255, 255, 0])
    assert_operator yellow[2], :>, 0, "Yellow should have positive b"
  end

  def test_oklch_chroma_always_positive
    colors = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 0]]
    colors.each do |rgb|
      oklab = Gouache::ColorUtils.oklab_from_srgb8(rgb)
      oklch = Gouache::ColorUtils.oklch_from_oklab(oklab)
      assert_operator oklch[1], :>=, 0, "Chroma should be non-negative for #{rgb}"
    end
  end

  def test_oklch_hue_range
    colors = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 0]]
    colors.each do |rgb|
      oklab = Gouache::ColorUtils.oklab_from_srgb8(rgb)
      oklch = Gouache::ColorUtils.oklch_from_oklab(oklab)
      assert_operator oklch[2], :>=, 0, "Hue should be >= 0 for #{rgb}"
      assert_operator oklch[2], :<, 360, "Hue should be < 360 for #{rgb}"
    end
  end

  def test_distance_symmetry
    rgb1 = [255, 0, 0]
    rgb2 = [0, 255, 0]

    d1 = Gouache::ColorUtils.oklab_distance_from_srgb8(rgb1, rgb2)
    d2 = Gouache::ColorUtils.oklab_distance_from_srgb8(rgb2, rgb1)

    assert_in_delta d1, d2, 0.001, "Distance should be symmetric"
  end

  def test_distance_zero_for_same_color
    rgb = [128, 64, 192]
    distance = Gouache::ColorUtils.oklab_distance_from_srgb8(rgb, rgb)
    assert_in_delta 0.0, distance, 0.001, "Distance to self should be zero"
  end

  def test_srgb8_to_oklch_roundtrip
    # Test basic colors roundtrip through OKLCH
    [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255], [0, 0, 0], [128, 128, 128]].each do |rgb|
      oklch = Gouache::ColorUtils.oklch_from_srgb8(rgb)
      back = Gouache::ColorUtils.srgb8_from_oklch(oklch)
      assert_in_delta rgb[0], back[0], 1, "Red component failed roundtrip for #{rgb}"
      assert_in_delta rgb[1], back[1], 1, "Green component failed roundtrip for #{rgb}"
      assert_in_delta rgb[2], back[2], 1, "Blue component failed roundtrip for #{rgb}"
    end
  end

  def test_oklch_from_srgb8_properties
    # Test OKLCH properties for known colors
    white = Gouache::ColorUtils.oklch_from_srgb8([255, 255, 255])
    assert_in_delta 1.0, white[0], 0.01, "White lightness should be ~1.0"
    assert_in_delta 0.0, white[1], 0.01, "White chroma should be ~0.0"

    black = Gouache::ColorUtils.oklch_from_srgb8([0, 0, 0])
    assert_in_delta 0.0, black[0], 0.01, "Black lightness should be ~0.0"
    assert_in_delta 0.0, black[1], 0.01, "Black chroma should be ~0.0"

    red = Gouache::ColorUtils.oklch_from_srgb8([255, 0, 0])
    assert_operator red[1], :>, 0, "Red should have positive chroma"
    assert_operator red[2], :>=, 0, "Hue should be non-negative"
    assert_operator red[2], :<, 360, "Hue should be < 360"
  end

  def test_oklch_chroma_always_positive_direct
    # Test that direct OKLCH conversion maintains positive chroma
    colors = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 0]]
    colors.each do |rgb|
      oklch = Gouache::ColorUtils.oklch_from_srgb8(rgb)
      assert_operator oklch[1], :>=, 0, "Chroma should be non-negative for #{rgb}"
    end
  end

  def test_oklch_from_maybe_relative_chroma
    # Test absolute chroma passthrough
    lch = Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.5, 0.1, 30])
    assert_equal [0.5, 0.1, 30], lch

    # Test relative chroma conversion
    lch_rel = Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.5, "0.5max", 30])
    cmax_val = Gouache::ColorUtils.cmax(0.5, 30)
    assert_in_delta 0.5, lch_rel[0], 0.001
    assert_in_delta 0.5 * cmax_val, lch_rel[1], 0.001
    assert_in_delta 30, lch_rel[2], 0.001
  end

  def test_cmax_function
    # Test that cmax returns reasonable values
    c1 = Gouache::ColorUtils.cmax(0.5, 30)
    c2 = Gouache::ColorUtils.cmax(0.8, 120)

    assert_operator c1, :>, 0, "cmax should be positive"
    assert_operator c2, :>, 0, "cmax should be positive"
    assert_operator c1, :<, 0.4, "cmax should be reasonable for sRGB"
    assert_operator c2, :<, 0.4, "cmax should be reasonable for sRGB"
  end

  def test_oklch_in_srgb_gamut
    # Test colors that should be in gamut
    assert Gouache::ColorUtils.oklch_in_srgb_gamut?([0.5, 0.0, 0])    # gray
    assert Gouache::ColorUtils.oklch_in_srgb_gamut?([1.0, 0.0, 0])    # white
    assert Gouache::ColorUtils.oklch_in_srgb_gamut?([0.0, 0.0, 0])    # black

    # Test color that should be out of gamut
    refute Gouache::ColorUtils.oklch_in_srgb_gamut?([0.5, 1.0, 0])    # extreme chroma
  end

  # OKLCH shift tests

  def test_oklch_shift_baseline
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, 0, 0])
    assert_equal [0.5, 0.1, 30], result
  end

  def test_oklch_shift_l_delta
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0.1, 0, 0])
    assert_in_delta 0.6, result[0], 0.001
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_l_absolute
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [[0.2], 0, 0])
    assert_in_delta 0.2, result[0], 0.001
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_h_delta_wrap
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 350], [0, 0, 20])
    assert_in_delta 0.5, result[0], 0.001
    assert_in_delta 0.1, result[1], 0.001
    assert_in_delta 10, result[2], 0.001
  end

  def test_oklch_shift_h_absolute
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, 0, [90]])
    assert_in_delta 0.5, result[0], 0.001
    assert_in_delta 0.1, result[1], 0.001
    assert_in_delta 90, result[2], 0.001
  end

  def test_oklch_shift_c_delta
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, 0.02, 0])
    assert_in_delta 0.5, result[0], 0.001
    assert_operator result[1], :>, 0.1  # should be larger
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_c_absolute
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, [0.05], 0])
    assert_in_delta 0.5, result[0], 0.001
    assert_in_delta 0.05, result[1], 0.001
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_c_absolute_relative
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, ["0.5max"], 0])
    cmax_val = Gouache::ColorUtils.cmax(0.5, 30)
    assert_in_delta 0.5, result[0], 0.001
    assert_in_delta 0.5 * cmax_val, result[1], 0.001
    assert_in_delta 30, result[2], 0.001

    # Test plain "max" in absolute replacement
    result2 = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, ["max"], 0])
    assert_in_delta 0.5, result2[0], 0.001
    assert_in_delta cmax_val, result2[1], 0.001
    assert_in_delta 30, result2[2], 0.001
  end

  def test_oklch_shift_c_relative_delta_positive
    old_cmax = Gouache::ColorUtils.cmax(0.5, 30)
    old_rel_c = 0.1 / old_cmax
    new_cmax = Gouache::ColorUtils.cmax(0.5, 30) # same L,H
    expected_c = (old_rel_c + 0.1) * new_cmax

    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, "0.1max", 0])
    assert_in_delta 0.5, result[0], 0.001
    assert_in_delta expected_c, result[1], 0.001
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_c_relative_delta_negative
    old_cmax = Gouache::ColorUtils.cmax(0.5, 30)
    old_rel_c = 0.1 / old_cmax
    new_cmax = Gouache::ColorUtils.cmax(0.5, 30) # same L,H
    expected_c = (old_rel_c - 0.1) * new_cmax

    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, "-0.1max", 0])
    assert_in_delta 0.5, result[0], 0.001
    assert_in_delta expected_c, result[1], 0.001
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_l_plus_c_absolute_relative
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0.1, ["0.5max"], 0])
    cmax_val = Gouache::ColorUtils.cmax(0.6, 30) # new lightness = 0.6
    assert_in_delta 0.6, result[0], 0.001
    assert_in_delta 0.5 * cmax_val, result[1], 0.001
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_l_plus_h_plus_c_absolute_relative
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0.1, ["0.5max"], 60])
    cmax_val = Gouache::ColorUtils.cmax(0.6, 90) # new L=0.6, H=90
    assert_in_delta 0.6, result[0], 0.001
    assert_in_delta 0.5 * cmax_val, result[1], 0.001
    assert_in_delta 90, result[2], 0.001
  end

  def test_oklch_shift_clamp_l
    result = Gouache::ColorUtils.oklch_shift([0.95, 0.1, 30], [0.2, 0, 0])
    assert_equal 1.0, result[0] # clamped from 1.15
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_clamp_c
    result = Gouache::ColorUtils.oklch_shift([0.5, 1.0, 30], [0, 0.5, 0])
    cmax_val = Gouache::ColorUtils.cmax(0.5, 30)
    assert_in_delta 0.5, result[0], 0.001
    assert_in_delta cmax_val, result[1], 0.001 # clamped to cmax
    assert_in_delta 30, result[2], 0.001
  end

  def test_oklch_shift_nil_preserves_relative_chroma
    old_cmax = Gouache::ColorUtils.cmax(0.5, 30)
    old_rel_c = 0.1 / old_cmax
    new_cmax = Gouache::ColorUtils.cmax(0.6, 90) # different L,H
    expected_c = old_rel_c * new_cmax

    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0.1, nil, 60])
    assert_in_delta 0.6, result[0], 0.001
    assert_in_delta expected_c, result[1], 0.001
    assert_in_delta 90, result[2], 0.001
  end

  def test_oklch_shift_with_invalid_arguments
    assert_raises(ArgumentError) { Gouache::ColorUtils.oklch_shift([1.5, 0.1, 30], [0, 0, 0]) } # L > 1
    assert_raises(ArgumentError) { Gouache::ColorUtils.oklch_shift([0.5, -0.1, 30], [0, 0, 0]) } # C < 0
    assert_raises(ArgumentError) { Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], ["bad", 0, 0]) } # invalid delta
  end

  # RGB shift tests

  def test_srgb8_shift_basic
    result = Gouache::ColorUtils.srgb8_shift([100, 150, 200], [50, -25, 30])
    assert_equal [150, 125, 230], result
  end

  def test_srgb8_shift_absolute
    result = Gouache::ColorUtils.srgb8_shift([100, 150, 200], [[50], [75], [250]])
    assert_equal [50, 75, 250], result
  end

  def test_srgb8_shift_mixed
    result = Gouache::ColorUtils.srgb8_shift([100, 150, 200], [25, [100], -50])
    assert_equal [125, 100, 150], result
  end

  def test_srgb8_shift_clamp_high
    result = Gouache::ColorUtils.srgb8_shift([100, 150, 200], [200, 200, 200])
    assert_equal [255, 255, 255], result
  end

  def test_srgb8_shift_clamp_low
    result = Gouache::ColorUtils.srgb8_shift([100, 150, 200], [-200, -200, -250])
    assert_equal [0, 0, 0], result
  end

  def test_srgb8_shift_floats_round
    result = Gouache::ColorUtils.srgb8_shift([100, 150, 200], [10.7, -25.3, 30.9])
    assert_equal [111, 125, 231], result
    result.each { |val| assert_instance_of Integer, val }
  end

  def test_srgb8_shift_with_invalid_arguments
    assert_raises(ArgumentError) { Gouache::ColorUtils.srgb8_shift([300, 150, 200], [0, 0, 0]) } # RGB > 255
    assert_raises(ArgumentError) { Gouache::ColorUtils.srgb8_shift([100, 150, 200], [[-10], 0, 0]) } # abs < 0
    assert_raises(ArgumentError) { Gouache::ColorUtils.srgb8_shift([100, 150, 200], [[300], 0, 0]) } # abs > 255
  end

  def test_oklch_shift_hue_modulo_wrapping
    # Test that hue wraps properly around 360
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 10], [0, 0, -30])
    assert_in_delta 340, result[2], 0.001  # 10 - 30 = -20, wraps to 340

    result2 = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 350], [0, 0, 30])
    assert_in_delta 20, result2[2], 0.001  # 350 + 30 = 380, wraps to 20
  end

  def test_oklch_shift_relative_chroma_edge_cases
    cmax_val = Gouache::ColorUtils.cmax(0.5, 30)

    # Test with very small relative chroma
    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, ["0.001max"], 0])
    assert_in_delta 0.001 * cmax_val, result[1], 0.0001

    # Test with maximum relative chroma
    result2 = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, ["1.0max"], 0])
    assert_in_delta cmax_val, result2[1], 0.001

    # Test plain "max" (should equal 1.0max)
    result3 = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, ["max"], 0])
    assert_in_delta cmax_val, result3[1], 0.001
  end

  def test_oklch_from_maybe_relative_chroma_edge_cases
    # Test with 0 relative chroma
    lch = Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.5, "0max", 30])
    assert_in_delta 0.0, lch[1], 0.001

    # Test with 1.0 relative chroma
    lch2 = Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.5, "1max", 30])
    cmax_val = Gouache::ColorUtils.cmax(0.5, 30)
    assert_in_delta cmax_val, lch2[1], 0.001

    # Test plain "max" (should be equivalent to "1.0max")
    lch3 = Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.5, "max", 30])
    assert_in_delta cmax_val, lch3[1], 0.001

    # Test validation fails for out-of-range values
    assert_raises(ArgumentError) { Gouache::ColorUtils.oklch_from_maybe_relative_chroma([1.5, 0.1, 30]) }
  end

  def test_oklch_in_srgb_gamut_comprehensive
    # Test white point
    assert Gouache::ColorUtils.oklch_in_srgb_gamut?([1.0, 0.0, 0])

    # Test black point
    assert Gouache::ColorUtils.oklch_in_srgb_gamut?([0.0, 0.0, 0])

    # Test mid gray
    assert Gouache::ColorUtils.oklch_in_srgb_gamut?([0.5, 0.0, 0])

    # Test reasonable color
    assert Gouache::ColorUtils.oklch_in_srgb_gamut?([0.7, 0.1, 180])

    # Test extreme chroma (should be out of gamut)
    refute Gouache::ColorUtils.oklch_in_srgb_gamut?([0.5, 0.5, 0])

    # Test negative lightness (invalid)
    refute Gouache::ColorUtils.oklch_in_srgb_gamut?([-0.1, 0.1, 0])

    # Test lightness > 1 (invalid)
    refute Gouache::ColorUtils.oklch_in_srgb_gamut?([1.1, 0.1, 0])
  end

  def test_cmax_comprehensive
    # Test that cmax is consistent
    c1 = Gouache::ColorUtils.cmax(0.5, 0)
    c2 = Gouache::ColorUtils.cmax(0.5, 360)
    assert_in_delta c1, c2, 0.001, "cmax should be same for 0° and 360°"

    # Test that very dark colors have low cmax
    dark_cmax = Gouache::ColorUtils.cmax(0.1, 180)
    assert_operator dark_cmax, :<, 0.1, "Dark colors should have low cmax"

    # Test that very bright colors have low cmax
    bright_cmax = Gouache::ColorUtils.cmax(0.95, 180)
    assert_operator bright_cmax, :<, 0.1, "Very bright colors should have low cmax"

    # Test mid-lightness has higher cmax
    mid_cmax = Gouache::ColorUtils.cmax(0.6, 180)
    assert_operator mid_cmax, :>, dark_cmax, "Mid lightness should have higher cmax than dark"
    assert_operator mid_cmax, :>, bright_cmax, "Mid lightness should have higher cmax than very bright"
  end

  def test_oklch_from_maybe_relative_chroma_comprehensive
    # Test absolute chroma (no "max" suffix)
    result = Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.6, 0.15, 45])
    assert_equal [0.6, 0.15, 45], result

    # Test relative chroma with different values
    cmax_val = Gouache::ColorUtils.cmax(0.7, 60)
    result2 = Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.7, "0.3max", 60])
    assert_in_delta 0.7, result2[0], 0.001
    assert_in_delta 0.3 * cmax_val, result2[1], 0.001
    assert_in_delta 60, result2[2], 0.001

    # Test edge case with 0 relative chroma
    result3 = Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.5, "0.0max", 90])
    assert_equal [0.5, 0.0, 90], result3

    # Test validation for lightness out of range
    assert_raises(ArgumentError) { Gouache::ColorUtils.oklch_from_maybe_relative_chroma([-0.1, 0.1, 30]) }
    assert_raises(ArgumentError) { Gouache::ColorUtils.oklch_from_maybe_relative_chroma([1.1, 0.1, 30]) }

    # Test validation for negative absolute chroma
    assert_raises(ArgumentError) { Gouache::ColorUtils.oklch_from_maybe_relative_chroma([0.5, -0.1, 30]) }
  end

  def test_oklch_shift_nil_chroma_preserves_relative
    # Test nil chroma preservation with same L,H
    old_cmax = Gouache::ColorUtils.cmax(0.5, 30)
    old_rel_c = 0.1 / old_cmax

    result = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0, nil, 0])
    expected_c = old_rel_c * old_cmax  # should be same as original
    assert_in_delta expected_c, result[1], 0.001

    # Test nil chroma preservation with different L,H
    new_cmax = Gouache::ColorUtils.cmax(0.7, 120)
    result2 = Gouache::ColorUtils.oklch_shift([0.5, 0.1, 30], [0.2, nil, 90])
    expected_c2 = old_rel_c * new_cmax
    assert_in_delta 0.7, result2[0], 0.001
    assert_in_delta expected_c2, result2[1], 0.001
    assert_in_delta 120, result2[2], 0.001

    # Test nil with zero chroma input
    result3 = Gouache::ColorUtils.oklch_shift([0.5, 0.0, 30], [0, nil, 0])
    assert_in_delta 0.0, result3[1], 0.001, "Zero chroma should remain zero with nil"
  end
end
