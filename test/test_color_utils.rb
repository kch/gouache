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
end
