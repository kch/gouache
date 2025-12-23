# frozen_string_literal: true

require_relative "test_helper"

class TestStylesheet < Minitest::Test
  def setup
    @ss = Gouache::Stylesheet::BASE

    # Stub color_level to truecolor for consistent test behavior
    Gouache::Term.singleton_class.alias_method :color_level_original, :color_level
    Gouache::Term.singleton_class.undef_method :color_level
    Gouache::Term.singleton_class.define_method(:color_level) { :truecolor }
  end

  def teardown
    # Restore original method
    Gouache::Term.singleton_class.undef_method :color_level
    Gouache::Term.singleton_class.alias_method :color_level, :color_level_original
    Gouache::Term.singleton_class.undef_method :color_level_original
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
    assert @ss.key?(:red)
    assert @ss.key?("red")
    assert @ss.key?(:bold)
    assert @ss.key?("bold")

    # Should not find non-existent selectors
    refute @ss.key?(:nonexistent)
    refute @ss.key?("nonexistent")

    # Should convert to symbol
    ss = Gouache::Stylesheet.new({custom: 31}, base: nil)
    assert ss.key?(:custom)
    assert ss.key?("custom")
  end

  def test_key_method_with_unconvertible_types
    # Should handle types that can't convert to symbol
    assert_raises { @ss.key?(123) }
    assert_raises { @ss.key?([]) }
    assert_raises { @ss.key?({}) }
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
      w: ["blink", :underline, :l, "on#123"]
    }

    ss = Gouache::Stylesheet.new(styles, base: nil)

    # All should resolve to layers
    styles.each_key do |key|
      assert_kind_of Gouache::Layer, ss.layer_map[key], "#{key} should be Layer"
    end

    # Test specific SGR values for key patterns
    assert_equal Gouache::Layer.from("38;2;252;0;0"), ss.layer_map[:red]  # #fc0000
    assert_equal Gouache::Layer.from(1), ss.layer_map[:a]                 # bold
    assert_equal ss.layer_map[:a], ss.layer_map[:b]                           # b->a chain
    assert_equal Gouache::Layer.empty, ss.layer_map[:d]                   # nil
    assert_equal Gouache::Layer.from(31, 4), ss.layer_map[:g]             # "31;4"
    assert_equal Gouache::Layer.from("38;2;1;2;233"), ss.layer_map[:k]    # rgb(1,2,233)
    assert_equal Gouache::Layer.from("38;5;255"), ss.layer_map[:l]        # gray(23) = 232+23
    assert_equal Gouache::Layer.from("38;5;123"), ss.layer_map[:n]        # 256(123)
    assert_equal Gouache::Layer.from("48;2;1;2;3"), ss.layer_map[:o]      # on_rgb(1,2,3)
    assert_equal Gouache::Layer.from("38;5;67"), ss.layer_map[:s]         # #123 = 1*36+2*6+3+16
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

      # 256-color variants
      color256_1:     "256(0)",
      color256_2:     "256(255)",
      color256_bg1:   "on_256(0)",
      color256_bg2:   "on_256(255)",

      # Grayscale variants
      gray1:          "gray(0)",
      gray2:          "gray(23)",
      gray_bg1:       "on_gray(0)",
      gray_bg2:       "on_gray(23)",

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
    }

    ss = Gouache::Stylesheet.new(styles, base: nil)

    # All color functions should produce non-empty layers
    styles.each_key do |key|
      assert_kind_of Gouache::Layer, ss.layer_map[key]
      refute_equal Gouache::Layer.empty, ss.layer_map[key], "#{key} should not be empty"
    end

    # Test specific SGR values
    assert_equal Gouache::Layer.from("38;2;0;0;0"), ss.layer_map[:rgb1]          # rgb(0,0,0)
    assert_equal Gouache::Layer.from("38;2;255;255;255"), ss.layer_map[:rgb2]    # rgb(255,255,255)
    assert_equal Gouache::Layer.from("48;2;128;64;32"), ss.layer_map[:rgb_bg1]   # on_rgb(128,64,32)
    assert_equal Gouache::Layer.from("48;2;255;0;128"), ss.layer_map[:rgb_bg2]   # on_rgb(255,0,128)

    assert_equal Gouache::Layer.from("38;5;0"), ss.layer_map[:color256_1]        # 256(0)
    assert_equal Gouache::Layer.from("38;5;255"), ss.layer_map[:color256_2]      # 256(255)
    assert_equal Gouache::Layer.from("48;5;0"), ss.layer_map[:color256_bg1]      # on_256(0)
    assert_equal Gouache::Layer.from("48;5;255"), ss.layer_map[:color256_bg2]    # on_256(255)

    assert_equal Gouache::Layer.from("38;5;232"), ss.layer_map[:gray1]           # gray(0) = 232+0
    assert_equal Gouache::Layer.from("38;5;255"), ss.layer_map[:gray2]           # gray(23) = 232+23
    assert_equal Gouache::Layer.from("48;5;232"), ss.layer_map[:gray_bg1]        # on_gray(0) = 232+0
    assert_equal Gouache::Layer.from("48;5;255"), ss.layer_map[:gray_bg2]        # on_gray(23) = 232+23

    assert_equal Gouache::Layer.from("38;5;16"), ss.layer_map[:hex3_1]           # #000 = 0*36+0*6+0+16
    assert_equal Gouache::Layer.from("38;5;231"), ss.layer_map[:hex3_2]          # #555 = 5*36+5*6+5+16
    assert_equal Gouache::Layer.from("38;2;0;0;0"), ss.layer_map[:hex6_1]        # #000000
    assert_equal Gouache::Layer.from("38;2;255;255;255"), ss.layer_map[:hex6_2]  # #ffffff
    assert_equal Gouache::Layer.from("38;2;171;205;239"), ss.layer_map[:hex6_3]  # #abcdef
    assert_equal Gouache::Layer.from("48;5;67"), ss.layer_map[:hex_bg3_1]        # on#123 = 1*36+2*6+3+16
    assert_equal Gouache::Layer.from("48;5;189"), ss.layer_map[:hex_bg3_2]       # on#445 = 4*36+4*6+5+16
    assert_equal Gouache::Layer.from("48;2;0;0;0"), ss.layer_map[:hex_bg6_1]     # on#000000
    assert_equal Gouache::Layer.from("48;2;255;255;255"), ss.layer_map[:hex_bg6_2] # on#ffffff
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
end
