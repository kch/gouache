# frozen_string_literal: true

require_relative "test_helper"

class TestStylesheet < Minitest::Test

  def setup
    super
    @ss = Gouache::Stylesheet::BASE
    Gouache::Term.color_level = :truecolor
    @fg_pos = Gouache::Layer::RANGES[:fg].index
    @bg_pos = Gouache::Layer::RANGES[:bg].index
    @ul_pos = Gouache::Layer::RANGES[:underline_color].index
    @bold_pos = Gouache::Layer::RANGES[:bold].index
  end


  def test_stylesheet_initialization_empty_and_nil_cases
    # All combinations of empty/nil for styles and base parameters

    # Empty styles, nil base
    ss1 = Gouache::Stylesheet.new({}, base: nil)
    assert_kind_of Hash, ss1.styles
    assert ss1.styles.empty?

    # Nil styles, nil base
    ss2 = Gouache::Stylesheet.new(nil, base: nil)
    assert_kind_of Hash, ss2.styles
    assert ss2.styles.empty?

    # Custom styles with nil base
    ss3 = Gouache::Stylesheet.new({custom: 1}, base: nil)
    assert ss3.layers[:custom]
    assert_kind_of Gouache::Layer, ss3.layers[:custom]
  end

  def test_base_parameter_type_requirements
    # base: nil should work
    ss1 = Gouache::Stylesheet.new({}, base: nil)
    assert_kind_of Hash, ss1.styles

    # base: Stylesheet should work
    base_ss = Gouache::Stylesheet.new({red: 31}, base: nil)
    ss2 = Gouache::Stylesheet.new({blue: 34}, base: base_ss)
    assert_kind_of Hash, ss2.styles
    assert ss2.layers[:red]  # Should inherit from base
    assert ss2.layers[:blue] # Should have new styles

    # base: Hash should raise TypeError
    assert_raises(TypeError) {
      Gouache::Stylesheet.new({}, base: {})
    }

    # base: String should raise TypeError
    assert_raises(TypeError) {
      Gouache::Stylesheet.new({}, base: "invalid")
    }

    # base: Integer should raise TypeError
    assert_raises(TypeError) {
      Gouache::Stylesheet.new({}, base: 42)
    }
  end

  def test_compute_rule_override_behavior_with_timeout
    require 'timeout'

    # Test that styles can override base styles without infinite loops
    base_ss = Gouache::Stylesheet.new({red: 31}, base: nil)

    # This should complete within reasonable time (not infinite loop)
    Timeout::timeout(0.1) do  # 0.1 second max
      override_ss = Gouache::Stylesheet.new({red: 91}, base: base_ss)
      assert_equal 91, override_ss.layers[:red][@fg_pos]
    end
  end

  def test_stylesheet_has_base_styles
    assert @ss.layers[:red]
    assert @ss.layers[:bold]
    assert @ss.layers[:on_blue]
  end

  def test_stylesheet_layers_are_layers
    assert_kind_of Gouache::Layer, @ss.layers[:red]
    assert_kind_of Gouache::Layer, @ss.layers[:bold]
  end

  def test_compute_decl_nil
    result = @ss.send(:compute_decl, nil)
    assert_equal [], result
  end

  def test_compute_decl_integer
    result = @ss.send(:compute_decl, 31)
    assert_kind_of Gouache::Color, result
  end

  def test_compute_decl_string_integer
    result = @ss.send(:compute_decl, "31")
    assert_kind_of Gouache::Color, result
  end

  def test_compute_decl_sgr_string
    result = @ss.send(:compute_decl, "31;1")
    assert_equal [Gouache::Color.sgr(31), 1], result
  end

  def test_compute_decl_rgb24_string
    result = @ss.send(:compute_decl, "rgb(255,0,0)")  # 24-bit RGB color format
    assert_equal Gouache::Color.rgb(255, 0, 0), result

    # Background version
    result = @ss.send(:compute_decl, "on_rgb(255,0,0)")
    assert_equal Gouache::Color.on_rgb(255, 0, 0), result
  end

  def test_compute_decl_hex24_string
    result = @ss.send(:compute_decl, "#ff0000")  # Hex 24-bit color format (CSS style)
    assert_equal Gouache::Color.hex("#ff0000"), result

    # Background version
    result = @ss.send(:compute_decl, "on#ff0000")
    assert_equal Gouache::Color.on_hex("#ff0000"), result
  end

  def test_compute_decl_hex8_string
    result = @ss.send(:compute_decl, "#500")  # Hex 8-bit color format (CSS-style 3 digits)
    assert_equal Gouache::Color.cube(5, 0, 0), result

    # Background version
    result = @ss.send(:compute_decl, "on#500")
    assert_equal Gouache::Color.on_cube(5, 0, 0), result
  end

  def test_compute_decl_256_string
    result = @ss.send(:compute_decl, "256(123)")  # 256-color format
    assert_equal Gouache::Color.sgr("38;5;123"), result

    # Background version
    result = @ss.send(:compute_decl, "on_256(123)")
    assert_equal Gouache::Color.sgr("48;5;123"), result
  end

  def test_compute_decl_gray_string
    result = @ss.send(:compute_decl, "gray(12)")  # Grayscale color format
    assert_equal Gouache::Color.gray(12), result

    # Background version
    result = @ss.send(:compute_decl, "on_gray(12)")
    assert_equal Gouache::Color.on_gray(12), result
  end

  def test_compute_decl_array
    result = @ss.send(:compute_decl, [31, 1])
    assert_equal [Gouache::Color.sgr(31), 1], result
  end

  def test_compute_decl_symbol_existing
    result = @ss.send(:compute_decl, :red)
    assert_equal [Gouache::Color.sgr(31)], result
  end

  def test_compute_decl_selector_string
    result = @ss.send(:compute_decl, "red")
    assert_equal [Gouache::Color.sgr(31)], result
  end

  def test_compute_rule_existing_selector
    result = @ss.send(:compute_rule, :red)
    assert_equal [Gouache::Color.sgr(31)], result
  end

  def test_compute_rule_nonexistent_selector
    ss = Gouache::Stylesheet.new({custom: 31}, base: nil)  # Selector exists in @styles but not @layers yet
    result = ss.send(:compute_rule, :custom)    # Should compute and cache in @layers
    assert_equal [Gouache::Color.sgr(31)], result
  end

  def test_compute_rule_circular_reference_detection
    # Direct circular reference: a->b->a
    ss = Gouache::Stylesheet.new({}, base: nil)
    ss.instance_variable_set(:@styles, {a: :b, b: :a})  # Bypass constructor processing
    assert_raises(RuntimeError, "circular reference for 'a'") {
      ss.send(:compute_rule, :a)                        # Should detect cycle via @sels stack
    }

    # Indirect circular reference: a->b->c->a
    ss2 = Gouache::Stylesheet.new({}, base: nil)
    ss2.instance_variable_set(:@styles, {a: :b, b: :c, c: :a})  # 3-step cycle
    assert_raises(RuntimeError, "circular reference for 'a'") {
      ss2.send(:compute_rule, :a)
    }
  end

  def test_compute_decl_out_of_bounds_integer
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, -1)    # Below valid range 1-107
    }
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, 108)  # Above valid range 1-107
    }
  end

  def test_compute_decl_invalid_string
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "not-a-valid-selector!")  # Contains dash, doesn't match RX_SEL
    }
  end

  def test_compute_decl_invalid_object
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, {})  # Hash doesn't match any pattern
    }
  end

  def test_compute_decl_rx_sel_valid_selectors
    # Create custom stylesheet with defined selectors
    ss = Gouache::Stylesheet.new({
      "bold!" => 1,
      "italic?" => 2,
      "red123" => 3,
      "under_line" => 4
    }, base: @ss)

    # Valid selector patterns that should match RX_SEL
    assert_equal [Gouache::Color.sgr(31)], ss.send(:compute_decl, "red")      # Simple word from base
    assert_equal [1], ss.send(:compute_decl, "bold!")    # Word with !
    assert_equal [2], ss.send(:compute_decl, "italic?")  # Word with ?
    assert_equal [3], ss.send(:compute_decl, "red123")   # Word with numbers
    assert_equal [4], ss.send(:compute_decl, "under_line") # Word with underscore
  end

  def test_compute_decl_rx_sel_invalid_selectors
    # Invalid selector patterns that should NOT match RX_SEL
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "red-bold") }    # Contains dash
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "red bold") }    # Contains space
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "red@blue") }    # Contains @
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "") }            # Empty string
  end

  def test_compute_decl_d256_bounds_checking
    # Valid D256 values (0-255)
    assert_equal Gouache::Color.sgr("38;5;0"), @ss.send(:compute_decl, "256(0)")
    assert_equal Gouache::Color.sgr("38;5;255"), @ss.send(:compute_decl, "256(255)")
    assert_equal Gouache::Color.rgb(0, 0, 0), @ss.send(:compute_decl, "rgb(0,0,0)")
    assert_equal Gouache::Color.rgb(255, 255, 255), @ss.send(:compute_decl, "rgb(255,255,255)")

    # Invalid D256 values (>255)
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "256(256)") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "rgb(256,0,0)") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "rgb(0,256,0)") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "rgb(0,0,256)") }
  end

  def test_compute_decl_d24_bounds_checking
    # Valid D24 values (0-23)
    assert_equal Gouache::Color.gray(0), @ss.send(:compute_decl, "gray(0)")
    assert_equal Gouache::Color.gray(23), @ss.send(:compute_decl, "gray(23)")

    # Invalid D24 values (>23)
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "gray(24)") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "gray(100)") }
  end

  def test_compute_decl_hex_case_sensitivity
    # 6-digit hex should work with upper/lower case
    assert_equal Gouache::Color.hex("#ff0000"), @ss.send(:compute_decl, "#ff0000")  # lowercase
    assert_equal Gouache::Color.hex("#FF0000"), @ss.send(:compute_decl, "#FF0000")  # uppercase
    assert_equal Gouache::Color.hex("#Ff0000"), @ss.send(:compute_decl, "#Ff0000")  # mixed case

    # 3-digit hex uses digits 0-5 only (RGB cube mapping)
    assert_equal Gouache::Color.cube(5, 0, 0), @ss.send(:compute_decl, "#500")     # valid digits
    assert_equal Gouache::Color.cube(1, 2, 3), @ss.send(:compute_decl, "#123")     # valid digits
    assert_equal Gouache::Color.cube(0, 5, 5), @ss.send(:compute_decl, "#055")     # valid digits

    # Background hex colors
    assert_equal Gouache::Color.on_hex("#ff0000"), @ss.send(:compute_decl, "on#ff0000")
    assert_equal Gouache::Color.on_hex("#FF0000"), @ss.send(:compute_decl, "on#FF0000")
  end

  def test_compute_decl_hex_bounds_checking
    # Valid hex8 digits (0-5 only)
    assert_equal Gouache::Color.cube(0, 0, 0), @ss.send(:compute_decl, "#000")
    assert_equal Gouache::Color.cube(5, 5, 5), @ss.send(:compute_decl, "#555")

    # Invalid hex8 digits (6-9, A-F not allowed in RGB cube)
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#600") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#5a0") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#5A0") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#999") }

    # Valid hex24 accepts full hex range
    assert_equal Gouache::Color.hex("#abcdef"), @ss.send(:compute_decl, "#abcdef")
    assert_equal Gouache::Color.hex("#ABCDEF"), @ss.send(:compute_decl, "#ABCDEF")
    assert_equal Gouache::Color.hex("#123abc"), @ss.send(:compute_decl, "#123abc")

    # Invalid hex24 (wrong length or invalid chars)
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#12345") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#1234567") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#gggggg") }
  end

  def test_key_method
    # Should find existing selectors
    assert @ss.tag?(:red)
    assert @ss.tag?("red")
    assert @ss.tag?(:bold)
    assert @ss.tag?("bold")

    # Should not find non-existent selectors
    refute @ss.tag?(:nonexistent)
    refute @ss.tag?("nonexistent")

    # Should convert to symbol
    ss = Gouache::Stylesheet.new({custom: 31}, base: nil)
    assert ss.tag?(:custom)
    assert ss.tag?("custom")
  end

  def test_key_method_with_unconvertible_types
    # Should handle types that can't convert to symbol
    assert_raises { @ss.tag?(123) }
    assert_raises { @ss.tag?([]) }
    assert_raises { @ss.tag?({}) }
  end

  def test_tags_method
    # Create stylesheet with mixed selector types
    custom_base = {
      simple:        31,           # Simple selector
      "with space":  1,            # Selector with space
      "multi word":  4,            # Multiple word selector
      compound:      [1, 31],      # Another simple selector
    }
    # Convert custom_base to stylesheet for use as base
    base_stylesheet = Gouache::Stylesheet.new(custom_base, base: nil)
    ss = Gouache::Stylesheet.new({}, base: base_stylesheet)

    result = ss.tags
    assert_kind_of Array, result

    # Should include selectors without spaces
    assert_includes result, :simple
    assert_includes result, :compound

    # Should be array of symbols
    result.each do |tag|
      assert_kind_of Symbol, tag
    end
  end

  # Comprehensive tests for all declaration patterns from test.rb

  def test_comprehensive_declaration_patterns
    # Test all patterns from not-real-tests/test.rb
    styles = {
      red: "#fc0000",
      z: :c,
      a: 1,
      b: :a,
      c: [:a],
      d: nil,
      e: "31",
      g: "31;4",
      h: "38;5;123",
      i: "38;2;1;2;3;107",
      k: "rgb(1,2,233)",
      l: "gray(23)",
      n: "256(123)",
      o: "on_rgb(1,2,3)",
      p: "on_gray(2)",
      q: "on_256(12)",
      s: "#123",
      t: "#123abc",
      u: "on#123",
      v: "on#123abc",
      w: ["blink", :underline, :l, "on#123"],

      # New over_* underline color functions
      over_rgb1: "over_rgb(255,128,0)",
      over_gray1: "over_gray(15)",
      over_2561: "over_256(196)",
      over_hex1: "over#ff8000",
      over_cube1: "over#520"
    }

    ss = Gouache::Stylesheet::BASE.merge(styles)

    # All should resolve to layers
    styles.each_key do |key|
      assert_kind_of Gouache::Layer, ss.layers[key], "#{key} should be Layer"
    end

    # Test specific SGR values for key patterns
    assert_equal [252, 0, 0], ss.layers[:red][@fg_pos].rgb         # #fc0000
    assert_equal 1,           ss.layers[:a][@bold_pos]             # bold
    assert_equal              ss.layers[:a], ss.layers[:b]         # b->a chain
    assert_equal              Gouache::Layer.empty, ss.layers[:d]  # nil
    assert_equal 31,          ss.layers[:g][@fg_pos].basic         # "31;4"
    assert_equal [1, 2, 233], ss.layers[:k][@fg_pos].rgb          # rgb(1,2,233)
    assert_equal 255,         ss.layers[:l][@fg_pos]._256          # gray(23) = 232+23
    assert_equal 123,         ss.layers[:n][@fg_pos]._256          # 256(123)
    assert_equal [1, 2, 3],   ss.layers[:o][@bg_pos].rgb          # on_rgb(1,2,3)
    assert_equal 67,          ss.layers[:s][@fg_pos]._256          # #123 = 1*36+2*6+3+16

    # Test new over_* underline color functions
    assert_equal [255, 128, 0], ss.layers[:over_rgb1][@ul_pos].rgb   # over_rgb(255,128,0)
    assert_equal 247,           ss.layers[:over_gray1][@ul_pos]._256  # over_gray(15) = 232+15
    assert_equal 196,           ss.layers[:over_2561][@ul_pos]._256   # over_256(196)
    assert_equal [255, 128, 0], ss.layers[:over_hex1][@ul_pos].rgb   # over#ff8000
    assert_equal 208,           ss.layers[:over_cube1][@ul_pos]._256  # over#520 = 5*36+2*6+0+16

    # Test complex array combination: ["blink", :underline, :l, "on#123"]
    # Expected: gray(23)=38;5;255 + on#123=48;5;67 + blink(5) + underline(4)
    assert_equal "38;5;255;48;5;67;5;4", ss.layers[:w].to_sgr
  end

  def test_valid_sgr_with_empty_segments
    # Test SGR strings with empty segments (leading/trailing/internal semicolons)
    ss = Gouache::Stylesheet.new({mixed: ";31;;4;"}, base: nil)
    assert_kind_of Gouache::Layer, ss.layers[:mixed]
    refute_equal Gouache::Layer.empty, ss.layers[:mixed]
  end

  def test_string_key_conversion_to_symbols
    # Test that string keys are properly converted to symbols in stylesheet
    ss = Gouache::Stylesheet.new({
      "red_text" => 31,
      "bold_text" => 1,
      "with_effect" => [32, proc { |top| top.italic = true }]
    }, base: nil)

    # Keys should appear as symbols in styles
    assert ss.styles.key?(:red_text)
    assert ss.styles.key?(:bold_text)
    assert ss.styles.key?(:with_effect)
    refute ss.styles.key?("red_text")
    refute ss.styles.key?("bold_text")

    # Keys should appear as symbols in tags
    assert_includes ss.tags, :red_text
    assert_includes ss.tags, :bold_text
    assert_includes ss.tags, :with_effect

    # Keys should be accessible via both string and symbol
    assert_equal Gouache::Layer.from(31), ss.layers[:red_text]
    assert_equal Gouache::Layer.from(31), ss.layers["red_text"]
    assert_equal Gouache::Layer.from(1), ss.layers[:bold_text]
    assert_equal Gouache::Layer.from(1), ss.layers["bold_text"]

    # Effects should be accessible via both string and symbol
    assert_kind_of Array, ss.effects[:with_effect]
    assert_kind_of Array, ss.effects["with_effect"]
    assert_equal 1, ss.effects[:with_effect].length
    assert_equal 1, ss.effects["with_effect"].length
  end

  def test_complex_rgb_sgr_combinations
    # Test complex SGR strings with RGB and other codes mixed
    styles = {
      rgb_bold:      "38;2;255;0;0;1",         # RGB + bold
      bg_rgb_dim:    "48;2;0;255;0;2",         # Background RGB + dim
      mixed_complex: "1;38;2;255;128;0;4;48;5;123", # Bold + RGB + underline + 256bg
      trailing_rgb:  "31;4;38;2;255;255;255",  # Standard + RGB at end
    }

    ss = Gouache::Stylesheet.new(styles, base: nil)

    # All should resolve successfully
    styles.each_key do |key|
      assert_kind_of Gouache::Layer, ss.layers[key]
      refute_equal Gouache::Layer.empty, ss.layers[key]
    end
  end

  def test_circular_reference_edge_cases
    # Test various circular reference patterns
    ss = Gouache::Stylesheet.new({}, base: nil)

    # Self-reference
    ss.instance_variable_set(:@styles, {self_ref: :self_ref})
    assert_raises(RuntimeError) { ss.send(:compute_rule, :self_ref) }

    # Long chain circular reference
    ss2 = Gouache::Stylesheet.new({}, base: nil)
    ss2.instance_variable_set(:@styles, {a: :b, b: :c, c: :d, d: :a})
    assert_raises(RuntimeError) { ss2.send(:compute_rule, :a) }
  end

  def test_all_color_function_variants
    # Test all color function patterns comprehensively
    styles = {
      # RGB variants
      rgb1:           "rgb(0,0,0)",
      rgb2:           "rgb(255,255,255)",
      rgb_bg1:        "on_rgb(128,64,32)",
      rgb_bg2:        "on_rgb(255,0,128)",
      rgb_ul1:        "over_rgb(255,128,0)",
      rgb_ul2:        "over_rgb(0,255,128)",

      # 256-color variants
      color256_1:     "256(0)",
      color256_2:     "256(255)",
      color256_bg1:   "on_256(0)",
      color256_bg2:   "on_256(255)",
      color256_ul1:   "over_256(196)",
      color256_ul2:   "over_256(46)",

      # Grayscale variants
      gray1:          "gray(0)",
      gray2:          "gray(23)",
      gray_bg1:       "on_gray(0)",
      gray_bg2:       "on_gray(23)",
      gray_ul1:       "over_gray(15)",
      gray_ul2:       "over_gray(5)",

      # Hex variants
      hex3_1:         "#000",
      hex3_2:         "#555",
      hex6_1:         "#000000",
      hex6_2:         "#ffffff",
      hex6_3:         "#abcdef",
      hex_bg3_1:      "on#123",
      hex_bg3_2:      "on#445",
      hex_bg6_1:      "on#000000",
      hex_bg6_2:      "on#ffffff",

      # OKLCH variants
      oklch1:         "oklch(0.5, 0.1, 30)",
      oklch2:         "oklch(0.8, 0.2, 180)",
      oklch_bg1:      "on_oklch(0.3, 0.05, 90)",
      oklch_bg2:      "on_oklch(0.7, 0.15, 270)",
      oklch_ul1:      "over_oklch(0.6, 0.1, 45)",
      oklch_ul2:      "over_oklch(0.4, 0.08, 315)",
      oklch_rel1:     "oklch(0.5, 0.5max, 60)",
      oklch_rel2:     "oklch(0.7, max, 120)",
    }

    ss = Gouache::Stylesheet.new(styles, base: nil)

    # All color functions should produce non-empty layers
    styles.each_key do |key|
      assert_kind_of Gouache::Layer, ss.layers[key]
      refute_equal Gouache::Layer.empty, ss.layers[key], "#{key} should not be empty"
    end

    # Test specific SGR values
    assert_equal [0, 0, 0], ss.layers[:rgb1][@fg_pos].rgb          # rgb(0,0,0)
    assert_equal [255, 255, 255], ss.layers[:rgb2][@fg_pos].rgb    # rgb(255,255,255)
    assert_equal [128, 64, 32], ss.layers[:rgb_bg1][@bg_pos].rgb   # on_rgb(128,64,32)
    assert_equal [255, 0, 128], ss.layers[:rgb_bg2][@bg_pos].rgb   # on_rgb(255,0,128)
    assert_equal [255, 128, 0], ss.layers[:rgb_ul1][@ul_pos].rgb   # over_rgb(255,128,0)
    assert_equal [0, 255, 128], ss.layers[:rgb_ul2][@ul_pos].rgb   # over_rgb(0,255,128)

    assert_equal 0,   ss.layers[:color256_1][@fg_pos]._256   # 256(0)
    assert_equal 255, ss.layers[:color256_2][@fg_pos]._256   # 256(255)
    assert_equal 0,   ss.layers[:color256_bg1][@bg_pos]._256 # on_256(0)
    assert_equal 255, ss.layers[:color256_bg2][@bg_pos]._256 # on_256(255)
    assert_equal 196, ss.layers[:color256_ul1][@ul_pos]._256 # over_256(196)
    assert_equal 46,  ss.layers[:color256_ul2][@ul_pos]._256 # over_256(46)

    assert_equal 232, ss.layers[:gray1][@fg_pos]._256           # gray(0) = 232+0
    assert_equal 255, ss.layers[:gray2][@fg_pos]._256           # gray(23) = 232+23
    assert_equal 232, ss.layers[:gray_bg1][@bg_pos]._256        # on_gray(0) = 232+0
    assert_equal 255, ss.layers[:gray_bg2][@bg_pos]._256        # on_gray(23) = 232+23
    assert_equal 247, ss.layers[:gray_ul1][@ul_pos]._256        # over_gray(15) = 232+15
    assert_equal 237, ss.layers[:gray_ul2][@ul_pos]._256        # over_gray(5) = 232+5

    assert_equal 16,              ss.layers[:hex3_1][@fg_pos]._256   # #000 = 0*36+0*6+0+16
    assert_equal 231,             ss.layers[:hex3_2][@fg_pos]._256   # #555 = 5*36+5*6+5+16
    assert_equal [0, 0, 0],       ss.layers[:hex6_1][@fg_pos].rgb   # #000000
    assert_equal [255, 255, 255], ss.layers[:hex6_2][@fg_pos].rgb   # #ffffff
    assert_equal [171, 205, 239], ss.layers[:hex6_3][@fg_pos].rgb   # #abcdef
    assert_equal 67,              ss.layers[:hex_bg3_1][@bg_pos]._256 # on#123 = 1*36+2*6+3+16
    assert_equal 189,             ss.layers[:hex_bg3_2][@bg_pos]._256 # on#445 = 4*36+4*6+5+16
    assert_equal [0, 0, 0],       ss.layers[:hex_bg6_1][@bg_pos].rgb # on#000000
    assert_equal [255, 255, 255], ss.layers[:hex_bg6_2][@bg_pos].rgb # on#ffffff

    # OKLCH functions should create proper Color objects
    assert_equal [0.5, 0.1, 30],                     ss.layers[:oklch1][@fg_pos].oklch
    assert_equal [0.8, 0.2, 180],                    ss.layers[:oklch2][@fg_pos].oklch
    assert_equal [0.3, 0.05, 90],                    ss.layers[:oklch_bg1][@bg_pos].oklch
    assert_equal [0.7, 0.15, 270],                   ss.layers[:oklch_bg2][@bg_pos].oklch
    assert_equal [0.6, 0.1, 45],                     ss.layers[:oklch_ul1][@ul_pos].oklch
    assert_equal [0.4, 0.08, 315],                   ss.layers[:oklch_ul2][@ul_pos].oklch
    assert_equal [0.5, 0.0586282804608345, 60.0],    ss.layers[:oklch_rel1][@fg_pos].oklch
    assert_equal [0.7, 0.16619166210293773, 120.0],  ss.layers[:oklch_rel2][@fg_pos].oklch
  end

  def test_boundary_conditions_comprehensive
    # Test boundary conditions for all numeric ranges

    # Valid boundary values should work
    valid_styles = {
      sgr_min:        1,           # Minimum SGR code
      sgr_max:        107,         # Maximum SGR code
      d256_min:       "256(0)",    # Minimum 256-color
      d256_max:       "256(255)",  # Maximum 256-color
      d24_min:        "gray(0)",   # Minimum grayscale
      d24_max:        "gray(23)",  # Maximum grayscale
      rgb_min:        "rgb(0,0,0)",     # Minimum RGB
      rgb_max:        "rgb(255,255,255)", # Maximum RGB
      hex3_min:       "#000",      # Minimum 3-digit hex
      hex3_max:       "#555",      # Maximum 3-digit hex (RGB cube)
    }

    ss = Gouache::Stylesheet.new(valid_styles, base: nil)
    valid_styles.each_key do |key|
      assert_kind_of Gouache::Layer, ss.layers[key]
    end

    # Invalid boundary values should raise errors
    invalid_cases = [
      {sgr_lt_zero: -1},       # Below SGR range
      {sgr_high: 108},         # Above SGR range
      {d256_high: "256(256)"}, # Above 256-color range
      {d24_high: "gray(24)"},  # Above grayscale range
      {rgb_high: "rgb(256,0,0)"}, # Above RGB range
      {hex3_invalid: "#678"},  # Invalid 3-digit hex (above RGB cube)
    ]

    invalid_cases.each do |invalid_style|
      ss_invalid = Gouache::Stylesheet.new({}, base: nil)
      ss_invalid.instance_variable_set(:@styles, invalid_style)
      key = invalid_style.keys.first
      assert_raises(NoMatchingPatternError) { ss_invalid.send(:compute_rule, key) }
    end
  end

  def test_merge_method
    # Create base stylesheet with some styles
    base_styles = {red: 31, bold: 1}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with additional styles
    merge_styles = {blue: 34, green: 32}
    merged_ss = base_ss.merge(merge_styles)

    # Should have all styles from base and merge
    assert_equal Gouache::Layer.from(31), merged_ss.layers[:red]
    assert_equal Gouache::Layer.from(1), merged_ss.layers[:bold]
    assert_equal Gouache::Layer.from(34), merged_ss.layers[:blue]
    assert_equal Gouache::Layer.from(32), merged_ss.layers[:green]
  end

  def test_merge_method_with_override
    # Create base stylesheet
    base_styles = {red: 31, bold: 1}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with overriding styles
    merge_styles = {red: 91, italic: 3}  # red overrides base red
    merged_ss = base_ss.merge(merge_styles)

    # Merged styles should override base styles
    assert_equal Gouache::Layer.from(91), merged_ss.layers[:red]  # overridden
    assert_equal Gouache::Layer.from(1), merged_ss.layers[:bold]   # from base
    assert_equal Gouache::Layer.from(3), merged_ss.layers[:italic] # new
  end

  def test_merge_method_preserves_original
    base_styles = {red: 31}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge should not modify original
    original_red = base_ss.layers[:red]
    merged_ss = base_ss.merge({blue: 34})

    # Original should be unchanged
    assert_equal original_red, base_ss.layers[:red]
    refute base_ss.layers.key?(:blue)

    # Merged should have both
    assert_equal original_red, merged_ss.layers[:red]
    assert_equal Gouache::Layer.from(34), merged_ss.layers[:blue]
  end

  def test_merge_method_with_multiple_hashes
    # Create base stylesheet
    base_styles = {red: 31, bold: 1}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with multiple style hashes
    merged_ss = base_ss.merge({blue: 34, green: 32}, {yellow: 33, red: 91})

    # Should have all styles, with later hashes overriding earlier ones
    assert_equal Gouache::Layer.from(91), merged_ss.layers[:red]  # overridden by second hash
    assert_equal Gouache::Layer.from(1), merged_ss.layers[:bold]   # from base
    assert_equal Gouache::Layer.from(34), merged_ss.layers[:blue]  # from first hash
    assert_equal Gouache::Layer.from(32), merged_ss.layers[:green] # from first hash
    assert_equal Gouache::Layer.from(33), merged_ss.layers[:yellow] # from second hash
  end

  def test_merge_method_with_empty_hashes
    base_styles = {red: 31}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with empty hashes and non-empty hash
    merged_ss = base_ss.merge({}, {blue: 34}, {})

    # Should work with empty hashes mixed in
    assert_equal Gouache::Layer.from(31), merged_ss.layers[:red]
    assert_equal Gouache::Layer.from(34), merged_ss.layers[:blue]
  end

  def test_merge_method_with_single_hash_still_works
    # Backwards compatibility test
    base_styles = {red: 31}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    merged_ss = base_ss.merge({blue: 34})

    # Single hash should still work
    assert_equal Gouache::Layer.from(31), merged_ss.layers[:red]
    assert_equal Gouache::Layer.from(34), merged_ss.layers[:blue]
  end

  def test_merge_method_with_no_arguments
    base_styles = {red: 31}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with no arguments should return copy of base
    merged_ss = base_ss.merge()

    assert_equal Gouache::Layer.from(31), merged_ss.layers[:red]
    refute_same base_ss, merged_ss  # Should be different object
  end


  def test_array_rule_color_merging
    # Test that array of colors in rule gets merged properly
    colors = [
      Gouache::Color.rgb(255, 128, 64),
      Gouache::Color.cube(5, 0, 0),
      Gouache::Color.sgr(31)
    ]

    ss = Gouache::Stylesheet.new({test_array: colors}, base: nil)
    layer = ss.layers[:test_array]

    # Should contain merged color with all representations
    assert_kind_of Gouache::Layer, layer
    color = layer[0]  # fg color at index 0
    assert_kind_of Gouache::Color, color
    assert_equal [255, 128, 64], color.rgb
    assert_equal 196, color._256  # from cube(5,0,0)
    assert_equal "38;2;255;128;64", color.sgr  # prefers highest fidelity
    assert_equal 31, color.to_sgr(fallback: :basic)  # uses fallback
  end

  def test_array_rule_mixed_roles
    # Test array with both foreground and background colors
    colors = [
      Gouache::Color.rgb(255, 0, 0),      # fg
      Gouache::Color.on_rgb(0, 255, 0),   # bg
      Gouache::Color.sgr(31),             # fg
      Gouache::Color.sgr(42)              # bg
    ]

    ss = Gouache::Stylesheet.new({test_mixed: colors}, base: nil)
    layer = ss.layers[:test_mixed]

    # Should have both fg and bg colors merged separately
    fg_color = layer[0]  # fg at index 0
    bg_color = layer[1]  # bg at index 1

    assert_kind_of Gouache::Color, fg_color
    assert_kind_of Gouache::Color, bg_color
    assert_equal [255, 0, 0], fg_color.rgb
    assert_equal 31, fg_color.basic
    assert_equal [0, 255, 0], bg_color.rgb
    assert_equal 42, bg_color.basic
  end

  def test_empty_array_rule
    ss = Gouache::Stylesheet.new({empty_test: []}, base: nil)
    layer = ss.layers[:empty_test]

    # Empty array should result in empty layer
    assert_kind_of Gouache::Layer, layer
    assert_equal 0, layer.compact.length
  end

  def test_compute_decl_nil_case
    result = @ss.send(:compute_decl, nil)
    assert_equal [], result
  end

  def test_compute_decl_color_case
    color = Gouache::Color.rgb(255, 0, 0)
    result = @ss.send(:compute_decl, color)
    assert_equal color, result
  end

  def test_compute_decl_layer_case
    layer = Gouache::Layer.from([31, 1])  # red foreground + bold
    assert_raises(RuntimeError) { @ss.send(:compute_decl, layer) }
  end

  def test_compute_decl_symbol_case
    result = @ss.send(:compute_decl, :red)
    assert_equal [Gouache::Color.sgr(31)], result
  end

  def test_compute_decl_array_case_basic
    result = @ss.send(:compute_decl, [31, 1])  # red foreground + bold
    assert_equal [Gouache::Color.sgr(31), 1], result
  end

  def test_compute_decl_ru_basic_case
    # Test various RU_BASIC ranges: 39, 49, 59, 30..37, 40..47, 90..97, 100..107

    # Single values: 39 (default fg), 49 (default bg), 59 (default underline color)
    result = @ss.send(:compute_decl, 39)
    assert_equal Gouache::Color.sgr(39), result

    result = @ss.send(:compute_decl, 49)
    assert_equal Gouache::Color.sgr(49), result

    result = @ss.send(:compute_decl, 59)
    assert_equal Gouache::Color.sgr(59), result

    # 30..37 range (standard fg colors)
    result = @ss.send(:compute_decl, 31)  # red foreground
    assert_equal Gouache::Color.sgr(31), result

    result = @ss.send(:compute_decl, 37)  # white foreground
    assert_equal Gouache::Color.sgr(37), result

    # 40..47 range (standard bg colors)
    result = @ss.send(:compute_decl, 42)  # green background
    assert_equal Gouache::Color.sgr(42), result

    # 90..97 range (bright fg colors)
    result = @ss.send(:compute_decl, 91)  # bright red foreground
    assert_equal Gouache::Color.sgr(91), result

    # 100..107 range (bright bg colors)
    result = @ss.send(:compute_decl, 102)  # bright green background
    assert_equal Gouache::Color.sgr(102), result
  end

  def test_compute_decl_rx_basic_case
    # Test RX_BASIC pattern: string versions of basic SGR codes
    # RX_BASIC matches /\A(?:3|4|9|10)[0-7]\z/ - colors 30-37, 40-47, 90-97, 100-107
    # Plus individual values 39, 49, 59

    # Default colors (39, 49, 59)
    result = @ss.send(:compute_decl, "39")
    assert_equal Gouache::Color.sgr("39"), result

    result = @ss.send(:compute_decl, "49")
    assert_equal Gouache::Color.sgr("49"), result

    result = @ss.send(:compute_decl, "59")
    assert_equal Gouache::Color.sgr("59"), result

    result = @ss.send(:compute_decl, "49")
    assert_equal Gouache::Color.sgr("49"), result

    # Standard fg colors (30-37)
    result = @ss.send(:compute_decl, "31")
    assert_equal Gouache::Color.sgr("31"), result

    result = @ss.send(:compute_decl, "37")
    assert_equal Gouache::Color.sgr("37"), result

    # Standard bg colors (40-47)
    result = @ss.send(:compute_decl, "42")
    assert_equal Gouache::Color.sgr("42"), result

    # Bright fg colors (90-97)
    result = @ss.send(:compute_decl, "91")
    assert_equal Gouache::Color.sgr("91"), result

    # Bright bg colors (100-107)
    result = @ss.send(:compute_decl, "102")
    assert_equal Gouache::Color.sgr("102"), result
  end

  def test_compute_decl_rx_ext_color_case
    # Test RX_EXT_COLOR pattern: extended color sequences
    # Pattern: /\A([34]8);(?:5;(#{D8})|2;(#{D8});(#{D8});(#{D8}))\z/

    # 256-color format: 38;5;n (fg) or 48;5;n (bg)
    result = @ss.send(:compute_decl, "38;5;196")  # red fg
    assert_equal Gouache::Color.sgr("38;5;196"), result

    result = @ss.send(:compute_decl, "48;5;46")   # bright green bg
    assert_equal Gouache::Color.sgr("48;5;46"), result

    # 24-bit RGB format: 38;2;r;g;b (fg) or 48;2;r;g;b (bg)
    result = @ss.send(:compute_decl, "38;2;255;0;0")  # red fg
    assert_equal Gouache::Color.sgr("38;2;255;0;0"), result

    result = @ss.send(:compute_decl, "48;2;0;255;0")  # green bg
    assert_equal Gouache::Color.sgr("48;2;0;255;0"), result
  end

  def test_compute_decl_invalid_ext_color_patterns
    # Invalid RX_EXT_COLOR patterns - these should not match the regex
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "38;5")     # incomplete 256-color
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "38;2;255") # incomplete RGB
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "38;5;256") # 256-color out of range (D8 is 0-255)
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "38;2;256;0;0") # RGB value out of range
    }
  end

  def test_compute_decl_ru_sgr_nc_case
    # Test RU_SGR_NC: valid SGR codes (0..107) excluding RU_BASIC, 38, 48, 58
    # These should return the integer directly

    result = @ss.send(:compute_decl, 0)   # reset
    assert_equal 0, result

    result = @ss.send(:compute_decl, 1)   # bold
    assert_equal 1, result

    result = @ss.send(:compute_decl, 2)   # dim
    assert_equal 2, result

    result = @ss.send(:compute_decl, 3)   # italic
    assert_equal 3, result

    result = @ss.send(:compute_decl, 4)   # underline
    assert_equal 4, result

    result = @ss.send(:compute_decl, 5)   # slow blink
    assert_equal 5, result

    result = @ss.send(:compute_decl, 7)   # reverse
    assert_equal 7, result

    result = @ss.send(:compute_decl, 8)   # conceal
    assert_equal 8, result

    result = @ss.send(:compute_decl, 9)   # strikethrough
    assert_equal 9, result

    # Reset codes in 20s range
    result = @ss.send(:compute_decl, 22)  # normal intensity
    assert_equal 22, result

    result = @ss.send(:compute_decl, 21)  # double underline
    assert_equal 21, result

    # Test that SGR 58 is excluded from RU_SGR_NC (incomplete sequence should fail)
    # SGR 58 alone is invalid - it requires color specification like 58;5;n or 58;2;r;g;b
    assert_raises(NoMatchingPatternError, "SGR 58 without color spec should not match any pattern") do
      @ss.send(:compute_decl, 58)
    end

    # Test weirder numbers in RU_SGR_NC range - unknown codes return the integer
    result = @ss.send(:compute_decl, 99)  # unknown SGR code
    assert_equal 99, result

    result = @ss.send(:compute_decl, 50)  # between basic ranges
    assert_equal 50, result

    result = @ss.send(:compute_decl, 89)  # just below bright fg range
    assert_equal 89, result

    result = @ss.send(:compute_decl, 98)  # just above bright fg range
    assert_equal 98, result
  end

  def test_compute_decl_rx_int_case
    # Test RX_INT pattern: string integers matching D8 (0-255)

    # Basic cases
    result = @ss.send(:compute_decl, "0")
    assert_equal @ss.send(:compute_decl, 0), result

    result = @ss.send(:compute_decl, "31")
    assert_equal @ss.send(:compute_decl, 31), result

    result = @ss.send(:compute_decl, "107")
    assert_equal @ss.send(:compute_decl, 107), result

    # Edge cases for D8 pattern
    result = @ss.send(:compute_decl, "1")
    assert_equal @ss.send(:compute_decl, 1), result

    result = @ss.send(:compute_decl, "99")
    assert_equal @ss.send(:compute_decl, 99), result

    result = @ss.send(:compute_decl, "50")
    assert_equal @ss.send(:compute_decl, 50), result

    result = @ss.send(:compute_decl, "89")
    assert_equal @ss.send(:compute_decl, 89), result

    result = @ss.send(:compute_decl, "23")
    assert_equal @ss.send(:compute_decl, 23), result
  end

  def test_compute_decl_rx_sgr_case
    # Test RX_SGR: /\A[0-9;]+\z/ (semicolon-separated SGR sequences)
    # RX_SGR matches strings like "31", "31;1", "0;31;42", etc.

    result = @ss.send(:compute_decl, "31;1")
    assert_equal [Gouache::Color.sgr(31), 1], result

    result = @ss.send(:compute_decl, "38;5;196;1")
    assert_equal [Gouache::Color.sgr("38;5;196"), 1], result

    result = @ss.send(:compute_decl, "0;31;42")
    assert_equal [0, Gouache::Color.sgr(31), Gouache::Color.sgr(42)], result



    # Test invalid SGR codes within valid SGR strings
    # These match RX_SGR pattern but contain codes that don't match any pattern

    # SGR string with out-of-range code (255 > 107)
    # scan_sgr parses it, but 255 will cause NoMatchingPatternError in recursive call
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "31;255;1")
    }

    # SGR string with invalid extended color (wrong role)
    result = @ss.send(:compute_decl, "28;5;100")
    # scan_sgr breaks it into [28, 5, 100] - all valid individually
    assert_equal [28, 5, Gouache::Color.sgr(100)], result
  end

  def test_compute_decl_rx_sel_pattern_compositions
    # Test RX_SEL pattern: /\A[a-z]\w*[?!]?\z/i
    # Must start with letter, followed by word chars, optionally ending with ? or !

    # Create stylesheet with actual rules for these selectors
    test_styles = {
      a: 1,
      Z: 2,
      red123: 31,
      my_color: 32,
      Color_123_ABC: 33,
      red?: 34,
      my_method?: 35,
      bold!: 1,
      danger_style!: 91,
      CamelCase: 36,
      mixedCase123!: 92
    }
    ss = Gouache::Stylesheet.new(test_styles, base: nil)

    # Basic letter-only selectors
    result = ss.send(:compute_decl, "a")
    assert_equal ss.send(:compute_rule, :a), result
    assert_equal [1], result

    result = ss.send(:compute_decl, "Z")  # case insensitive
    assert_equal ss.send(:compute_rule, :Z), result
    assert_equal [2], result

    # Letters with word characters (letters, digits, underscore)
    result = ss.send(:compute_decl, "red123")
    assert_equal ss.send(:compute_rule, :red123), result
    assert_equal [Gouache::Color.sgr(31)], result

    result = ss.send(:compute_decl, "my_color")
    assert_equal ss.send(:compute_rule, :my_color), result
    assert_equal [Gouache::Color.sgr(32)], result

    result = ss.send(:compute_decl, "Color_123_ABC")
    assert_equal ss.send(:compute_rule, :Color_123_ABC), result
    assert_equal [Gouache::Color.sgr(33)], result

    # With optional ? suffix
    result = ss.send(:compute_decl, "red?")
    assert_equal ss.send(:compute_rule, :red?), result
    assert_equal [Gouache::Color.sgr(34)], result

    result = ss.send(:compute_decl, "my_method?")
    assert_equal ss.send(:compute_rule, :my_method?), result
    assert_equal [Gouache::Color.sgr(35)], result

    # With optional ! suffix
    result = ss.send(:compute_decl, "bold!")
    assert_equal ss.send(:compute_rule, :bold!), result
    assert_equal [1], result
    result = ss.send(:compute_decl, "danger_style!")
    assert_equal ss.send(:compute_rule, :danger_style!), result
    assert_equal [Gouache::Color.sgr(91)], result

    # Mixed case variations
    result = ss.send(:compute_decl, "CamelCase")
    assert_equal ss.send(:compute_rule, :CamelCase), result
    assert_equal [Gouache::Color.sgr(36)], result

    result = ss.send(:compute_decl, "mixedCase123!")
    assert_equal ss.send(:compute_rule, :mixedCase123!), result
    assert_equal [Gouache::Color.sgr(92)], result
  end

  def test_compute_decl_rx_fn_color_functions
    # Test all RX_FN_* color function patterns

    # RX_FN_HEX: /(on)?#(\h{6})/
    result = @ss.send(:compute_decl, "#ff0000")
    assert_equal Gouache::Color.hex("#ff0000"), result

    result = @ss.send(:compute_decl, "on#00ff00")
    assert_equal Gouache::Color.on_hex("#00ff00"), result

    result = @ss.send(:compute_decl, "over#0000ff")
    assert_equal Gouache::Color.over_hex("#0000ff"), result

    result = @ss.send(:compute_decl, "#123abc")
    assert_equal Gouache::Color.hex("#123abc"), result

    # RX_FN_RGB: /(on_)? rgb \(\s* (D8) \s*,\s* (D8) \s*,\s* (D8) \s*\)/
    result = @ss.send(:compute_decl, "rgb(255,128,64)")
    assert_equal Gouache::Color.rgb(255, 128, 64), result

    result = @ss.send(:compute_decl, "on_rgb(0, 255, 0)")
    assert_equal Gouache::Color.on_rgb(0, 255, 0), result

    result = @ss.send(:compute_decl, "over_rgb(255, 128, 0)")
    assert_equal Gouache::Color.over_rgb(255, 128, 0), result

    result = @ss.send(:compute_decl, "rgb( 100 , 150 , 200 )")
    assert_equal Gouache::Color.rgb(100, 150, 200), result

    # RX_FN_CUBE: /(on)?#[0-5]{3}/
    result = @ss.send(:compute_decl, "#500")
    assert_equal Gouache::Color.cube(5, 0, 0), result

    result = @ss.send(:compute_decl, "on#023")
    assert_equal Gouache::Color.on_cube(0, 2, 3), result

    result = @ss.send(:compute_decl, "#135")
    assert_equal Gouache::Color.cube(1, 3, 5), result

    # RX_FN_GRAY: /(on_)? gray \(\s* (D24) \s* \)/
    result = @ss.send(:compute_decl, "on_gray(15)")
    assert_equal Gouache::Color.on_gray(15), result

    result = @ss.send(:compute_decl, "over_gray(10)")
    assert_equal Gouache::Color.over_gray(10), result

    result = @ss.send(:compute_decl, "on_gray( 0 )")
    assert_equal Gouache::Color.on_gray(0), result

    result = @ss.send(:compute_decl, "gray(23)")
    assert_equal Gouache::Color.gray(23), result

    # RX_FN_256: /(on_)? 256 \(\s* (D8) \s* \)/
    result = @ss.send(:compute_decl, "256(196)")
    assert_equal Gouache::Color.sgr("38;5;196"), result

    result = @ss.send(:compute_decl, "on_256(46)")
    assert_equal Gouache::Color.sgr("48;5;46"), result

    result = @ss.send(:compute_decl, "over_256(196)")
    assert_equal Gouache::Color.sgr("58;5;196"), result

    result = @ss.send(:compute_decl, "over#520")
    assert_equal Gouache::Color.over_cube(5, 2, 0), result

    result = @ss.send(:compute_decl, "256(255)")
    assert_equal Gouache::Color.sgr("38;5;255"), result

    # Test out of bounds values - should raise NoMatchingPatternError

    # RX_FN_HEX: invalid hex digits
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "#gggggg")  # invalid hex
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "#12345")   # too short
    }

    # RX_FN_RGB: out of D8 range (0-255)
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "rgb(256,0,0)")  # > 255
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "rgb(100,300,50)")  # > 255
    }

    # RX_FN_CUBE: out of [0-5] range
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "#600")  # 6 > 5
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "#159")  # 9 > 5
    }

    # RX_FN_GRAY: out of D24 range (0-23)
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "gray(24)")  # > 23
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "gray(100)")  # > 23
    }

    # RX_FN_256: out of D8 range (0-255)
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "256(256)")  # > 255
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "256(999)")  # > 255
    }

    # RX_FN_OKLCH: /(on_|over_)? oklch\(\s* (NNF) \s*,\s* (NNF(?:max)?|max) \s*,\s* (NNF) \s*\)/
    result = @ss.send(:compute_decl, "oklch(0.7, 0.15, 180)")
    assert_equal Gouache::Color.new(role: 38, oklch: [0.7, 0.15, 180]), result

    result = @ss.send(:compute_decl, "on_oklch(0.5, 0.1, 30)")
    assert_equal Gouache::Color.new(role: 48, oklch: [0.5, 0.1, 30]), result

    result = @ss.send(:compute_decl, "over_oklch(0.8, 0.2, 90)")
    assert_equal Gouache::Color.new(role: 58, oklch: [0.8, 0.2, 90]), result

    # Test relative chroma with "max" suffix
    result = @ss.send(:compute_decl, "oklch(0.6, 0.5max, 45)")
    assert_equal Gouache::Color.new(role: 38, oklch: [0.6, "0.5max", 45]), result

    # Test plain "max"
    result = @ss.send(:compute_decl, "oklch(0.5, max, 120)")
    assert_equal Gouache::Color.new(role: 38, oklch: [0.5, "max", 120]), result

    # Test with whitespace
    result = @ss.send(:compute_decl, "oklch( 0.7 , 0.1max , 240 )")
    assert_equal Gouache::Color.new(role: 38, oklch: [0.7, "0.1max", 240]), result
  end

  def test_compute_decl_oklch_function_edge_cases
    # Test integer lightness values (should work as floats)
    result = @ss.send(:compute_decl, "oklch(1, 0.1, 0)")
    assert_equal Gouache::Color.new(role: 38, oklch: [1.0, 0.1, 0.0]), result

    # Test zero values
    result = @ss.send(:compute_decl, "oklch(0, 0, 0)")
    assert_equal Gouache::Color.new(role: 38, oklch: [0.0, 0.0, 0.0]), result

    # Test decimal-only chroma with max
    result = @ss.send(:compute_decl, "oklch(0.5, .8max, 180)")
    assert_equal Gouache::Color.new(role: 38, oklch: [0.5, ".8max", 180.0]), result

    # Test large hue values (should work)
    result = @ss.send(:compute_decl, "oklch(0.6, 0.1, 359.99)")
    assert_equal Gouache::Color.new(role: 38, oklch: [0.6, 0.1, 359.99]), result

    # Test all role prefixes with relative chroma
    result = @ss.send(:compute_decl, "on_oklch(0.4, 0.3max, 270)")
    assert_equal Gouache::Color.new(role: 48, oklch: [0.4, "0.3max", 270.0]), result

    result = @ss.send(:compute_decl, "over_oklch(0.9, max, 45)")
    assert_equal Gouache::Color.new(role: 58, oklch: [0.9, "max", 45.0]), result

    # Test invalid patterns (should not match OKLCH regex)
    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "oklch(-0.1, 0.1, 0)")  # negative lightness
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "oklch(0.5, -0.1max, 0)")  # negative relative chroma
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "oklch(0.5, 0.1maxs, 0)")  # invalid suffix
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "oklch(0.5)")  # missing parameters
    }

    assert_raises(NoMatchingPatternError) {
      @ss.send(:compute_decl, "oklch(0.5, 0.1)")  # missing hue
    }
  end

  def test_compute_decl_proc_case
    effect = proc { |top, under| "test effect" }
    result = @ss.send(:compute_decl, effect)

    assert_instance_of Proc, result
    assert_equal effect, result
  end

  def test_compute_decl_with_proc_and_sgr_mixed
    effect1 = proc { |top, under| top.bold = true }
    effect2 = proc { |top, under| under.italic = false }

    result = @ss.send(:compute_decl, [effect1, effect2, 31])
    assert_equal [effect1, effect2, Gouache::Color.sgr(31)], result
  end

  def test_compute_rule_deep_nested_arrays_mixed_types
    effect1 = proc { |top, under| top.bold = true }
    effect2 = proc { |top, under| under.italic = false }
    color1 = Gouache::Color.rgb(255, 0, 0)  # red fg
    color2 = Gouache::Color.on_rgb(0, 255, 0)  # green bg

    # Deeply nested array with mixed types
    nested_array = [
      1,                                   # bold
      [
        effect1,                           # first effect
        [
          color1,                          # red fg
          [effect2, 4],                    # second effect + underline
          32                               # green fg (overrides red)
        ],
        color2                             # green bg
      ],
      3                                    # italic
    ]

    # Create stylesheet with complex rule
    ss = Gouache::Stylesheet.new({
      complex_rule: nested_array
    }, base: nil)

    # Test compute_rule processes everything correctly
    result = ss.send(:compute_rule, :complex_rule)

    # Should return the flattened styles array
    assert_kind_of Array, result
    assert_includes result, effect1
    assert_includes result, effect2
    assert_includes result, color1
    assert_includes result, color2
    assert_includes result, 1  # bold
    assert_includes result, 4  # underline
    assert_includes result, 3  # italic

    # Check effects are separated correctly
    effects = ss.effects[:complex_rule]
    assert_equal [effect1, effect2], effects

    # Check layer has merged colors and SGR codes
    layer = ss.layers[:complex_rule]
    assert_kind_of Gouache::Layer, layer

    # Check color merging - complex merged color: RGB from red, basic from green (32)
    fg_color = layer[Gouache::Layer::RANGES[:fg].index]
    assert_equal [255, 0, 0], fg_color.rgb  # red RGB preserved
    assert_equal 32, fg_color.basic         # green basic wins

    # Check bg color is present (green bg)
    bg_color = layer[Gouache::Layer::RANGES[:bg].index]
    assert_equal [0, 255, 0], bg_color.rgb  # green bg

    # Check SGR codes are applied
    assert_equal 1, layer[Gouache::Layer::RANGES[:bold].index]       # bold
    assert_equal 4, layer[Gouache::Layer::RANGES[:underline].index] # underline
    assert_equal 3, layer[Gouache::Layer::RANGES[:italic].index]    # italic
  end

  def test_compute_rule_color_merging_precedence
    # Test that later colors take precedence in merge
    red_color = Gouache::Color.rgb(255, 0, 0)
    green_color = Gouache::Color.rgb(0, 255, 0)

    ss = Gouache::Stylesheet.new({
      color_merge_test: [red_color, green_color]  # green should win
    }, base: nil)

    layer = ss.layers[:color_merge_test]
    fg_color = layer[Gouache::Layer::RANGES[:fg].index]

    # Later color (green) should take precedence
    assert_equal [0, 255, 0], fg_color.rgb
  end

  def test_base_merge_combines_styles
    # Test that BASE.merge combines existing styles with new ones
    merged_ss = Gouache::Stylesheet::BASE.merge({red: :underline})  # red + underline

    # Original red should be just 31 in BASE
    original_red = Gouache::Stylesheet::BASE.layers[:red]
    assert_equal Gouache::Layer.from(31), original_red

    # Merged red should have both 31 and 4
    merged_red = merged_ss.layers[:red]
    assert_equal Gouache::Layer.from(31, 4), merged_red

    # Should have red color and underline SGR
    assert_equal 31, merged_red[Gouache::Layer::RANGES[:fg].index].basic
    assert_equal 4, merged_red[Gouache::Layer::RANGES[:underline].index]
  end

  def test_compute_rule_caching
    call_count = 0
    original_compute_decl = Gouache::Stylesheet.instance_method(:compute_decl)

    ss = Gouache::Stylesheet.new({test_rule: 31}, base: nil)

    # Define a method to count calls to compute_decl
    ss.define_singleton_method(:compute_decl) do |x|
      call_count += 1 if x == 31
      original_compute_decl.bind(self).call(x)
    end

    # First call should compute
    result1 = ss.send(:compute_rule, :test_rule)
    assert_equal 1, call_count

    # Second call should use cache
    result2 = ss.send(:compute_rule, :test_rule)
    assert_equal 1, call_count  # Should not increment

    assert_equal result1, result2
  end

  def test_stylesheet_with_direct_color_objects
    # Test creating Gouache with direct Color objects as style values
    fg_color = Gouache::Color.rgb(255, 128, 0)
    bg_color = Gouache::Color.on_rgb(0, 255, 128)
    ul_color = Gouache::Color.over_rgb(255, 0, 255)

    go = Gouache.new(
      orange_text: fg_color,
      green_bg: bg_color,
      magenta_ul: ul_color
    )

    result = go[:orange_text, "orange", :green_bg, "green", :magenta_ul, "magenta"]

    # Should contain proper escape sequences
    assert_includes result, "\e[38;2;255;128;0m"  # orange fg
    assert_includes result, "\e[48;2;0;255;128m"  # green bg
    assert_includes result, "\e[58;2;255;0;255m"  # magenta ul
    assert_includes result, "orange"
    assert_includes result, "green"
    assert_includes result, "magenta"
  end

  def test_stylesheet_with_color_objects_in_arrays
    # Test Color objects mixed with SGR codes in array styles
    fg_color = Gouache::Color.rgb(255, 0, 0)
    bg_color = Gouache::Color.on_rgb(0, 0, 255)

    go = Gouache.new(
      complex_style: [1, fg_color, bg_color, 3]  # bold, red fg, blue bg, italic
    )

    result = go[:complex_style, "styled text"]

    # Should contain proper escape sequences for bold, colors, and italic
    assert_includes result, "\e[22;38;2;255;0;0;48;2;0;0;255;3;1m"
    assert_includes result, "styled text"
  end

  def test_stylesheet_with_basic_color_objects
    # Test Color objects created from basic SGR codes
    red_fg = Gouache::Color.sgr(31)
    green_bg = Gouache::Color.sgr(42)
    bright_blue = Gouache::Color.sgr(94)

    go = Gouache.new(
      basic_red: red_fg,
      basic_green_bg: green_bg,
      bright_blue: bright_blue
    )

    result = go[:basic_red, "red", :basic_green_bg, "green", :bright_blue, "blue"]

    assert_includes result, "\e[31m"
    assert_includes result, "\e[42m"
    assert_includes result, "\e[94m"
  end

  def test_stylesheet_color_objects_with_effects
    # Test Color objects combined with effects
    red_color = Gouache::Color.rgb(255, 0, 0)
    effect = proc { |top, under| top.bold = true }

    go = Gouache.new(
      red_with_effect: [red_color, effect]
    )

    result = go[:red_with_effect, "text"]

    # Should contain red color and bold effect
    assert_includes result, "\e[22;38;2;255;0;0;1m"
    assert_includes result, "text"
  end

end
