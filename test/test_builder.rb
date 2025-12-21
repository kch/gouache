# frozen_string_literal: true

require_relative "test_helper"

class TestBuilder < Minitest::Test
  @@called_tags = []

  def setup
    @gouache = Gouache.new
    @@called_tags.clear

    # Set up tag tracking
    Gouache::Emitter.alias_method :open_tag_original, :open_tag
    Gouache::Emitter.remove_method :open_tag
    Gouache::Emitter.define_method(:open_tag) do |tag|
      @@called_tags << tag
      open_tag_original(tag)
    end
  end

  def teardown
    # Restore original method
    Gouache::Emitter.remove_method :open_tag
    Gouache::Emitter.alias_method :open_tag, :open_tag_original
    Gouache::Emitter.remove_method :open_tag_original
  end

  def test_simple_method_call_returns_string
    result = @gouache.red("foo")
    assert_equal "\e[31mfoo\e[0m", result
  end

  def test_chaining_level_1
    result = @gouache.red.bold("foo")
    assert_equal "\e[31;22;1mfoo\e[0m", result
  end

  def test_chaining_level_2
    result = @gouache.red.bold.underline("foo")
    assert_equal "\e[31;4;22;1mfoo\e[0m", result
  end

  def test_chaining_level_3
    result = @gouache.red.bold.underline.italic("foo")
    assert_equal "\e[31;3;4;22;1mfoo\e[0m", result
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

    expected = "\e[34;3;7;22;1mwow" +
               "\e[35;23;27;9;1;2mdim_strike" +
               "\e[32;29;22;1mgreen_text" +
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
    assert_raises(Gouache::Builder::UnfinishedChain) do
      @gouache.red.bold {|x|
        x.underline.underline.underline
      }
    end
  end

  def test_unfinished_chain_with_content_before
    assert_raises(Gouache::Builder::UnfinishedChain) do
      @gouache.red.bold {|x|
        x.bar("content")
        x.underline
      }
    end
  end

  def test_unfinished_chain_with_content_after
    assert_raises(Gouache::Builder::UnfinishedChain) do
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
               "\e[39mnested_call_text" +
               "\e[0m"
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

    expected = "\e[36;22;1mdeep_nested_content" +
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

    expected = "\e[32;22;1mgreen_text" +
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
    # UnfinishedChain is only raised when the chain is left dangling in a block context
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

    expected = "\e[35;22;1mnested_content" +
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
end
