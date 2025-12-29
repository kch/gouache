# frozen_string_literal: true

require_relative "test_helper"

class TestStylesheet < Minitest::Test

  def setup
    super
    @ss = Gouache::Stylesheet::BASE
    Gouache::Term.color_level = :truecolor
  end


  def test_stylesheet_initialization_empty_and_nil_cases
    # All combinations of empty/nil for styles and base parameters

    # Empty styles, nil base
    ss1 = Gouache::Stylesheet.new({}, base: nil)
    assert_kind_of Hash, ss1.layer_map
    assert ss1.layer_map.empty?

    # Nil styles, nil base
    ss2 = Gouache::Stylesheet.new(nil, base: nil)
    assert_kind_of Hash, ss2.layer_map
    assert ss2.layer_map.empty?

    # Custom styles with nil base
    ss3 = Gouache::Stylesheet.new({custom: 1}, base: nil)
    assert ss3.layer_map[:custom]
    assert_kind_of Gouache::Layer, ss3.layer_map[:custom]
  end

  def test_base_parameter_type_requirements
    # base: nil should work
    ss1 = Gouache::Stylesheet.new({}, base: nil)
    assert_kind_of Hash, ss1.layer_map

    # base: Stylesheet should work
    base_ss = Gouache::Stylesheet.new({red: 31}, base: nil)
    ss2 = Gouache::Stylesheet.new({blue: 34}, base: base_ss)
    assert_kind_of Hash, ss2.layer_map
    assert ss2.layer_map[:red]  # Should inherit from base
    assert ss2.layer_map[:blue] # Should have new styles

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
      assert_equal Gouache::Layer.from(91), override_ss.layer_map[:red]
    end
  end

  def test_stylesheet_has_base_styles
    assert @ss.layer_map[:red]
    assert @ss.layer_map[:bold]
    assert @ss.layer_map[:on_blue]
  end

  def test_stylesheet_layer_map_are_layers
    assert_kind_of Gouache::Layer, @ss.layer_map[:red]
    assert_kind_of Gouache::Layer, @ss.layer_map[:bold]
  end

  def test_compute_decl_nil
    result = @ss.send(:compute_decl, nil)
    assert_kind_of Gouache::Layer, result
    assert_equal Gouache::Layer.empty, result  # nil -> empty 11-position Layer
  end

  def test_compute_decl_integer
    result = @ss.send(:compute_decl, 31)
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_string_integer
    result = @ss.send(:compute_decl, "31")
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_sgr_string
    result = @ss.send(:compute_decl, "31;1")
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_rgb24_string
    result = @ss.send(:compute_decl, "rgb(255,0,0)")  # 24-bit RGB color format
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result

    # Background version
    result = @ss.send(:compute_decl, "on_rgb(255,0,0)")
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_hex24_string
    result = @ss.send(:compute_decl, "#ff0000")      # 6-digit hex color
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result

    # Background version
    result = @ss.send(:compute_decl, "on#ff0000")
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_hex8_string
    result = @ss.send(:compute_decl, "#500")         # 3-digit hex color (RGB cube)
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result

    # Background version
    result = @ss.send(:compute_decl, "on#500")
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_256_string
    result = @ss.send(:compute_decl, "256(123)")     # 256-color palette index
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result

    # Background version
    result = @ss.send(:compute_decl, "on_256(123)")
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_gray_string
    result = @ss.send(:compute_decl, "gray(12)")     # Grayscale 0-23
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result

    # Background version
    result = @ss.send(:compute_decl, "on_gray(12)")
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_array
    result = @ss.send(:compute_decl, [31, 1])        # Array recursively flattened
    assert_kind_of Gouache::Layer, result
    refute_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_symbol_existing
    result = @ss.send(:compute_decl, :red)
    assert_kind_of Gouache::Layer, result
    assert_equal @ss.layer_map[:red], result
  end

  def test_compute_decl_selector_string
    result = @ss.send(:compute_decl, "red")
    assert_kind_of Gouache::Layer, result
    assert_equal @ss.layer_map[:red], result
  end

  def test_compute_rule_existing_selector
    result = @ss.send(:compute_rule, :red)
    assert_kind_of Gouache::Layer, result
    assert_equal @ss.layer_map[:red], result
  end

  def test_compute_rule_nonexistent_selector
    ss = Gouache::Stylesheet.new({custom: 31}, base: nil)  # Selector exists in @styles but not @layer_map yet
    result = ss.send(:compute_rule, :custom)    # Should compute and cache in @layer_map
    assert_kind_of Gouache::Layer, result
    assert_equal ss.layer_map[:custom], result
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
    # Valid selector patterns that should match RX_SEL
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "red")      # Simple word
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "bold!")    # Word with !
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "italic?")  # Word with ?
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "red123")   # Word with numbers
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
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "256(0)")
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "256(255)")
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "rgb(0,0,0)")
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "rgb(255,255,255)")

    # Invalid D256 values (>255)
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "256(256)") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "rgb(256,0,0)") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "rgb(0,256,0)") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "rgb(0,0,256)") }
  end

  def test_compute_decl_d24_bounds_checking
    # Valid D24 values (0-23)
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "gray(0)")
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "gray(23)")

    # Invalid D24 values (>23)
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "gray(24)") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "gray(100)") }
  end

  def test_compute_decl_hex_case_sensitivity
    # 6-digit hex should work with upper/lower case
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#ff0000")  # lowercase
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#FF0000")  # uppercase
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#Ff0000")  # mixed case

    # 3-digit hex uses digits 0-5 only (RGB cube mapping)
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#500")     # valid digits
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#123")     # valid digits
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#055")     # valid digits

    # Background hex colors
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "on#ff0000")
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "on#FF0000")
  end

  def test_compute_decl_hex_bounds_checking
    # Valid hex8 digits (0-5 only)
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#000")
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#555")

    # Invalid hex8 digits (6-9, A-F not allowed in RGB cube)
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#600") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#5a0") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#5A0") }
    assert_raises(NoMatchingPatternError) { @ss.send(:compute_decl, "#999") }

    # Valid hex24 accepts full hex range
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#abcdef")
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#ABCDEF")
    assert_kind_of Gouache::Layer, @ss.send(:compute_decl, "#123abc")

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

  def test_square_bracket_method
    # Single selector
    result = @ss[:red]
    assert_kind_of Gouache::Layer, result
    assert_equal @ss.layer_map[:red], result

    # String selector converted to symbol
    result = @ss["red"]
    assert_equal @ss[:red], result

    # Non-existent selector returns nil
    result = @ss[:nonexistent]
    assert_nil result
  end

  def test_to_h_method
    # Create stylesheet with varied declaration types
    custom_base = {
      simple_int:    31,                    # Single integer
      array_decl:    [1, 31],              # Array declaration
      string_decl:   "31;1",               # SGR string
      rgb_decl:      "rgb(255,0,0)",       # RGB color
      hex_decl:      "#ff0000",            # Hex color
      mixed_sgr:     "1;38;2;255;128;0;4", # Mixed SGR with RGB color
      symbol_ref:    :simple_int,          # Symbol reference
    }
    # Convert custom_base to layer_map by creating temporary stylesheet
    base_stylesheet = Gouache::Stylesheet.new(custom_base, base: nil)
    ss = Gouache::Stylesheet.new({}, base: base_stylesheet)

    result = ss.to_h
    assert_kind_of Hash, result

    # Test keys are present
    expected_keys = [:simple_int, :array_decl, :string_decl, :rgb_decl, :hex_decl, :mixed_sgr, :symbol_ref]
    assert_equal expected_keys.sort, result.keys.sort

    # Test specific final values
    assert_equal 31, result[:simple_int]           # Single value unwrapped
    assert_equal [31, 1], result[:array_decl]      # Array sorted descending
    assert_equal [31, 1], result[:string_decl]     # SGR string parsed and sorted
    assert_equal "38;2;255;0;0", result[:rgb_decl] # RGB converted to SGR string
    assert_equal "38;2;255;0;0", result[:hex_decl] # Hex converted to SGR string
    assert_equal ["38;2;255;128;0", 4, 1], result[:mixed_sgr] # Mixed SGR with RGB color preserved
    assert_equal 31, result[:symbol_ref]           # Symbol reference resolved
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
      assert_kind_of Gouache::Layer, ss.layer_map[key], "#{key} should be Layer"
    end

    # Test specific SGR values for key patterns
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;2;252;0;0"), ss.layer_map[:red]  # #fc0000
    assert_equal Gouache::Layer.from(1), ss.layer_map[:a]                 # bold
    assert_equal ss.layer_map[:a], ss.layer_map[:b]                           # b->a chain
    assert_equal Gouache::Layer.empty, ss.layer_map[:d]                   # nil
    assert_equal Gouache::Layer.from(31, 4), ss.layer_map[:g]             # "31;4"
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;2;1;2;233"), ss.layer_map[:k]    # rgb(1,2,233)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;255"), ss.layer_map[:l]        # gray(23) = 232+23
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;123"), ss.layer_map[:n]        # 256(123)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;2;1;2;3"), ss.layer_map[:o]      # on_rgb(1,2,3)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;67"), ss.layer_map[:s]         # #123 = 1*36+2*6+3+16

    # Test new over_* underline color functions
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;2;255;128;0"), ss.layer_map[:over_rgb1]  # over_rgb(255,128,0)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;5;247"), ss.layer_map[:over_gray1]        # over_gray(15) = 232+15
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;5;196"), ss.layer_map[:over_2561]         # over_256(196)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;2;255;128;0"), ss.layer_map[:over_hex1]   # over#ff8000
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;5;208"), ss.layer_map[:over_cube1]        # over#520 = 5*36+2*6+0+16

    # Test complex array combination: ["blink", :underline, :l, "on#123"]
    # Expected: gray(23)=38;5;255 + on#123=48;5;67 + blink(5) + underline(4)
    assert_equal "38;5;255;48;5;67;5;4", ss.layer_map[:w].to_sgr
  end

  def test_valid_sgr_with_empty_segments
    # Test SGR strings with empty segments (leading/trailing/internal semicolons)
    ss = Gouache::Stylesheet.new({mixed: ";31;;4;"}, base: nil)
    assert_kind_of Gouache::Layer, ss.layer_map[:mixed]
    refute_equal Gouache::Layer.empty, ss.layer_map[:mixed]
  end

  def test_string_symbol_key_mismatch_bug
    # Test for bug where @styles.delete sel used wrong key type
    # If @styles has string keys but compute_rule uses symbol for @sels tracking
    ss = Gouache::Stylesheet.new({}, base: nil)
    ss.instance_variable_set(:@styles, {"string_key" => 31})  # String key in @styles

    # This should not cause infinite loop - compute_rule should handle string/symbol conversion correctly
    result = ss.send(:compute_rule, "string_key")  # Pass string selector
    assert_kind_of Gouache::Layer, result

    # Key should be properly deleted from @styles after computation
    refute ss.instance_variable_get(:@styles).key?("string_key")

    # Test reverse case: symbol key in @styles, string selector
    ss2 = Gouache::Stylesheet.new({}, base: nil)
    ss2.instance_variable_set(:@styles, {symbol_key: 31})  # Symbol key in @styles

    result2 = ss2.send(:compute_rule, :symbol_key)  # Pass symbol selector
    assert_kind_of Gouache::Layer, result2

    # Key should be properly deleted from @styles
    refute ss2.instance_variable_get(:@styles).key?(:symbol_key)
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
      assert_kind_of Gouache::Layer, ss.layer_map[key]
      refute_equal Gouache::Layer.empty, ss.layer_map[key]
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
      assert_kind_of Gouache::Layer, ss.layer_map[key]
      refute_equal Gouache::Layer.empty, ss.layer_map[key], "#{key} should not be empty"
    end

    # Test specific SGR values
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;2;0;0;0"), ss.layer_map[:rgb1]          # rgb(0,0,0)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;2;255;255;255"), ss.layer_map[:rgb2]    # rgb(255,255,255)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;2;128;64;32"), ss.layer_map[:rgb_bg1]   # on_rgb(128,64,32)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;2;255;0;128"), ss.layer_map[:rgb_bg2]   # on_rgb(255,0,128)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;2;255;128;0"), ss.layer_map[:rgb_ul1]   # over_rgb(255,128,0)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;2;0;255;128"), ss.layer_map[:rgb_ul2]   # over_rgb(0,255,128)

    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;0"), ss.layer_map[:color256_1]        # 256(0)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;255"), ss.layer_map[:color256_2]      # 256(255)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;5;0"), ss.layer_map[:color256_bg1]      # on_256(0)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;5;255"), ss.layer_map[:color256_bg2]    # on_256(255)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;5;196"), ss.layer_map[:color256_ul1]    # over_256(196)
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;5;46"), ss.layer_map[:color256_ul2]     # over_256(46)

    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;232"), ss.layer_map[:gray1]           # gray(0) = 232+0
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;255"), ss.layer_map[:gray2]           # gray(23) = 232+23
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;5;232"), ss.layer_map[:gray_bg1]        # on_gray(0) = 232+0
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;5;255"), ss.layer_map[:gray_bg2]        # on_gray(23) = 232+23
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;5;247"), ss.layer_map[:gray_ul1]        # over_gray(15) = 232+15
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "58;5;237"), ss.layer_map[:gray_ul2]        # over_gray(5) = 232+5

    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;16"), ss.layer_map[:hex3_1]           # #000 = 0*36+0*6+0+16
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;5;231"), ss.layer_map[:hex3_2]          # #555 = 5*36+5*6+5+16
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;2;0;0;0"), ss.layer_map[:hex6_1]        # #000000
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;2;255;255;255"), ss.layer_map[:hex6_2]  # #ffffff
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "38;2;171;205;239"), ss.layer_map[:hex6_3]  # #abcdef
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;5;67"), ss.layer_map[:hex_bg3_1]        # on#123 = 1*36+2*6+3+16
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;5;189"), ss.layer_map[:hex_bg3_2]       # on#445 = 4*36+4*6+5+16
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;2;0;0;0"), ss.layer_map[:hex_bg6_1]     # on#000000
    assert_equal Gouache::Layer.from(Gouache::Color.sgr "48;2;255;255;255"), ss.layer_map[:hex_bg6_2] # on#ffffff

    # OKLCH functions should create proper Color objects (converted to SGR for comparison)
    assert_equal Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.5, 0.1, 30])), ss.layer_map[:oklch1]
    assert_equal Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.8, 0.2, 180])), ss.layer_map[:oklch2]
    assert_equal Gouache::Layer.from(Gouache::Color.new(role: 48, oklch: [0.3, 0.05, 90])), ss.layer_map[:oklch_bg1]
    assert_equal Gouache::Layer.from(Gouache::Color.new(role: 48, oklch: [0.7, 0.15, 270])), ss.layer_map[:oklch_bg2]
    assert_equal Gouache::Layer.from(Gouache::Color.new(role: 58, oklch: [0.6, 0.1, 45])), ss.layer_map[:oklch_ul1]
    assert_equal Gouache::Layer.from(Gouache::Color.new(role: 58, oklch: [0.4, 0.08, 315])), ss.layer_map[:oklch_ul2]
    assert_equal Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.5, "0.5max", 60])), ss.layer_map[:oklch_rel1]
    assert_equal Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.7, "max", 120])), ss.layer_map[:oklch_rel2]
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
      assert_kind_of Gouache::Layer, ss.layer_map[key]
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
    assert_equal Gouache::Layer.from(31), merged_ss.layer_map[:red]
    assert_equal Gouache::Layer.from(1), merged_ss.layer_map[:bold]
    assert_equal Gouache::Layer.from(34), merged_ss.layer_map[:blue]
    assert_equal Gouache::Layer.from(32), merged_ss.layer_map[:green]
  end

  def test_merge_method_with_override
    # Create base stylesheet
    base_styles = {red: 31, bold: 1}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with overriding styles
    merge_styles = {red: 91, italic: 3}  # red overrides base red
    merged_ss = base_ss.merge(merge_styles)

    # Merged styles should override base styles
    assert_equal Gouache::Layer.from(91), merged_ss.layer_map[:red]  # overridden
    assert_equal Gouache::Layer.from(1), merged_ss.layer_map[:bold]   # from base
    assert_equal Gouache::Layer.from(3), merged_ss.layer_map[:italic] # new
  end

  def test_merge_method_preserves_original
    base_styles = {red: 31}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge should not modify original
    original_red = base_ss.layer_map[:red]
    merged_ss = base_ss.merge({blue: 34})

    # Original should be unchanged
    assert_equal original_red, base_ss.layer_map[:red]
    refute base_ss.layer_map.key?(:blue)

    # Merged should have both
    assert_equal original_red, merged_ss.layer_map[:red]
    assert_equal Gouache::Layer.from(34), merged_ss.layer_map[:blue]
  end

  def test_merge_method_with_multiple_hashes
    # Create base stylesheet
    base_styles = {red: 31, bold: 1}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with multiple style hashes
    merged_ss = base_ss.merge({blue: 34, green: 32}, {yellow: 33, red: 91})

    # Should have all styles, with later hashes overriding earlier ones
    assert_equal Gouache::Layer.from(91), merged_ss.layer_map[:red]  # overridden by second hash
    assert_equal Gouache::Layer.from(1), merged_ss.layer_map[:bold]   # from base
    assert_equal Gouache::Layer.from(34), merged_ss.layer_map[:blue]  # from first hash
    assert_equal Gouache::Layer.from(32), merged_ss.layer_map[:green] # from first hash
    assert_equal Gouache::Layer.from(33), merged_ss.layer_map[:yellow] # from second hash
  end

  def test_merge_method_with_empty_hashes
    base_styles = {red: 31}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with empty hashes and non-empty hash
    merged_ss = base_ss.merge({}, {blue: 34}, {})

    # Should work with empty hashes mixed in
    assert_equal Gouache::Layer.from(31), merged_ss.layer_map[:red]
    assert_equal Gouache::Layer.from(34), merged_ss.layer_map[:blue]
  end

  def test_merge_method_with_single_hash_still_works
    # Backwards compatibility test
    base_styles = {red: 31}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    merged_ss = base_ss.merge({blue: 34})

    # Single hash should still work
    assert_equal Gouache::Layer.from(31), merged_ss.layer_map[:red]
    assert_equal Gouache::Layer.from(34), merged_ss.layer_map[:blue]
  end

  def test_merge_method_with_no_arguments
    base_styles = {red: 31}
    base_ss = Gouache::Stylesheet.new(base_styles, base: nil)

    # Merge with no arguments should return copy of base
    merged_ss = base_ss.merge()

    assert_equal Gouache::Layer.from(31), merged_ss.layer_map[:red]
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
    layer = ss[:test_array]

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
    layer = ss[:test_mixed]

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
    ss = Gouache::Stylesheet.new({empty_rule: []}, base: nil)
    layer = ss[:empty_rule]

    # Empty array should result in empty layer
    assert_kind_of Gouache::Layer, layer
    assert_equal 0, layer.compact.length
  end

  def test_stylesheet_to_h_color_conversion
    # Test that to_h converts Color objects to SGR strings
    color = Gouache::Color.rgb(255, 0, 0)
    ss = Gouache::Stylesheet.new({test_color: color}, base: nil)
    hash = ss.to_h

    # Color should be converted to SGR string
    assert_equal "38;2;255;0;0", hash[:test_color]
  end

  def test_stylesheet_to_h_mixed_colors_and_codes
    # Test to_h with mix of Color objects and SGR codes
    color = Gouache::Color.rgb(255, 0, 0)
    ss = Gouache::Stylesheet.new({test_style: [1, color, 4]}, base: nil)
    hash = ss.to_h

    # Should convert Color to SGR, keep other codes as-is (order may vary)
    assert_includes hash[:test_style], 1
    assert_includes hash[:test_style], "38;2;255;0;0"
    assert_includes hash[:test_style], 4
    assert_equal 3, hash[:test_style].size
  end

  def test_stylesheet_to_h_single_color_unwrapped
    # Test that single Color gets unwrapped from array
    color = Gouache::Color.sgr(31)
    ss = Gouache::Stylesheet.new({test_single: color}, base: nil)
    hash = ss.to_h

    # Single item should be unwrapped
    assert_equal 31, hash[:test_single]
  end

  def test_compute_decl_nil_case
    result = @ss.send(:compute_decl, nil)
    assert_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_color_case
    color = Gouache::Color.rgb(255, 0, 0)
    result = @ss.send(:compute_decl, color)
    assert_equal Gouache::Layer.from(color), result
  end

  def test_compute_decl_layer_case
    layer = Gouache::Layer.from([31, 1])  # red foreground + bold
    result = @ss.send(:compute_decl, layer)
    assert_equal layer, result
  end

  def test_compute_decl_symbol_case
    result = @ss.send(:compute_decl, :red)
    assert_equal @ss[:red], result
  end

  def test_compute_decl_array_case_basic
    result = @ss.send(:compute_decl, [31, 1])  # red foreground + bold
    expected = Gouache::Layer.from([31, 1])
    assert_equal expected, result
  end

  def test_compute_decl_ru_basic_case
    # Test various RU_BASIC ranges: 39, 49, 59, 30..37, 40..47, 90..97, 100..107

    # Single values: 39 (default fg), 49 (default bg), 59 (default underline color)
    result = @ss.send(:compute_decl, 39)
    expected = Gouache::Layer.from(Gouache::Color.sgr(39))
    assert_equal expected, result

    result = @ss.send(:compute_decl, 49)
    expected = Gouache::Layer.from(Gouache::Color.sgr(49))
    assert_equal expected, result

    result = @ss.send(:compute_decl, 59)
    expected = Gouache::Layer.from(Gouache::Color.sgr(59))
    assert_equal expected, result

    # 30..37 range (standard fg colors)
    result = @ss.send(:compute_decl, 31)  # red foreground
    expected = Gouache::Layer.from(Gouache::Color.sgr(31))
    assert_equal expected, result

    result = @ss.send(:compute_decl, 37)  # white foreground
    expected = Gouache::Layer.from(Gouache::Color.sgr(37))
    assert_equal expected, result

    # 40..47 range (standard bg colors)
    result = @ss.send(:compute_decl, 42)  # green background
    expected = Gouache::Layer.from(Gouache::Color.sgr(42))
    assert_equal expected, result

    # 90..97 range (bright fg colors)
    result = @ss.send(:compute_decl, 91)  # bright red foreground
    expected = Gouache::Layer.from(Gouache::Color.sgr(91))
    assert_equal expected, result

    # 100..107 range (bright bg colors)
    result = @ss.send(:compute_decl, 102)  # bright green background
    expected = Gouache::Layer.from(Gouache::Color.sgr(102))
    assert_equal expected, result
  end

  def test_compute_decl_rx_basic_case
    # Test RX_BASIC pattern: string versions of basic SGR codes
    # RX_BASIC matches /\A(?:3|4|9|10)[0-7]\z/ - colors 30-37, 40-47, 90-97, 100-107
    # Plus individual values 39, 49, 59

    # Default colors (39, 49, 59)
    result = @ss.send(:compute_decl, "39")
    expected = Gouache::Layer.from(Gouache::Color.sgr("39"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "49")
    expected = Gouache::Layer.from(Gouache::Color.sgr("49"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "59")
    expected = Gouache::Layer.from(Gouache::Color.sgr("59"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "49")
    expected = Gouache::Layer.from(Gouache::Color.sgr("49"))
    assert_equal expected, result

    # Standard fg colors (30-37)
    result = @ss.send(:compute_decl, "31")
    expected = Gouache::Layer.from(Gouache::Color.sgr("31"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "37")
    expected = Gouache::Layer.from(Gouache::Color.sgr("37"))
    assert_equal expected, result

    # Standard bg colors (40-47)
    result = @ss.send(:compute_decl, "42")
    expected = Gouache::Layer.from(Gouache::Color.sgr("42"))
    assert_equal expected, result

    # Bright fg colors (90-97)
    result = @ss.send(:compute_decl, "91")
    expected = Gouache::Layer.from(Gouache::Color.sgr("91"))
    assert_equal expected, result

    # Bright bg colors (100-107)
    result = @ss.send(:compute_decl, "102")
    expected = Gouache::Layer.from(Gouache::Color.sgr("102"))
    assert_equal expected, result
  end

  def test_compute_decl_rx_ext_color_case
    # Test RX_EXT_COLOR pattern: extended color sequences
    # Pattern: /\A([34]8);(?:5;(#{D8})|2;(#{D8});(#{D8});(#{D8}))\z/

    # 256-color format: 38;5;n (fg) or 48;5;n (bg)
    result = @ss.send(:compute_decl, "38;5;196")  # bright red fg
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;5;196"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "48;5;46")   # bright green bg
    expected = Gouache::Layer.from(Gouache::Color.sgr("48;5;46"))
    assert_equal expected, result

    # 24-bit RGB format: 38;2;r;g;b (fg) or 48;2;r;g;b (bg)
    result = @ss.send(:compute_decl, "38;2;255;0;0")  # red fg
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;2;255;0;0"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "48;2;0;255;0")  # green bg
    expected = Gouache::Layer.from(Gouache::Color.sgr("48;2;0;255;0"))
    assert_equal expected, result
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
    # RU_SGR_NC = RangeExclusion.new 0..107, RU_BASIC, 38, 48, 58
    # Excludes: 39, 49, 59, 30..37, 40..47, 90..97, 100..107, 38, 48, 58

    # Valid non-color SGR codes that should return the integer directly
    result = @ss.send(:compute_decl, 0)   # reset - replaces with BASE layer
    assert_equal Gouache::Layer::BASE, result

    result = @ss.send(:compute_decl, 1)   # bold
    assert_equal Gouache::Layer.from(1), result

    result = @ss.send(:compute_decl, 2)   # dim
    assert_equal Gouache::Layer.from(2), result

    result = @ss.send(:compute_decl, 3)   # italic
    assert_equal Gouache::Layer.from(3), result

    result = @ss.send(:compute_decl, 4)   # underline
    assert_equal Gouache::Layer.from(4), result

    result = @ss.send(:compute_decl, 5)   # slow blink
    assert_equal Gouache::Layer.from(5), result

    result = @ss.send(:compute_decl, 7)   # reverse
    assert_equal Gouache::Layer.from(7), result

    result = @ss.send(:compute_decl, 8)   # conceal
    assert_equal Gouache::Layer.from(8), result

    result = @ss.send(:compute_decl, 9)   # strikethrough
    assert_equal Gouache::Layer.from(9), result

    # Reset codes in 20s range
    result = @ss.send(:compute_decl, 22)  # normal intensity
    assert_equal Gouache::Layer.from(22), result

    result = @ss.send(:compute_decl, 24)  # no underline
    assert_equal Gouache::Layer.from(24), result

    # Test that SGR 58 is excluded from RU_SGR_NC (incomplete sequence should fail)
    # SGR 58 alone is invalid - it requires color specification like 58;5;n or 58;2;r;g;b
    assert_raises(NoMatchingPatternError, "SGR 58 without color spec should not match any pattern") do
      @ss.send(:compute_decl, 58)
    end

    # Test weirder numbers in RU_SGR_NC range - unknown codes become all-nil layers
    result = @ss.send(:compute_decl, 99)  # unknown SGR code
    assert_equal Gouache::Layer.from(99), result
    assert_equal Array.new(Gouache::Layer::RANGES.length), result

    result = @ss.send(:compute_decl, 50)  # between basic ranges
    assert_equal Gouache::Layer.from(50), result
    assert_equal Array.new(Gouache::Layer::RANGES.length), result

    result = @ss.send(:compute_decl, 89)  # just below bright fg range
    assert_equal Gouache::Layer.from(89), result
    assert_equal Array.new(Gouache::Layer::RANGES.length), result

    result = @ss.send(:compute_decl, 98)  # just above bright fg range
    assert_equal Gouache::Layer.from(98), result
    assert_equal Array.new(Gouache::Layer::RANGES.length), result
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
    # Test RX_SGR pattern: SGR sequences that get scanned and recursively processed
    # RX_SGR = /\A[\d;]+\z/

    result = @ss.send(:compute_decl, "31;1")
    expected_parts = Gouache.scan_sgr("31;1").map{ @ss.send(:compute_decl, it) }
    expected = Gouache::Layer.from(expected_parts)
    assert_equal expected, result

    result = @ss.send(:compute_decl, "38;5;196;1")
    expected_parts = Gouache.scan_sgr("38;5;196;1").map{ @ss.send(:compute_decl, it) }
    expected = Gouache::Layer.from(expected_parts)
    assert_equal expected, result

    result = @ss.send(:compute_decl, "0;31;42")
    expected_parts = Gouache.scan_sgr("0;31;42").map{ @ss.send(:compute_decl, it) }
    expected = Gouache::Layer.from(expected_parts)
    assert_equal expected, result

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
    expected_parts = Gouache.scan_sgr("28;5;100").map{ @ss.send(:compute_decl, it) }
    expected = Gouache::Layer.from(expected_parts)
    assert_equal expected, result
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
    assert_equal Gouache::Layer.from(1), result

    result = ss.send(:compute_decl, "Z")  # case insensitive
    assert_equal ss.send(:compute_rule, :Z), result
    assert_equal Gouache::Layer.from(2), result

    # Letters with word characters (letters, digits, underscore)
    result = ss.send(:compute_decl, "red123")
    assert_equal ss.send(:compute_rule, :red123), result
    assert_equal Gouache::Layer.from(Gouache::Color.sgr(31)), result

    result = ss.send(:compute_decl, "my_color")
    assert_equal ss.send(:compute_rule, :my_color), result
    assert_equal Gouache::Layer.from(Gouache::Color.sgr(32)), result

    result = ss.send(:compute_decl, "Color_123_ABC")
    assert_equal ss.send(:compute_rule, :Color_123_ABC), result
    assert_equal Gouache::Layer.from(Gouache::Color.sgr(33)), result

    # With optional ? suffix
    result = ss.send(:compute_decl, "red?")
    assert_equal ss.send(:compute_rule, :red?), result
    assert_equal Gouache::Layer.from(Gouache::Color.sgr(34)), result

    result = ss.send(:compute_decl, "my_method?")
    assert_equal ss.send(:compute_rule, :my_method?), result
    assert_equal Gouache::Layer.from(Gouache::Color.sgr(35)), result

    # With optional ! suffix
    result = ss.send(:compute_decl, "bold!")
    assert_equal ss.send(:compute_rule, :bold!), result
    assert_equal Gouache::Layer.from(1), result

    result = ss.send(:compute_decl, "danger_style!")
    assert_equal ss.send(:compute_rule, :danger_style!), result
    assert_equal Gouache::Layer.from(Gouache::Color.sgr(91)), result

    # Mixed case variations
    result = ss.send(:compute_decl, "CamelCase")
    assert_equal ss.send(:compute_rule, :CamelCase), result
    assert_equal Gouache::Layer.from(Gouache::Color.sgr(36)), result

    result = ss.send(:compute_decl, "mixedCase123!")
    assert_equal ss.send(:compute_rule, :mixedCase123!), result
    assert_equal Gouache::Layer.from(Gouache::Color.sgr(92)), result
  end

  def test_compute_decl_rx_fn_color_functions
    # Test all RX_FN_* color function patterns

    # RX_FN_HEX: /(on)?#(\h{6})/
    result = @ss.send(:compute_decl, "#ff0000")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;2;255;0;0"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "on#00ff00")
    expected = Gouache::Layer.from(Gouache::Color.sgr("48;2;0;255;0"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "over#0000ff")
    expected = Gouache::Layer.from(Gouache::Color.sgr("58;2;0;0;255"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "#123abc")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;2;18;58;188"))
    assert_equal expected, result

    # RX_FN_RGB: /(on_)? rgb \(\s* (D8) \s*,\s* (D8) \s*,\s* (D8) \s*\)/
    result = @ss.send(:compute_decl, "rgb(255,128,64)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;2;255;128;64"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "on_rgb(0, 255, 0)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("48;2;0;255;0"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "over_rgb(255, 128, 0)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("58;2;255;128;0"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "rgb( 100 , 150 , 200 )")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;2;100;150;200"))
    assert_equal expected, result

    # RX_FN_CUBE: /(on)?#[0-5]{3}/
    result = @ss.send(:compute_decl, "#500")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;5;196"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "on#023")
    expected = Gouache::Layer.from(Gouache::Color.sgr("48;5;31"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "#135")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;5;75"))
    assert_equal expected, result

    # RX_FN_GRAY: /(on_)? gray \(\s* (D24) \s* \)/
    result = @ss.send(:compute_decl, "on_gray(15)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("48;5;247"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "over_gray(10)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("58;5;242"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "on_gray( 0 )")
    expected = Gouache::Layer.from(Gouache::Color.sgr("48;5;232"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "gray(23)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;5;255"))
    assert_equal expected, result

    # RX_FN_256: /(on_)? 256 \(\s* (D8) \s* \)/
    result = @ss.send(:compute_decl, "256(196)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;5;196"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "on_256(46)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("48;5;46"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "over_256(196)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("58;5;196"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "over#520")
    expected = Gouache::Layer.from(Gouache::Color.sgr("58;5;208"))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "256(255)")
    expected = Gouache::Layer.from(Gouache::Color.sgr("38;5;255"))
    assert_equal expected, result

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
    expected = Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.7, 0.15, 180]))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "on_oklch(0.5, 0.1, 30)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 48, oklch: [0.5, 0.1, 30]))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "over_oklch(0.8, 0.2, 90)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 58, oklch: [0.8, 0.2, 90]))
    assert_equal expected, result

    # Test relative chroma with "max" suffix
    result = @ss.send(:compute_decl, "oklch(0.6, 0.5max, 45)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.6, "0.5max", 45]))
    assert_equal expected, result

    # Test plain "max"
    result = @ss.send(:compute_decl, "oklch(0.5, max, 120)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.5, "max", 120]))
    assert_equal expected, result

    # Test with whitespace
    result = @ss.send(:compute_decl, "oklch( 0.7 , 0.1max , 240 )")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.7, "0.1max", 240]))
    assert_equal expected, result
  end

  def test_compute_decl_oklch_function_edge_cases
    # Test integer lightness values (should work as floats)
    result = @ss.send(:compute_decl, "oklch(1, 0.1, 0)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [1.0, 0.1, 0.0]))
    assert_equal expected, result

    # Test zero values
    result = @ss.send(:compute_decl, "oklch(0, 0, 0)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.0, 0.0, 0.0]))
    assert_equal expected, result

    # Test decimal-only chroma with max
    result = @ss.send(:compute_decl, "oklch(0.5, .8max, 180)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.5, ".8max", 180.0]))
    assert_equal expected, result

    # Test large hue values (should work)
    result = @ss.send(:compute_decl, "oklch(0.6, 0.1, 359.99)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 38, oklch: [0.6, 0.1, 359.99]))
    assert_equal expected, result

    # Test all role prefixes with relative chroma
    result = @ss.send(:compute_decl, "on_oklch(0.4, 0.3max, 270)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 48, oklch: [0.4, "0.3max", 270.0]))
    assert_equal expected, result

    result = @ss.send(:compute_decl, "over_oklch(0.9, max, 45)")
    expected = Gouache::Layer.from(Gouache::Color.new(role: 58, oklch: [0.9, "max", 45.0]))
    assert_equal expected, result

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

    assert_instance_of Gouache::Layer, result
    assert_equal [effect], result.effects
    assert_equal Gouache::Layer.empty, result
  end

  def test_compute_decl_with_proc_and_sgr_mixed
    effect1 = proc { |top, under| top.bold = true }
    effect2 = proc { |top, under| under.italic = false }

    layer = @ss.send(:compute_decl, [effect1, effect2, 31])
    assert_equal [effect1, effect2], layer.effects
    assert_equal 31, layer[0]  # fg red
  end

  def test_compute_decl_deep_nested_arrays_mixed_types
    effect1 = proc { |top, under| top.bold = true }
    effect2 = proc { |top, under| under.italic = false }
    color1 = Gouache::Color.rgb(255, 0, 0)
    color2 = Gouache::Color.on_rgb(0, 255, 0)

    # Deep nesting: [sgr, [effect, [color, [effect, sgr]], color], sgr]
    nested_array = [
      1,                                    # bold
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

    layer = @ss.send(:compute_decl, nested_array)

    # Check effects are collected
    assert_equal [effect1, effect2], layer.effects

    # Check SGR codes are applied
    assert_equal 1, layer[Gouache::Layer::RANGES[:bold].index]   # bold
    assert_equal 4, layer[Gouache::Layer::RANGES[:underline].index]   # underline
    assert_equal 3, layer[Gouache::Layer::RANGES[:italic].index]   # italic

    # Check colors - red and green fg merge with green as fallback for red
    fg_color = layer[0]
    assert_instance_of Gouache::Color, fg_color
    assert_equal [255, 0, 0], fg_color.rgb  # red rgb
    assert_equal 32, fg_color.basic         # green fallback
    assert_instance_of Gouache::Color, layer[1]  # bg color object
    assert_equal Gouache::Color::BG, layer[1].role
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
