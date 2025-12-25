# frozen_string_literal: true

require_relative "test_helper"

class TestMain < Minitest::Test
  using Gouache::Wrap
  def setup
    @original_stdout = $stdout
    @string_io = StringIO.new
  end

  def teardown
    $stdout = @original_stdout
  end

  def test_class_bracket_method_basic
    # Gouache.[] should work like instance []
    result = Gouache[:red, "text"]
    assert_equal "\e[31mtext\e[0m", result
  end

  def test_class_bracket_method_with_styles
    # Gouache[] with styles should create temporary instance
    result = Gouache[:bold, "text", custom: 33]
    expected = "\e[22;1mtext\e[0m"
    assert_equal expected, result
  end

  def test_class_bracket_method_with_custom_styles_used
    # Custom styles in Gouache[] should be available
    result = Gouache[:custom, "text", custom: 33]
    expected = "\e[33mtext\e[0m"
    assert_equal expected, result
  end

  def test_class_bracket_method_with_block
    # Gouache[] with block should work
    result = Gouache[] {|x| x.red("content") }
    expected = "\e[31mcontent\e[0m"
    assert_equal expected, result
  end

  def test_class_bracket_method_with_styles_and_block
    # Gouache[] with custom styles and block
    result = Gouache[custom: 33] {|x| x.custom("content") }
    expected = "\e[33mcontent\e[0m"
    assert_equal expected, result
  end

  def test_class_bracket_method_arrays
    # Gouache[] should handle arrays like instance
    result = Gouache[[:bold, "bold"], " ", [:red, "red"]]
    expected = "\e[22;1mbold\e[22m \e[31mred\e[0m"
    assert_equal expected, result
  end

  def test_delegated_enable_method
    # Gouache.enable should delegate to MAIN
    result = Gouache.enable
    assert_equal Gouache::MAIN, result
    assert_equal true, Gouache::MAIN.enabled?
    # Restore original state
    Gouache::MAIN.instance_variable_set(:@enabled, nil)
  end

  def test_delegated_disable_method
    # Gouache.disable should delegate to MAIN
    result = Gouache.disable
    assert_equal Gouache::MAIN, result
    assert_equal false, Gouache::MAIN.enabled?
    # Restore original state
    Gouache::MAIN.instance_variable_set(:@enabled, nil)
  end

  def test_delegated_enabled_query_method
    # Gouache.enabled? should delegate to MAIN
    Gouache::MAIN.enable
    assert_equal true, Gouache.enabled?

    Gouache::MAIN.disable
    assert_equal false, Gouache.enabled?

    # Restore original state
    Gouache::MAIN.instance_variable_set(:@enabled, nil)
  end

  def test_delegated_reopen_method
    # Gouache.reopen should delegate to MAIN
    original_io = Gouache::MAIN.io
    new_io = StringIO.new

    result = Gouache.reopen(new_io)
    assert_equal Gouache::MAIN, result
    assert_equal new_io, Gouache::MAIN.io

    # Restore original IO
    Gouache::MAIN.reopen(original_io)
  end

  def test_delegated_puts_method
    # Gouache.puts should delegate to MAIN
    Gouache.reopen(@string_io)

    Gouache.puts("hello", "world")
    assert_equal "hello\nworld\n", @string_io.string

    # Restore
    Gouache.reopen(@original_stdout)
  end

  def test_delegated_print_method
    # Gouache.print should delegate to MAIN
    Gouache.reopen(@string_io)

    Gouache.print("hello", "world")
    assert_equal "helloworld", @string_io.string

    # Restore
    Gouache.reopen(@original_stdout)
  end

  def test_delegated_puts_with_styled_content
    # Gouache.puts should handle styled content when enabled
    Gouache.reopen(@string_io).enable

    styled = Gouache[:red, "colored"]
    Gouache.puts("plain", styled)

    output = @string_io.string
    assert_includes output, "plain\n"
    assert_includes output, "\e[31mcolored\e[0m\n"

    # Restore
    Gouache.reopen(@original_stdout).instance_variable_set(:@enabled, nil)
  end

  def test_delegated_print_with_styled_content
    # Gouache.print should handle styled content when enabled
    Gouache.reopen(@string_io).enable

    styled = Gouache[:blue, "colored"]
    Gouache.print("plain", styled)

    output = @string_io.string
    assert_includes output, "plain"
    assert_includes output, "\e[34mcolored\e[0m"

    # Restore
    Gouache.reopen(@original_stdout).instance_variable_set(:@enabled, nil)
  end

  def test_delegated_puts_when_disabled
    # Gouache.puts should strip colors when disabled
    Gouache.reopen(@string_io).disable

    styled = Gouache[:red, "colored"]
    Gouache.puts(styled)

    # Should have content but no escape codes
    output = @string_io.string
    assert_equal "colored\n", output
    refute_includes output, "\e["

    # Restore
    Gouache.reopen(@original_stdout).instance_variable_set(:@enabled, nil)
  end

  def test_main_instance_exists
    # MAIN constant should exist and be a Gouache instance
    assert_kind_of Gouache, Gouache::MAIN
  end

  def test_main_instance_has_base_styles
    # MAIN instance should have base stylesheet
    assert Gouache::MAIN.rules.key?(:red)
    assert Gouache::MAIN.rules.key?(:bold)
    assert Gouache::MAIN.rules.key?(:blue)
  end

  def test_class_methods_vs_main_instance_consistency
    # Class methods should behave like MAIN instance methods
    class_result = Gouache[:green, "text"]
    instance_result = Gouache::MAIN[:green, "text"]
    assert_equal instance_result, class_result
  end

  def test_class_bracket_with_styles_doesnt_affect_main
    # Using Gouache[] with styles shouldn't affect MAIN instance
    had_custom = Gouache::MAIN.rules.key?(:custom)

    Gouache[:custom, "text", custom: 33]

    # MAIN should be unchanged
    assert_equal had_custom, Gouache::MAIN.rules.key?(:custom)
  end

  def test_class_unpaint_method
    # Gouache.unpaint should strip escape codes
    styled = "\e[31mred\e[0m text \e[1mbold\e[0m"
    result = Gouache.unpaint(styled)
    assert_equal "red text bold", result
  end

  def test_class_wrap_method
    # Gouache.wrap should add wrap sequences to SGR content
    sgr_content = "\e[31mcontent\e[0m"
    result = Gouache.wrap(sgr_content)
    assert_includes result, "\e]971"
    assert_includes result, "content"
  end

  def test_class_embed_alias
    # Gouache.embed should be alias for wrap
    result1 = Gouache.wrap("content")
    result2 = Gouache.embed("content")
    assert_equal result1, result2
  end

  def test_class_scan_sgr_method
    # Gouache.scan_sgr should extract SGR codes
    sgr_string = "\e[31;1m"
    result = Gouache.scan_sgr(sgr_string)
    assert_includes result, 31
    assert_includes result, 1
  end

  def test_delegated_methods_return_main_instance
    # Delegated methods should return MAIN for chaining
    result = Gouache.enable.disable.reopen(@string_io)
    assert_equal Gouache::MAIN, result

    # Restore
    Gouache.reopen(@original_stdout).instance_variable_set(:@enabled, nil)
  end

  def test_complex_chaining_with_delegated_methods
    # Complex chaining of delegated methods
    Gouache.reopen(@string_io).enable
    Gouache.puts(Gouache[:red, "styled"])
    Gouache.disable
    Gouache.puts(Gouache[:blue, "unstyled"])

    output = @string_io.string
    lines = output.split("\n")

    # First line should have escape codes
    assert_includes lines[0], "\e[31m"
    # Second line should not have escape codes
    assert_equal "unstyled", lines[1]

    # Restore
    Gouache.reopen(@original_stdout).instance_variable_set(:@enabled, nil)
  end

  def test_class_method_missing_delegates_to_main
    # Class-level method_missing should delegate builder methods to MAIN
    result = Gouache.red("content")
    expected = "\e[31mcontent\e[0m"
    assert_equal expected, result
  end

  def test_class_method_missing_with_chaining
    # Class-level chained builder methods should work
    result = Gouache.red.bold("content")
    expected = "\e[22;31;1mcontent\e[0m"
    assert_equal expected, result
  end

  def test_class_method_missing_with_block
    # Class-level builder methods with blocks should work
    result = Gouache.red {|x| x.bold("content") }
    expected = "\e[22;31;1mcontent\e[0m"
    assert_equal expected, result
  end

  def test_class_method_missing_with_arrays
    # Class-level builder methods should handle arrays
    result = Gouache.red([:bold, "content"])
    expected = "\e[22;31;1mcontent\e[0m"
    assert_equal expected, result
  end
end
