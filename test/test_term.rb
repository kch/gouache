# frozen_string_literal: true

require "test_helper"

class TestTerm < Minitest::Test
  self.term_isolation = false

  def setup
    super
    # Reset memoized instance variables to ensure test isolation
    Gouache::Term.instance_variable_set(:@colors, nil)
    Gouache::Term.instance_variable_set(:@fg_color, nil)
    Gouache::Term.instance_variable_set(:@bg_color, nil)
    Gouache::Term.instance_variable_set(:@basic_colors, nil)
    # Reset class variable for color indices cache
    Gouache::Term.class_variable_set(:@@color_indices, {})

  end

  def teardown
    super
  end

  def test_ansi16_colors_count
    assert_equal 16, Gouache::Term::ANSI16.size
  end

  def test_ansi16_all_valid_rgb
    Gouache::Term::ANSI16.each_with_index do |rgb, i|
      assert_equal 3, rgb.size, "Color #{i} should have 3 components"
      rgb.each { |c| assert_in_delta c, c.clamp(0, 255), 0, "Component should be 0-255" }
    end
  end

  def test_rgb8_from_ansi_cube_range
    assert_raises(IndexError) { Gouache::Term.rgb8_from_ansi_cube(15) }
    assert_raises(IndexError) { Gouache::Term.rgb8_from_ansi_cube(232) }

    # Valid range
    rgb = Gouache::Term.rgb8_from_ansi_cube(16)
    assert_equal 3, rgb.size
    assert_equal [0, 0, 0], rgb

    rgb = Gouache::Term.rgb8_from_ansi_cube(231)
    assert_equal [255, 255, 255], rgb
  end

  def test_rgb8_from_the_grays
    # Test with ansi index
    rgb = Gouache::Term.rgb8_from_the_grays(232)
    assert_equal [8, 8, 8], rgb

    rgb = Gouache::Term.rgb8_from_the_grays(255)
    assert_equal [238, 238, 238], rgb

    # Test with 0-based gray index
    rgb = Gouache::Term.rgb8_from_the_grays(0)
    assert_equal [8, 8, 8], rgb

    assert_raises(IndexError) { Gouache::Term.rgb8_from_the_grays(-1) }
    assert_raises(IndexError) { Gouache::Term.rgb8_from_the_grays(24) }
  end

  def test_colors256_size
    assert_equal 256, Gouache::Term::COLORS256.size
  end

  def test_colors256_structure
    # First 16 should be ANSI16
    16.times do |i|
      assert_equal Gouache::Term::ANSI16[i], Gouache::Term::COLORS256[i]
    end

    # Last 24 colors should be grays (r=g=b)
    Gouache::Term::RG_GRAY.each do |i|
      rgb = Gouache::Term::COLORS256[i]
      assert_equal rgb[0], rgb[1], "Gray #{i} r should equal g"
      assert_equal rgb[1], rgb[2], "Gray #{i} g should equal b"
    end

    # All should be valid RGB
    Gouache::Term::COLORS256.each_with_index do |rgb, i|
      assert_equal 3, rgb.size, "Color #{i} should have 3 components"
      rgb.each { |c| assert_in_delta c, c.clamp(0, 255), 0, "Component should be 0-255" }
    end
  end

  def test_scan_colors
    # Test standard format with \a ending
    osc_string = "\e]4;1;rgb:ff/00/00\a\e]4;2;rgb:00/ff/00\a"
    colors = Gouache::Term.scan_colors(osc_string, 2)
    assert_equal({1 => [255, 0, 0], 2 => [0, 255, 0]}, colors)

    # Test with \e\\ ending
    osc_string = "\e]4;1;rgb:ff/00/00\e\\\e]4;2;rgb:00/ff/00\e\\"
    colors = Gouache::Term.scan_colors(osc_string, 2)
    assert_equal({1 => [255, 0, 0], 2 => [0, 255, 0]}, colors)

    # Test with ffff/ffff/ffff format
    osc_string = "\e]4;1;rgb:ffff/0000/0000\a"
    colors = Gouache::Term.scan_colors(osc_string, 1)
    assert_equal({1 => [255, 0, 0]}, colors)

    # Test mixed formats
    osc_string = "\e]4;1;rgb:ff/00/00\a\e]4;2;rgb:ffff/ffff/0000\e\\"
    colors = Gouache::Term.scan_colors(osc_string, 2)
    assert_equal({1 => [255, 0, 0], 2 => [255, 255, 0]}, colors)
  end

  def test_scan_color
    osc_string = "\e]4;1;rgb:ff/00/00\a"
    color = Gouache::Term.scan_color(osc_string)

    assert_equal [255, 0, 0], color
  end

  def test_color_level_from_env
    original_colorterm = ENV["COLORTERM"]
    original_term = ENV["TERM"]

    begin
      ENV["COLORTERM"] = "truecolor"
      assert_equal :truecolor, Gouache::Term.color_level

      ENV["COLORTERM"] = nil
      ENV["TERM"] = "xterm-256color"
      assert_equal :_256, Gouache::Term.color_level

      ENV["TERM"] = "xterm"
      assert_equal :basic, Gouache::Term.color_level

      ENV["TERM"] = "dumb"
      assert_equal :basic, Gouache::Term.color_level

      ENV["TERM"] = "unknown"
      assert_equal :basic, Gouache::Term.color_level
    ensure
      ENV["COLORTERM"] = original_colorterm
      ENV["TERM"] = original_term
    end
  end

  def test_color_level_forced_setting
    original_colorterm = ENV["COLORTERM"]
    original_term = ENV["TERM"]

    begin
      # Test that forced setting overrides environment
      ENV["COLORTERM"] = "truecolor"
      ENV["TERM"] = "xterm-256color"

      Gouache::Term.color_level = :basic
      assert_equal :basic, Gouache::Term.color_level

      Gouache::Term.color_level = :_256
      assert_equal :_256, Gouache::Term.color_level

      Gouache::Term.color_level = :truecolor
      assert_equal :truecolor, Gouache::Term.color_level
    ensure
      ENV["COLORTERM"] = original_colorterm
      ENV["TERM"] = original_term
      # Reset forced setting
      Gouache::Term.instance_variable_set(:@color_level, nil)
    end
  end

  def test_color_level_setter_validation
    assert_raises(ArgumentError) { Gouache::Term.color_level = :invalid }
    assert_raises(ArgumentError) { Gouache::Term.color_level = "basic" }
    assert_raises(ArgumentError) { Gouache::Term.color_level = 256 }
    # nil should be valid now (resets forced setting)
    Gouache::Term.color_level = nil

    # Valid values should not raise
    Gouache::Term.color_level = :basic
    Gouache::Term.color_level = :_256
    Gouache::Term.color_level = :truecolor

    # Cleanup
    Gouache::Term.color_level = nil
  end

  def test_color_level_fallback_to_env_when_not_forced
    original_colorterm = ENV["COLORTERM"]
    original_term = ENV["TERM"]

    begin
      # Reset any forced setting
      Gouache::Term.instance_variable_set(:@color_level, nil)

      ENV["COLORTERM"] = "truecolor"
      assert_equal :truecolor, Gouache::Term.color_level

      # Force a setting, then reset it
      Gouache::Term.color_level = :basic
      assert_equal :basic, Gouache::Term.color_level

      # Reset and should fall back to env
      Gouache::Term.instance_variable_set(:@color_level, nil)
      assert_equal :truecolor, Gouache::Term.color_level
    ensure
      ENV["COLORTERM"] = original_colorterm
      ENV["TERM"] = original_term
      Gouache::Term.instance_variable_set(:@color_level, nil)
    end
  end

  def test_color_level_reset_with_nil
    original_colorterm = ENV["COLORTERM"]
    original_term = ENV["TERM"]

    begin
      ENV["COLORTERM"] = "truecolor"
      ENV["TERM"] = "xterm-256color"

      # Force a setting
      Gouache::Term.color_level = :basic
      assert_equal :basic, Gouache::Term.color_level

      # Reset with nil - should fall back to environment
      Gouache::Term.color_level = nil
      assert_equal :truecolor, Gouache::Term.color_level
    ensure
      ENV["COLORTERM"] = original_colorterm
      ENV["TERM"] = original_term
      Gouache::Term.instance_variable_set(:@color_level, nil)
    end
  end

  def test_osc_with_mock
    Gouache::Term.stub :term_seq, "\e]4;1;rgb:ff/00/00\a" do
      result = Gouache::Term.osc(4, 1, "?")
      assert_equal "\e]4;1;rgb:ff/00/00\a", result
    end
  end

  def test_rgb_for_with_mock
    Gouache::Term.stub :term_seq, "\e]4;1;rgb:ff/00/00\a" do
      color = Gouache::Term.rgb_for(1)
      assert_equal [255, 0, 0], color
    end
  end

  def test_fg_color_with_mock
    Gouache::Term.stub :term_seq, "\e]10;rgb:cc/cc/cc\a" do
      fg = Gouache::Term.fg_color
      assert_equal [204, 204, 204], fg
    end
  end

  def test_bg_color_with_mock
    Gouache::Term.stub :term_seq, "\e]11;rgb:00/00/00\a" do
      bg = Gouache::Term.bg_color
      assert_equal [0, 0, 0], bg
    end
  end

  def test_basic_colors_with_mock
    mock_response = (0..15).map{|i| "\e]4;#{i};rgb:ff/00/00\a" }.join
    Gouache::Term.stub :term_seq, mock_response do
      colors = Gouache::Term.basic_colors
      assert_equal 16, colors.size
      colors.each do |rgb|
        assert_equal [255, 0, 0], rgb
      end
    end
  end

  def test_basic_colors_fallback
    # Test fallback to ANSI16 when scan_colors fails
    Gouache::Term.stub :term_seq, "invalid_response" do
      colors = Gouache::Term.basic_colors
      assert_equal Gouache::Term::ANSI16, colors
    end
  end

  def test_nearest16
    # Test nearest16 finds closest color in basic 16-color palette
    Gouache::Term.stub :basic_colors, Gouache::Term::ANSI16 do
      # Red should match index 1 (normal red) in ANSI16
      index = Gouache::Term.nearest16([255, 0, 0])
      assert_equal 9, index  # bright red is closer to pure red than normal red

      # Black should match index 0
      index = Gouache::Term.nearest16([0, 0, 0])
      assert_equal 0, index

      # White should match index 15
      index = Gouache::Term.nearest16([255, 255, 255])
      assert_equal 15, index
    end
  end

  def test_nearest256
    # Test nearest256 finds closest color in 256-color palette
    Gouache::Term.stub :colors, Gouache::Term::COLORS256 do
      # Pure red should find exact match
      index = Gouache::Term.nearest256([255, 0, 0])
      assert_equal Gouache::Term.colors[index], [255, 0, 0]

      # Test caching - should return same result
      index2 = Gouache::Term.nearest256([255, 0, 0])
      assert_equal index, index2
    end
  end

  def test_colors_method
    # Test that colors returns COLORS256 with basic colors replaced
    Gouache::Term.stub :basic_colors, Gouache::Term::ANSI16 do
      colors = Gouache::Term.colors
      assert_equal 256, colors.size

      # First 16 should be basic_colors
      16.times do |i|
        assert_equal Gouache::Term.basic_colors[i], colors[i]
      end

      # Rest should be from COLORS256
      (16...256).each do |i|
        assert_equal Gouache::Term::COLORS256[i], colors[i]
      end
    end
  end

  def test_dark_method
    # Test light background (white bg, black fg) - should return false
    Gouache::Term.stub :fg_color, [0, 0, 0] do
      Gouache::Term.stub :bg_color, [255, 255, 255] do
        refute Gouache::Term.dark?, "Light background should return false"
      end
    end

    # Test dark background (black bg, white fg) - should return true
    Gouache::Term.stub :fg_color, [255, 255, 255] do
      Gouache::Term.stub :bg_color, [0, 0, 0] do
        assert Gouache::Term.dark?, "Dark background should return true"
      end
    end

    # Test equal lightness (same fg and bg) - should return false
    Gouache::Term.stub :fg_color, [128, 128, 128] do
      Gouache::Term.stub :bg_color, [128, 128, 128] do
        refute Gouache::Term.dark?, "Equal lightness should return false"
      end
    end

    # Test gray background darker than gray foreground - should return true
    Gouache::Term.stub :fg_color, [192, 192, 192] do  # lighter gray
      Gouache::Term.stub :bg_color, [64, 64, 64] do   # darker gray
        assert Gouache::Term.dark?, "Darker background than foreground should return true"
      end
    end
  end
end
