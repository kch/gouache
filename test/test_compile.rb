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
    expected = "\e[22;1mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_content_then_symbol
    result = @go["prefix", :bold, "text"]  # ["prefix", :bold, "text"] structure
    expected = "prefix\e[22;1mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_symbol_content_symbol
    result = @go["prefix", :bold, "text", :red, "more"]  # Mixed content/symbols
    # Should have prefix, then bold section, then red section with incremental close
    expected = "prefix\e[22;1mtext\e[31mmore\e[0m"
    assert_equal expected, result
  end

  def test_compile_multiple_symbols_same_array_nested
    result = @go[:bold, :red, "text"]  # Multiple symbols auto-nest
    # Multiple symbols in same array get nested: [:bold, [:red, "text"]]
    expected = "\e[22;31;1mtext\e[0m"                           # Combined SGR codes with comprehensive reset
    assert_equal expected, result
  end

  def test_compile_nested_arrays
    result = @go[["outer", [:bold, "inner"]]]  # Nested array structure
    expected = "outer\e[22;1minner\e[0m"
    assert_equal expected, result
  end

  def test_compile_deep_nesting
    result = @go[[["deep", [:bold, "text"]]]]  # Deeply nested arrays
    expected = "deep\e[22;1mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_array_at_start
    result = @go[["start"], :bold, "end"] # [["start"], :bold, "end"] structure
    expected = "start\e[22;1mend\e[0m"
    assert_equal expected, result
  end

  def test_compile_array_in_middle
    result = @go["start", ["middle"], :bold, "end"] # Mixed positioning
    expected = "startmiddle\e[22;1mend\e[0m"
    assert_equal expected, result
  end

  def test_compile_array_at_end
    result = @go[:bold, "text", ["end"]]  # [:bold, "text", ["end"]] structure
    expected = "\e[22;1mtextend\e[0m"
    assert_equal expected, result
  end

  def test_compile_symbol_chain_nesting
    result = @go[:bold, :red, :italic, "text"]  # Symbol chain structure
    # Should nest as [:bold, [:red, [:italic, "text"]]]
    expected = "\e[22;31;3;1mtext\e[0m"                                   # All styles combined into one SGR
    assert_equal expected, result
  end

  def test_compile_mixed_content_types
    result = @go[123, :bold, 456, :red, "text"]  # Mixed types via to_s conversion
    expected = "123\e[22;1m456\e[31mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_nil_values_converted
    result = @go[nil, :bold, nil, "text"]  # Nil handling
    expected = "\e[22;1mtext\e[0m"
    assert_equal expected, result
  end

  def test_compile_boolean_values
    result = @go[true, :bold, false, "text"]  # Boolean to_s conversion
    expected = "true\e[22;1mfalsetext\e[0m"
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
    expected = "start\e[22;1mbold text\e[31mred and bold\e[39mmore bold\e[22mmiddle\e[3mjust italic\e[23mplain in nested\e[4munderlined end\e[0m"
    assert_equal expected, result
  end

  def test_compile_deeply_nested_arrays
    structure = [[[[[[:bold, "deep"]]]]], "surface"]  # 6-level deep nesting
    result = @go[*structure]
    expected = "\e[22;1mdeep\e[22msurface\e[0m"      # Deep nesting flattened, incremental close, final reset
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

    expected = "\e[22;1mone\e[31mtwo\e[3mthree\e[0m"
    assert_equal expected, result
  end

  def test_instance_bracket_method_basic
    result = @go[:bold, "text"]           # [] method shorthand for compile
    expected = "\e[22;1mtext\e[0m"
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
    expected = "prefix\e[22;1mtext\e[31mend\e[0m"
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

    expected = "start\e[22;1mbold text\e[31mred and bold\e[39mmore bold\e[22mmiddle\e[3;4mnested textend\e[0m"
    assert_equal expected, result
  end

end
