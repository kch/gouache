# frozen_string_literal: true

require_relative "test_helper"

class TestCompile < Minitest::Test
  def setup
    super
    @go = Gouache.new
  end

  def test_compile_empty_array
    result = @go[]  # Empty array should produce no output
    assert_equal "", result
  end

  def test_compile_simple_string
    result = @go["hello"]  # Plain strings pass through unchanged
    assert_equal "hello", result
  end

  def test_compile_multiple_strings
    result = @go["hello", " ", "world"]  # Multiple strings concatenated
    assert_equal "hello world", result
  end

  def test_compile_single_symbol_no_content
    result = @go[:bold]  # Symbol without content
    assert_equal "", result                       # Empty tags produce no output (optimization)
  end

  def test_compile_symbol_with_content
    result = @go[:bold, "text"]  # [:bold, "text"] structure
    expected = "\e[1mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_content_then_symbol
    result = @go["prefix", :bold, "text"]  # ["prefix", :bold, "text"] structure
    expected = "prefix\e[1mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_symbol_content_symbol
    result = @go["prefix", :bold, "text", :red, "more"]  # Mixed content/symbols
    # Should have prefix, then bold section, then red section with incremental close
    expected = "prefix\e[1mtext\e[31mmore\e[0m"
    assert_equal expected, result
  end

  def test_compile_multiple_symbols_same_array_nested
    result = @go[:bold, :red, "text"]  # Multiple symbols auto-nest
    # Multiple symbols in same array get nested: [:bold, [:red, "text"]]
    expected = "\e[31;1mtext\e[0m"                           # Combined SGR codes
    assert_equal expected, result
  end

  def test_compile_nested_arrays
    result = @go[["outer", [:bold, "inner"]]]  # Nested array structure
    expected = "outer\e[1minner\e[0m"
    assert_equal expected, result
  end

  def test_compile_deep_nesting
    result = @go[[["deep", [:bold, "text"]]]]  # Deeply nested arrays
    expected = "deep\e[1mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_array_at_start
    result = @go[["start"], :bold, "end"] # [["start"], :bold, "end"] structure
    expected = "start\e[1mend\e[0m"
    assert_equal expected, result
  end

  def test_compile_array_in_middle
    result = @go["start", ["middle"], :bold, "end"] # Mixed positioning
    expected = "startmiddle\e[1mend\e[0m"
    assert_equal expected, result
  end

  def test_compile_array_at_end
    result = @go[:bold, "text", ["end"]]  # [:bold, "text", ["end"]] structure
    expected = "\e[1mtextend\e[0m"
    assert_equal expected, result
  end

  def test_compile_symbol_chain_nesting
    result = @go[:bold, :red, :italic, "text"]  # Symbol chain structure
    # Should nest as [:bold, [:red, [:italic, "text"]]]
    expected = "\e[31;3;1mtext\e[0m"                                   # All styles combined into one SGR
    assert_equal expected, result
  end

  def test_compile_mixed_content_types
    result = @go[123, :bold, 456, :red, "text"]  # Mixed types via to_s conversion
    expected = "123\e[1m456\e[31mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_nil_values_converted
    result = @go[nil, :bold, nil, "text"]  # Nil handling
    expected = "\e[1mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_boolean_values
    result = @go[true, :bold, false, "text"]  # Boolean to_s conversion
    expected = "true\e[1mfalsetext\e[0m"
    assert_equal expected, result
  end

  def test_compile_with_custom_styles
    go = Gouache.new(custom: 33)
    result = go[:custom, "text"]
    expected = "\e[33mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_object_to_s_failure
    obj = Object.new                  # Object that raises on to_s
    def obj.to_s
      raise "Cannot convert"
    end

    assert_raises(RuntimeError) {     # Should propagate to_s exceptions
      @go[obj]
    }
  end

  def test_compile_complex_nested_structure
    structure = [                     # Complex mixed structure
      "start",                        # Plain string
      [:bold,                         # Bold section with nested content
        "bold text",
        [:red, "red and bold"],       # Nested red within bold
        "more bold"
      ],
      "middle",                       # Plain string
      [                               # Array section
        [:italic, "just italic"],     # Styled content in array
        "plain in nested"
      ],
      :underline,                     # Final symbol
      "underlined end"
    ]

    result = @go[*structure]
    expected = "start\e[1mbold text\e[31mred and bold\e[39mmore bold\e[22mmiddle\e[3mjust italic\e[23mplain in nested\e[4munderlined end\e[0m"
    assert_equal expected, result
  end

  def test_compile_deeply_nested_arrays
    structure = [[[[[[:bold, "deep"]]]]], "surface"]  # 6-level deep nesting
    result = @go[*structure]
    expected = "\e[1mdeep\e[22msurface\e[0m"      # Deep nesting flattened, incremental close, final reset
    assert_equal expected, result
  end

  def test_compile_empty_nested_arrays
    result = @go[[], [[]], [[[]]]]  # Nested empty arrays
    assert_equal "", result                                  # Should produce no output
  end

  def test_compile_symbol_with_nested_empty_arrays
    result = @go[:bold, []]  # Symbol with empty array content
    assert_equal "", result                           # No content = no output (optimization)
  end

  def test_compile_alternating_symbols_content
    result = @go[            # Alternating pattern: symbol, content, symbol, content...
      :bold, "one",                   # Each symbol applies to following content
      :red, "two",
      :italic, "three"
    ]

    expected = "\e[1mone\e[31mtwo\e[3mthree\e[0m"
    assert_equal expected, result
  end

  def test_instance_bracket_method_basic
    result = @go[:bold, "text"]           # [] method shorthand for compile
    expected = "\e[1mtext\e[0m"
    assert_equal expected, result
  end

  def test_instance_bracket_method_with_keyword_styles
    go = Gouache.new(custom: 33)
    result = go[:custom, "text"]
    expected = "\e[33mtext\e[0m"
    assert_equal expected, result
  end

  def test_instance_bracket_method_multiple_keywords
    go = Gouache.new(a: 35, b: 36)
    result = go[:a, :b, "text"]
    # Should nest as [:a, [:b, "text"]] with both custom styles
    expected = "\e[36mtext\e[0m"
    assert_equal expected, result
  end

  def test_instance_bracket_method_basic_styles
    go = Gouache.new(custom_red: 31, custom_blue: 34)
    result = go[:custom_red, "red ", :custom_blue, "blue"]
    expected = "\e[31mred \e[34mblue\e[0m"
    assert_equal expected, result
  end

  def test_instance_styles_override
    go = Gouache.new(red: 91)
    result = go[:red, "text"]
    expected = "\e[91mtext\e[0m"
    assert_equal expected, result
  end

  def test_bracket_method_mixed_styles
    go = Gouache.new(custom_bold: 1, custom_red: 31)
    result = go["prefix", :custom_bold, "text", :custom_red, "end"]
    expected = "prefix\e[1mtext\e[31mend\e[0m"
    assert_equal expected, result
  end

  def test_bracket_method_empty_array
    result = @go[]
    assert_equal "", result
  end

  def test_bracket_method_empty_with_styles
    go = Gouache.new(custom: 33)
    result = go[:custom]
    assert_equal "", result
  end

  def test_bracket_method_complex_nested_structure
    result = @go[                         # Complex nested structure with [] method
      "start",                            # Plain text
      [:bold,                             # Bold section
        "bold text",
        [:red, "red and bold"],           # Nested red within bold
        "more bold"
      ],
      "middle",                           # Plain text
      :italic, :underline, "nested text", # Implicit nesting: [:italic, [:underline, "nested text"]]
      "end"
    ]

    expected = "start\e[1mbold text\e[31mred and bold\e[39mmore bold\e[22mmiddle\e[3;4mnested textend\e[0m"
    assert_equal expected, result
  end

  def test_compile_inline_color_objects
    # Test inline Color objects in compile arrays
    c = Gouache::Color
    result = @go[c.sgr(31), "red", [:green, "asdf"], "asdf", c.sgr(44), "asdf"]
    expected = "\e[31mred\e[32masdf\e[31masdf\e[44masdf\e[0m"
    assert_equal expected, result
  end

  def test_compile_mixed_color_objects_and_symbols
    # Test mixing Color objects with symbol tags
    c = Gouache::Color
    result = @go["start", c.sgr(33), "yellow", :bold, "bold", c.sgr(42), "background"]
    expected = "start\e[33myellow\e[1mbold\e[42mbackground\e[0m"
    assert_equal expected, result
  end

  def test_compile_color_objects_in_nested_arrays
    # Test Color objects within nested array structures
    c = Gouache::Color
    result = @go[["prefix", c.sgr(35), "magenta"], [:italic, c.sgr(41), "nested"]]
    expected = "prefix\e[35mmagenta\e[39;41;3mnested\e[0m"
    assert_equal expected, result
  end

  def test_compile_complex_color_objects
    # Test complex SGR Color objects (256-color, truecolor)
    c = Gouache::Color
    result = @go[c.sgr("38;5;196"), "256-color", c.sgr("48;2;0;255;0"), "truecolor-bg"]
    expected = "\e[38;5;196m256-color\e[48;2;0;255;0mtruecolor-bg\e[0m"
    assert_equal expected, result
  end

  def test_compile_color_objects_with_basic_fallback
    # Test Color objects with Term.color_level set to basic
    Gouache::Term.color_level = :basic
    c = Gouache::Color
    rgb_red = c.rgb(255, 0, 0)  # Should fallback to bright red (91)
    rgb_blue = c.rgb(0, 0, 255)  # Should fallback to basic blue (34)
    result = @go[rgb_red, "red text", rgb_blue, "blue text"]
    expected = "\e[91mred text\e[34mblue text\e[0m"
    assert_equal expected, result
  end

  def test_compile_truecolor_with_basic_fallback
    # Test truecolor SGR with basic fallback
    Gouache::Term.color_level = :basic
    c = Gouache::Color
    truecolor = c.sgr("38;2;255;128;64")  # Orange, should fallback to bright red (91)
    result = @go["start", truecolor, "orange text", :bold, "bold"]
    # Should use basic color fallback, not the full truecolor sequence
    assert result.include?("\e[91m"), "Should contain basic bright red fallback"
    refute result.include?("38;2;"), "Should not contain truecolor sequence"
  end

  def test_compile_mixed_fallback_levels
    # Test mixing different color types with basic fallback
    Gouache::Term.color_level = :basic
    c = Gouache::Color
    result = @go[
      c.rgb(255, 0, 0), "red",     # RGB should fallback to basic
      c.sgr("38;5;196"), "256",    # 256-color should fallback to basic
      c.sgr(32), "basic",          # Basic should stay as basic
      c.sgr("48;2;0;255;0"), "bg"  # RGB background should fallback to basic
    ]
    # All should use basic color codes, no complex sequences
    refute result.include?("38;2;"), "Should not contain truecolor"
    refute result.include?("38;5;"), "Should not contain 256-color"
    refute result.include?("48;2;"), "Should not contain truecolor background"
  end

end
