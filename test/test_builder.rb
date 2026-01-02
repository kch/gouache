# frozen_string_literal: true

require_relative "test_helper"

class TestBuilder < Minitest::Test
  @@called_tags = []

  def setup
    super
    @gouache = Gouache.new
    @@called_tags.clear

    # Set up tag tracking
    MethodHelpers.replace_method(Gouache::Emitter, :open_tag) do |tag|
      @@called_tags << tag
      open_tag_original(tag)
    end
  end

  def teardown
    # Restore original method
    MethodHelpers.restore_method(Gouache::Emitter, :open_tag)
    super
  end

  def test_simple_method_call_returns_string
    result = @gouache.red("foo")
    assert_equal "\e[31mfoo\e[0m", result
  end

  def test_chaining_level_1
    result = @gouache.red.bold("foo")
    assert_equal "\e[31;1mfoo\e[0m", result
  end

  def test_chaining_level_2
    result = @gouache.red.bold.underline("foo")
    assert_equal "\e[31;4;1mfoo\e[0m", result
  end

  def test_chaining_level_3
    result = @gouache.red.bold.underline.italic("foo")
    assert_equal "\e[31;3;4;1mfoo\e[0m", result
  end

  def test_block_with_it_parameter
    result = @gouache.red{ it.strike("content") }
    assert_equal "\e[31;9mcontent\e[0m", result
  end

  def test_block_with_named_parameter
    result = @gouache.red{|x| x.strike("content") }
    assert_equal "\e[31;9mcontent\e[0m", result
  end

  def test_block_with_implicit_self
    result = @gouache.red{ strike("content") }
    assert_equal "\e[31;9mcontent\e[0m", result
  end

  def test_nonexistent_method_from_instance
    assert_raises(NoMethodError) do
      @gouache.fake
    end
  end

  def test_chaining_with_nonexistent_method
    result = @gouache.red.fake.underline("foo"){ blue("nested") }
    assert_equal "\e[31;4mfoo\e[34mnested\e[0m", result
  end

  def test_nested_blocks_with_mixed_usage
    result = @gouache.red.bold {|x|
      x.invert.italic.blue("wow")
      x.magenta{ strike.dim("dim_strike"); x.green("green_text") }
      x.yellow("yellow_text")
      x << "plain_red_text"
    }

    expected = "\e[34;3;7;1mwow" +
               "\e[35;23;27;9;2mdim_strike" +
               "\e[22;32;29;1mgreen_text" +
               "\e[33myellow_text" +
               "\e[31mplain_red_text" +
               "\e[0m"
    assert_equal expected, result
  end

  def test_special_method_call_creates_tag
    result = @gouache.call{ red("content") }
    assert_equal "\e[31mcontent\e[0m", result
  end

  def test_special_method_names_create_tags
    @gouache.red.bold {|x|
      x.call("call_content")
      x.initialize("init_content")
      x.method_missing("missing_content")
      x._build!("build_content")
    }

    assert_equal [:red, :bold, :call, :initialize, :method_missing, :_build!], @@called_tags
  end

  def test_appending_to_unfinished_chain
    result = @gouache.red {|x|
      x.underline << "appended_text"
    }
    assert_equal "\e[31;4mappended_text\e[0m", result
  end

  def test_unfinished_chain_single_method
    assert_raises(Gouache::Builder::UnfinishedChainError) do
      @gouache.red.bold {|x|
        x.underline.underline.underline
      }
    end
  end

  def test_unfinished_chain_with_content_before
    assert_raises(Gouache::Builder::UnfinishedChainError) do
      @gouache.red.bold {|x|
        x.bar("content")
        x.underline
      }
    end
  end

  def test_unfinished_chain_with_content_after
    assert_raises(Gouache::Builder::UnfinishedChainError) do
      @gouache.red {|x|
        x.underline
        x.bar("content")
      }
    end
  end

  def test_call_without_block_raises_error
    assert_raises(ArgumentError) do
      @gouache.()
    end
  end

  def test_call_with_block_only
    result = @gouache.(){|x| x.red("content") }
    assert_equal "\e[31mcontent\e[0m", result
  end

  def test_call_with_string_and_block
    result = @gouache.("direct_text"){|x| x.blue("blue_text") }
    expected = "direct_text" +
               "\e[34mblue_text" +
               "\e[0m"
    assert_equal expected, result
  end

  def test_call_with_string_and_append_in_block
    result = @gouache.("direct_text"){|x| x << "appended_text" }
    assert_equal "direct_textappended_text", result
  end

  def test_call_with_nested_calls
    result = @gouache.(){|x|
      x.red("red_content")
      x.("nested_call_text")
    }
    expected = "\e[31mred_content" +
               "\e[0mnested_call_text"
    assert_equal expected, result
  end

  def test_deep_nesting_5_levels
    result = @gouache.red.bold{ |a|
      a.blue { |b|
        b.green { |c|
          c.yellow { |d|
            d.magenta { |e|
              e.cyan("deep_nested_content")
            }
            d.white("level_4_content")
          }
        }
      }
      a.underline("level_1_content")
    }

    expected = "\e[36;1mdeep_nested_content" +
               "\e[37mlevel_4_content" +
               "\e[31;4mlevel_1_content" +
               "\e[0m"
    assert_equal expected, result
    assert_equal [:red, :bold, :blue, :green, :yellow, :magenta, :cyan, :white, :underline], @@called_tags
  end

  def test_mixed_content_and_nesting
    result = @gouache.red.bold {|x|
      x.green("green_text")
      x.blue {
        yellow("yellow_in_blue")
        italic("italic_in_blue")
      }
      x << "plain_text_in_red_bold"
    }

    expected = "\e[32;1mgreen_text" +
               "\e[33myellow_in_blue" +
               "\e[34;3mitalic_in_blue" +
               "\e[31;23mplain_text_in_red_bold" +
               "\e[0m"
    assert_equal expected, result
  end

  def test_chain_to_s_raises_no_method_error
    assert_raises(NoMethodError) do
      @gouache.red.to_s
    end
  end

  def test_standalone_unfinished_chain
    chain = @gouache.red
    assert_kind_of Gouache::Builder::ChainProxy, chain
    # UnfinishedChainError is only raised when the chain is left dangling in a block context
  end

  def test_call_with_string_only_raises_error
    assert_raises(ArgumentError) do
      @gouache.("asdf")
    end
  end

  def test_complex_mixed_nesting_pattern
    result = @gouache.red.bold{ |a|
      a.green { |b|
        b.yellow { |c|
          c.blue { |d|
            d.magenta("nested_content")
          }
        }
      }
      a.cyan("level_1_content")
    }

    expected = "\e[35;1mnested_content" +
               "\e[36mlevel_1_content" +
               "\e[0m"
    assert_equal expected, result
    assert_equal [:red, :bold, :green, :yellow, :blue, :magenta, :cyan], @@called_tags
  end

  def test_chain_proxy_leak_prevention_to_s
    assert_raises(NoMethodError) do
      @gouache.red.to_s
    end
  end

  def test_chain_proxy_leak_prevention_to_str
    assert_raises(NoMethodError) do
      @gouache.red.to_str
    end
  end

  def test_chain_proxy_leak_prevention_to_ary
    assert_raises(NoMethodError) do
      @gouache.red.to_ary
    end
  end

  def test_builder_proxy_leak_prevention_to_s
    # Need to manually instantiate proxy to test this
    proxy = Gouache::Builder::Proxy.new(@gouache)
    assert_raises(NoMethodError) do
      proxy.to_s
    end
  end

  def test_builder_proxy_leak_prevention_to_str
    proxy = Gouache::Builder::Proxy.new(@gouache)
    assert_raises(NoMethodError) do
      proxy.to_str
    end
  end

  def test_builder_proxy_leak_prevention_to_ary
    proxy = Gouache::Builder::Proxy.new(@gouache)
    assert_raises(NoMethodError) do
      proxy.to_ary
    end
  end

  def test_builder_methods_return_nil_inside_block
    result = @gouache.red {|x|
      ret4 = :foo
      ret1 = x.blue("content")
      ret2 = x.green {}
      ret3 = x.yellow { ret4 = strike("nested") }

      assert_nil ret1
      assert_nil ret2
      assert_nil ret3
      assert_nil ret4

      x << "final_content"
    }

    # Only the top-level should return the emitted string
    assert_equal "\e[34mcontent\e[33;9mnested\e[31;29mfinal_content\e[0m", result
  end

  def test_builder_method_with_simple_array
    # Basic array of strings passed to builder method
    result = @gouache.red(["hello", "world"])
    assert_equal "\e[31mhelloworld\e[0m", result
  end

  def test_builder_method_with_array_containing_symbols
    # Array with symbol tags should nest properly within builder method context
    result = @gouache.red([:bold, "text"])
    assert_equal "\e[31;1mtext\e[0m", result
  end

  def test_builder_method_with_nested_arrays
    # Deeply nested array structures should flatten and compile correctly
    result = @gouache.red([["nested", [:bold, "text"]]])
    assert_equal "\e[31mnested\e[1mtext\e[0m", result
  end

  def test_builder_method_mixed_string_and_array
    # Builder methods should accept mixed string and array arguments
    result = @gouache.red("prefix", [:bold, "bold"])
    assert_equal "\e[31mprefix\e[1mbold\e[0m", result
  end

  def test_builder_method_with_chained_arrays
    # Chained builder methods should handle arrays with proper style combination
    result = @gouache.red.bold([:italic, "text"])
    assert_equal "\e[31;3;1mtext\e[0m", result
  end

  def test_builder_method_with_complex_nested_array
    # Complex array: strings, symbols, nested arrays with multiple style changes
    array = ["start", [:bold, "bold"], "middle", [:red, [:italic, "nested"]], "end"]
    result = @gouache.green(array)
    assert_equal "\e[32mstart\e[1mbold\e[22mmiddle\e[31;3mnested\e[32;23mend\e[0m", result
  end

  def test_builder_method_with_deeply_nested_arrays
    # 4-level deep array nesting should flatten and compile correctly
    array = [[[[:bold, "deep"]]]]
    result = @gouache.red(array)
    assert_equal "\e[31;1mdeep\e[0m", result
  end

  def test_builder_method_with_multiple_arrays
    # Multiple separate array arguments should be processed sequentially
    result = @gouache.blue(["first", "part"], [:bold, "second"], ["third"])
    assert_equal "\e[34mfirstpart\e[1msecond\e[22mthird\e[0m", result
  end

  def test_builder_method_with_empty_arrays
    # Empty arrays should be ignored, only actual content should render
    result = @gouache.red([], "content", [[]], [:bold, []])
    assert_equal "\e[31mcontent\e[0m", result
  end

  def test_builder_method_with_array_in_block
    # Arrays passed to builder methods within block context
    result = @gouache.red {|x|
      x.blue([:bold, "nested"])     # Array with symbol in nested method call
      x << "plain"                  # Plain append for comparison
    }
    assert_equal "\e[34;1mnested\e[22;31mplain\e[0m", result
  end

  def test_builder_method_with_alternating_symbols_in_array
    # Array with alternating symbols and content: symbol applies to following content
    array = [:bold, "one", :italic, "two", :underline, "three"]
    result = @gouache.red(array)
    assert_equal "\e[31;1mone\e[3mtwo\e[4mthree\e[0m", result
  end

  def test_builder_method_with_mixed_types_in_array
    # Array with various types: numbers, symbols, nil, booleans, strings
    array = [123, :bold, nil, true, "text"]  # nil should be filtered out
    result = @gouache.green(array)
    assert_equal "\e[32m123\e[1mtruetext\e[0m", result
  end

  def test_builder_method_array_vs_direct_compilation
    # Builder method with array should match direct bracket compilation
    array = [:bold, "text", :red, "more"]     # Same array structure
    builder_result = @gouache.green(array)    # Via builder method
    direct_result = @gouache[:green, array]   # Via direct compilation
    assert_equal direct_result, builder_result
    assert_equal "\e[32;1mtext\e[31mmore\e[0m", builder_result
  end

  def test_builder_method_with_nested_builder_calls_in_array
    # Array containing pre-compiled styled strings should handle SGR sequences
    nested_content = @gouache[:italic, "italic_text"]  # Pre-compiled with escape codes
    array = ["prefix", nested_content, "suffix"]       # Mixed with plain strings
    result = @gouache.red(array)
    expected = "\e[31mprefix\e[3mitalic_text\e[23msuffix\e[0m"
    assert_equal expected, result
  end

  def test_builder_chaining_with_array_and_block
    # Chained builder with both array argument and block
    result = @gouache.red.bold([:italic, "array_content"]) {|x|  # Array in chained call
      x.underline("block_content")                               # Block adds more content
    }
    expected = "\e[31;3;1marray_content\e[23;4mblock_content\e[0m"
    assert_equal expected, result
  end

  def test_builder_method_with_symbol_chain_array
    # Array with multiple consecutive symbols should auto-nest: [:bold, [:italic, [:underline, "text"]]]
    array = [:bold, :italic, :underline, "chained_styles"]
    result = @gouache.red(array)
    assert_equal "\e[31;3;4;1mchained_styles\e[0m", result
  end

  def test_builder_method_with_array_in_nested_blocks
    # Arrays in deeply nested block contexts with multiple style changes
    result = @gouache.red {|x|
      x.blue([:bold, "blue_bold"])               # Array with symbol in 2nd level
      x.green {|y|                               # 3rd nesting level
        y.yellow([:italic, "yellow_italic"])     # Array with symbol in 4th level
        y.magenta(["plain", :underline, "underlined"])  # Mixed array content
      }
    }
    expected = "\e[34;1mblue_bold\e[22;33;3myellow_italic\e[35;23mplain\e[4munderlined\e[0m"
    assert_equal expected, result
  end

  def test_builder_method_with_complex_array_in_block
    # Complex array structure: strings, symbols, nested arrays within block context
    result = @gouache.red {|x|
      array = ["start", [:bold, "bold_part"], :italic, "italic_part", ["nested", [:underline, "under"]]]
      x.blue(array)                             # Pass entire complex array to method
      x << "final"                              # Append plain content
    }
    expected = "\e[34mstart\e[1mbold_part\e[22;3mitalic_partnested\e[4munder\e[31;23;24mfinal\e[0m"
    assert_equal expected, result
  end

  def test_builder_method_with_array_containing_block_results
    # Array containing pre-built styled content from other builder calls
    inner = @gouache.red {|x| x.bold("inner") }         # Pre-built content with escape codes
    array = ["prefix", inner, "suffix"]                 # Mix with plain strings
    result = @gouache.green(array)
    expected = "\e[32mprefix\e[31;1minner\e[22;32msuffix\e[0m"
    assert_equal expected, result
  end

  def test_builder_method_array_with_chained_methods_in_block
    # Chained builder methods with array argument within block context
    result = @gouache.red {|x|
      x.blue.bold([:italic, "chained_with_array"])  # Chain + array in block
    }
    expected = "\e[34;3;1mchained_with_array\e[0m"
    assert_equal expected, result
  end

  def test_builder_method_multiple_arrays_in_block
    # Multiple method calls with different array structures in same block
    result = @gouache.red {|x|
      x.blue(["first"], [:bold, "second"])      # Multiple arrays to same call
      x.green([[:italic, "third"]], "fourth")   # Nested array + string
    }
    expected = "\e[34mfirst\e[1msecond\e[22;32;3mthird\e[23mfourth\e[0m"
    assert_equal expected, result
  end

  def test_builder_method_array_and_append_in_block
    # Mix of builder method calls with arrays and direct append operator
    result = @gouache.red {|x|
      x.blue([:bold, "from_array"])                         # Method call with array
      x << ["appended_array", :italic, "italic_appended"]   # Append operator now handles arrays properly
    }
    expected = "\e[34;1mfrom_array\e[22;31mappended_array\e[3mitalic_appended\e[0m"
    assert_equal expected, result
  end

  def test_builder_method_deep_nesting_with_arrays
    # Deep block nesting (3 levels) with arrays at different levels
    result = @gouache.red {|a|                              # Level 1: red context
      a.blue {|b|                                           # Level 2: blue context
        b.green([:bold, "deep_bold"])                       # Array in level 3 method
        b.yellow {|c|                                       # Level 3: yellow context
          c.magenta([[:italic, "very_deep"], "plain"])      # Complex nested array
        }
      }
    }
    expected = "\e[32;1mdeep_bold\e[22;35;3mvery_deep\e[23mplain\e[0m"
    assert_equal expected, result
  end

  def test_append_operator_with_simple_array
    # Append operator should handle simple arrays like method calls
    result = @gouache.red {|x|
      x << ["hello", "world"]
    }
    expected = "\e[31mhelloworld\e[0m"
    assert_equal expected, result
  end

  def test_append_operator_with_nested_arrays_and_symbols
    # Append operator should compile complex nested array structures
    result = @gouache.blue {|x|
      x << [[:bold, "bold"], " ", [:italic, "italic"]]
    }
    expected = "\e[34;1mbold\e[22m \e[3mitalic\e[0m"
    assert_equal expected, result
  end

  def test_bracket_method_with_block_only
    # [] method with block only should work like call()
    result = @gouache[] {|x| x.red("content") }
    assert_equal "\e[31mcontent\e[0m", result
  end

  def test_bracket_method_with_text_and_block
    # [] method with text and block should combine both
    result = @gouache["prefix"] {|x| x.blue("block_content") }
    expected = "prefix\e[34mblock_content\e[0m"
    assert_equal expected, result
  end

  def test_bracket_method_with_multiple_args_and_block
    # [] method with multiple arguments and block
    result = @gouache["start", :bold, "bold_part"] {|x|
      x.red("red_content")
      x << " suffix"
    }
    expected = "start\e[1mbold_part\e[22;31mred_content\e[0m suffix"
    assert_equal expected, result
  end

  def test_bracket_method_with_array_args_and_block
    # [] method with array arguments and block
    result = @gouache[[:italic, "italic_part"], "middle"] {|x|
      x.underline("underlined")
    }
    expected = "\e[3mitalic_part\e[0mmiddle\e[4munderlined\e[0m"
    assert_equal expected, result
  end

  def test_bracket_method_with_empty_args_and_block
    # [] method with empty args and block
    result = @gouache[] {|x|
      x.green("green_text")
      x.bold("bold_text")
    }
    expected = "\e[32mgreen_text\e[39;1mbold_text\e[0m"
    assert_equal expected, result
  end

  def test_bracket_method_block_vs_call_consistency
    # [] method with block should match call() behavior
    content_args = ["prefix", :red, "RED_TEXT"]

    bracket_result = @gouache[*content_args] {|x| x.bold("bold_block") }
    call_result = @gouache.call(content_args) {|x| x.bold("bold_block") }

    assert_equal call_result, bracket_result
    # Verify symbols are processed as styling, not literal text
    assert_includes bracket_result, "\e[31m"  # Contains red styling
    refute_includes bracket_result, "red"  # Not literal ":red" symbol
  end

  def test_bracket_method_nested_blocks
    # [] method with nested blocks
    result = @gouache["outer"] {|a|
      a.red {|b|
        b.bold("nested_content")
      }
      a << " final"
    }
    expected = "outer\e[31;1mnested_content\e[0m final"
    assert_equal expected, result
  end

  def test_bracket_method_with_symbol_args_and_block
    # [] method with symbol styling and block
    result = @gouache[:italic, "styled_start"] {|x|
      x.red("block_red")
      x.underline("block_underline")
    }
    expected = "\e[3mstyled_start\e[31;23mblock_red\e[39;4mblock_underline\e[0m"
    assert_equal expected, result
  end

  def test_bracket_method_block_with_chaining
    # [] method block with method chaining inside
    result = @gouache["prefix"] {|x|
      x.red.bold("chained_method")
    }
    expected = "prefix\e[31;1mchained_method\e[0m"
    assert_equal expected, result
  end

  def test_bracket_method_without_block_still_works
    # [] without block should still work normally
    result = @gouache[:red, "no_block"]
    assert_equal "\e[31mno_block\e[0m", result
  end

  def test_call_with_multi_parameter_block_raises_error
    # Blocks with more than 1 parameter should raise ArgumentError
    assert_raises(ArgumentError) do
      @gouache.call { |a, b| red("test") }
    end
  end

  def test_call_with_three_parameter_block_raises_error
    # Blocks with 3 parameters should also raise ArgumentError
    assert_raises(ArgumentError) do
      @gouache.call { |x, y, z| bold("test") }
    end
  end
end
