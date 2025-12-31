# frozen_string_literal: true

require_relative "test_helper"

class TestPrinters < Minitest::Test
  using Gouache::Wrap

  def setup
    super
    @go = Gouache.new
  end

  def test_puts_single_argument_enabled
    # puts with single argument when enabled should apply repaint
    @go.enable
    out, _err = capture_io do
      @go.puts("text with \e[31mred\e[0m content")
    end
    expected = "text with \e[31mred\e[0m content\n"
    assert_equal expected, out
  end

  def test_puts_single_argument_disabled
    # puts with single argument when disabled should match plain IO puts
    @go.disable
    test_string = "text with \e[31mred\e[0m content"

    # Gouache puts output
    go_out, _err = capture_io do
      @go.puts(test_string)
    end

    # Plain IO puts output
    plain_out, _err = capture_io do
      $stdout.puts(test_string)
    end

    # Should match exactly (both just strip SGR codes)
    assert_equal plain_out.gsub(/\e\[[;\d]*m/, ""), go_out
  end

  def test_puts_multiple_arguments_enabled
    # puts with multiple arguments when enabled
    @go.enable
    out, _err = capture_io do
      @go.puts("line1 \e[31mred\e[0m", "line2 \e[32mgreen\e[0m", "line3")
    end
    expected = "line1 \e[31mred\e[0m\n" +
               "line2 \e[32mgreen\e[0m\n" +
               "line3\n"
    assert_equal expected, out
  end

  def test_puts_multiple_arguments_disabled
    # puts with multiple arguments when disabled should match plain puts
    @go.disable
    args = ["line1 \e[31mred\e[0m", "line2 \e[32mgreen\e[0m", "line3"]

    # Gouache puts output
    go_out, _err = capture_io do
      @go.puts(*args)
    end

    # Plain IO puts output with unpainted args
    plain_out, _err = capture_io do
      $stdout.puts(*args.map { |arg| @go.unpaint(arg) })
    end

    assert_equal plain_out, go_out
  end

  def test_puts_no_arguments
    # puts with no arguments should output newline
    out, _err = capture_io do
      @go.puts
    end
    assert_equal "\n", out
  end

  def test_puts_with_custom_io_enabled
    # puts should use custom IO when enabled
    require 'stringio'
    custom_io = StringIO.new
    @go.reopen(custom_io).enable

    @go.puts("styled \e[31mred\e[0m text")

    custom_io.rewind
    result = custom_io.read
    expected = "styled \e[31mred\e[0m text\n"
    assert_equal expected, result
  end

  def test_puts_with_custom_io_disabled
    # puts should use custom IO when disabled and match plain behavior
    require 'stringio'
    custom_io = StringIO.new
    plain_io = StringIO.new
    @go.reopen(custom_io).disable

    test_string = "styled \e[31mred\e[0m text"

    # Gouache puts to custom IO
    @go.puts(test_string)

    # Plain puts to comparison IO
    plain_io.puts(@go.unpaint(test_string))

    custom_io.rewind
    plain_io.rewind
    assert_equal plain_io.read, custom_io.read
  end

  def test_print_single_argument_enabled
    # print with single argument when enabled should apply repaint
    @go.enable
    out, _err = capture_io do
      @go.print("text with \e[31mred\e[0m content")
    end
    expected = "text with \e[31mred\e[0m content"
    assert_equal expected, out
  end

  def test_print_single_argument_disabled
    # print with single argument when disabled should match plain IO print
    @go.disable
    test_string = "text with \e[31mred\e[0m content"

    # Gouache print output
    go_out, _err = capture_io do
      @go.print(test_string)
    end

    # Plain IO print output
    plain_out, _err = capture_io do
      $stdout.print(@go.unpaint(test_string))
    end

    assert_equal plain_out, go_out
  end

  def test_print_multiple_arguments_enabled
    # print with multiple arguments when enabled (no newlines)
    @go.enable
    out, _err = capture_io do
      @go.print("part1 \e[31mred\e[0m", "part2 \e[32mgreen\e[0m", "part3")
    end
    expected = "part1 \e[31mred\e[0m" +
               "part2 \e[32mgreen\e[0m" +
               "part3"
    assert_equal expected, out
  end

  def test_print_multiple_arguments_disabled
    # print with multiple arguments when disabled should match plain print
    @go.disable
    args = ["part1 \e[31mred\e[0m", "part2 \e[32mgreen\e[0m", "part3"]

    # Gouache print output
    go_out, _err = capture_io do
      @go.print(*args)
    end

    # Plain IO print output with unpainted args
    plain_out, _err = capture_io do
      $stdout.print(*args.map { |arg| @go.unpaint(arg) })
    end

    assert_equal plain_out, go_out
  end

  def test_print_no_arguments
    # print with no arguments should output nothing
    out, _err = capture_io do
      @go.print
    end
    assert_equal "", out
  end

  def test_print_with_custom_io_enabled
    # print should use custom IO when enabled
    require 'stringio'
    custom_io = StringIO.new
    @go.reopen(custom_io).enable

    @go.print("styled \e[31mred\e[0m text")

    custom_io.rewind
    result = custom_io.read
    expected = "styled \e[31mred\e[0m text"
    assert_equal expected, result
  end

  def test_print_with_custom_io_disabled
    # print should use custom IO when disabled and match plain behavior
    require 'stringio'
    custom_io = StringIO.new
    plain_io = StringIO.new
    @go.reopen(custom_io).disable

    test_string = "styled \e[31mred\e[0m text"

    # Gouache print to custom IO
    @go.print(test_string)

    # Plain print to comparison IO
    plain_io.print(@go.unpaint(test_string))

    custom_io.rewind
    plain_io.rewind
    assert_equal plain_io.read, custom_io.read
  end

  def test_puts_print_mixed_usage
    # Mixed puts and print usage
    @go.enable
    out, _err = capture_io do
      @go.print("start \e[31mred\e[0m ")
      @go.puts("line1 \e[32mgreen\e[0m")
      @go.print("middle ")
      @go.puts("line2")
    end
    expected = "start \e[31mred\e[0m " +
               "line1 \e[32mgreen\e[0m\n" +
               "middle " +
               "line2\n"
    assert_equal expected, out
  end

  def test_puts_with_wrapped_content
    # puts should handle wrapped content correctly
    @go.enable
    wrapped = "wrapped \e[35mmagenta\e[0m text".wrap

    out, _err = capture_io do
      @go.puts("before #{wrapped} after")
    end
    expected = "before wrapped \e[35mmagenta\e[0m text after\n"
    assert_equal expected, out
  end

  def test_print_with_wrapped_content
    # print should handle wrapped content correctly
    @go.enable
    wrapped = "wrapped \e[35mmagenta\e[0m text".wrap

    out, _err = capture_io do
      @go.print("before #{wrapped} after")
    end
    expected = "before wrapped \e[35mmagenta\e[0m text after"
    assert_equal expected, out
  end

  def test_puts_with_various_data_types
    # puts should handle various data types via to_s conversion
    @go.enable
    out, _err = capture_io do
      @go.puts(123, nil, true, :symbol)
    end
    expected = "123\n\ntrue\nsymbol\n"
    assert_equal expected, out
  end

  def test_print_with_various_data_types
    # print should handle various data types via to_s conversion
    @go.enable
    out, _err = capture_io do
      @go.print(123, nil, true, :symbol)
    end
    expected = "123truesymbol"
    assert_equal expected, out
  end

  def test_puts_print_enabled_state_switching
    # puts/print behavior should change with enabled state
    test_string = "test \e[31mred\e[0m content"

    # When enabled - should process SGR codes
    @go.enable
    enabled_out, _err = capture_io do
      @go.puts(test_string)
    end
    assert_includes enabled_out, "\e[31m"  # Contains SGR codes

    # When disabled - should strip SGR codes
    @go.disable
    disabled_out, _err = capture_io do
      @go.puts(test_string)
    end
    refute_includes disabled_out, "\e[31m"  # No SGR codes
    assert_equal "test red content\n", disabled_out
  end

  def test_puts_print_with_tty_detection
    # puts/print should respect TTY detection when enabled is nil
    require 'stringio'

    # Mock non-TTY IO
    non_tty_io = StringIO.new
    def non_tty_io.tty? = false
    def non_tty_io.puts(s) = write("#{s}\n")
    def non_tty_io.print(s) = write(s)

    @go.reopen(non_tty_io)  # enabled? will return false due to tty?
    test_string = "test \e[31mred\e[0m content"

    @go.puts(test_string)

    non_tty_io.rewind
    result = non_tty_io.read
    # Should be unpainted since TTY detection returned false
    assert_equal "test red content\n", result
  end
end
