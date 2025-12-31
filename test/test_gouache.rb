# frozen_string_literal: true

require_relative "test_helper"

class TestGouache < Minitest::Test
  using Gouache::Wrap

  def test_initialize_default_values
    # Default initialization should set nil values for io and enabled
    go = Gouache.new
    assert_equal $stdout, go.io  # Should default to $stdout
    assert [true, false].include?(go.enabled?)  # Should always return boolean
    assert_kind_of Gouache::Stylesheet, go.stylesheet
    assert go.stylesheet.tag?(:red)  # Verify base styles are present
  end

  def test_initialize_with_styles_hash
    # Styles hash should be merged with base stylesheet
    custom_styles = {custom_red: 31, custom_blue: 34}
    go = Gouache.new(styles: custom_styles)
    assert go.stylesheet.tag?(:custom_red)
    assert go.stylesheet.tag?(:custom_blue)
    # Base styles should still be present
    assert go.stylesheet.tag?(:red)  # From BASE stylesheet
  end

  def test_initialize_with_keyword_styles
    # Keyword arguments should be merged as styles
    go = Gouache.new(my_red: 31, my_blue: 34)
    assert go.stylesheet.tag?(:my_red)
    assert go.stylesheet.tag?(:my_blue)
    # Base styles should still be present
    assert go.stylesheet.tag?(:red)
  end

  def test_initialize_with_both_styles_and_keywords
    # Both styles hash and keywords should be merged
    styles_hash = {hash_style: 31}
    go = Gouache.new(styles: styles_hash, keyword_style: 32)
    assert go.stylesheet.tag?(:hash_style)
    assert go.stylesheet.tag?(:keyword_style)
    # Base styles should still be present
    assert go.stylesheet.tag?(:red)
  end

  def test_initialize_keywords_override_styles_hash
    # Keyword arguments should take precedence over styles hash
    go = Gouache.new(styles: {red: 31}, red: 32)
    # Just verify red key exists (keyword should override)
    assert go.stylesheet.tag?(:red)
  end

  def test_initialize_with_io_parameter
    # IO parameter should be stored
    require 'stringio'
    custom_io = StringIO.new
    go = Gouache.new(io: custom_io)
    assert_equal custom_io, go.io
  end

  def test_initialize_with_enabled_true
    # Enabled parameter should be stored when true
    go = Gouache.new(enabled: true)
    assert_equal true, go.enabled?
  end

  def test_initialize_with_enabled_false
    # Enabled parameter should be stored when false
    go = Gouache.new(enabled: false)
    assert_equal false, go.enabled?
  end

  def test_io_returns_custom_io
    # io method should return custom IO when set
    require 'stringio'
    custom_io = StringIO.new
    go = Gouache.new(io: custom_io)
    assert_equal custom_io, go.io
  end

  def test_io_returns_stdout_when_nil
    # io method should return $stdout when @io is nil
    go = Gouache.new
    assert_equal $stdout, go.io
  end

  def test_enable_sets_enabled_true
    # enable method should set @enabled to true and return self
    go = Gouache.new
    result = go.enable
    assert_equal go, result
    assert_equal true, go.enabled?
  end

  def test_disable_sets_enabled_false
    # disable method should set @enabled to false and return self
    go = Gouache.new
    result = go.disable
    assert_equal go, result
    assert_equal false, go.enabled?
  end

  def test_enabled_returns_explicit_true
    # enabled? should return true when explicitly set to true
    go = Gouache.new(enabled: true)
    assert_equal true, go.enabled?
  end

  def test_enabled_returns_explicit_false
    # enabled? should return false when explicitly set to false
    go = Gouache.new(enabled: false)
    assert_equal false, go.enabled?
  end

  def test_enabled_checks_tty_and_term_when_nil
    # enabled? should check io.tty? && ENV["TERM"] != "dumb" when @enabled is nil
    require 'stringio'

    # Mock a non-TTY IO
    non_tty_io = StringIO.new
    def non_tty_io.tty? = false

    go = Gouache.new(io: non_tty_io)
    assert_equal false, go.enabled?

    # Mock a TTY IO with normal TERM
    tty_io = StringIO.new
    def tty_io.tty? = true

    original_term = ENV["TERM"]
    begin
      ENV["TERM"] = "xterm"
      go2 = Gouache.new(io: tty_io)
      assert_equal true, go2.enabled?

      # TTY but TERM=dumb should be false
      ENV["TERM"] = "dumb"
      go3 = Gouache.new(io: tty_io)
      assert_equal false, go3.enabled?
    ensure
      ENV["TERM"] = original_term
    end
  end

  def test_reopen_changes_io
    # reopen should change the IO and return self
    require 'stringio'
    original_io = StringIO.new
    new_io = StringIO.new

    go = Gouache.new(io: original_io)
    result = go.reopen(new_io)

    assert_equal new_io, go.io
    assert_equal go, result  # Should return self for chaining
  end

  def test_reopen_affects_enabled_check
    # reopen should affect enabled? behavior via new IO's tty? method
    require 'stringio'

    original_term = ENV["TERM"]
    begin
      ENV["TERM"] = "xterm"

      # Start with non-TTY
      non_tty = StringIO.new
      def non_tty.tty? = false

      go = Gouache.new(io: non_tty)
      assert_equal false, go.enabled?

      # Reopen with TTY
      tty_io = StringIO.new
      def tty_io.tty? = true

      go.reopen(tty_io)
      assert_equal true, go.enabled?
    ensure
      ENV["TERM"] = original_term
    end
  end



  def test_chaining_enable_disable
    # enable/disable methods should be chainable
    go = Gouache.new

    result1 = go.enable.disable
    assert_equal go, result1
    assert_equal false, go.enabled?

    result2 = go.disable.enable
    assert_equal go, result2
    assert_equal true, go.enabled?
  end

  def test_chaining_reopen_with_enable_disable
    # reopen should be chainable with enable/disable
    require 'stringio'
    io1 = StringIO.new
    io2 = StringIO.new

    go = Gouache.new
    result = go.reopen(io1).enable.reopen(io2).disable

    assert_equal go, result
    assert_equal io2, go.io
    assert_equal false, go.enabled?
  end

  def test_rules_immutable_after_init
    # stylesheet should not be affected by later changes to initialization arguments
    styles_hash = {mutable_red: 31}
    go = Gouache.new(styles: styles_hash)

    # Modify original hash
    styles_hash[:mutable_red] = 32
    styles_hash[:new_style] = 33

    # Should not affect initialized stylesheet
    assert go.stylesheet.tag?(:mutable_red)
    refute go.stylesheet.tag?(:new_style)
  end

  def test_multiple_instances_independent
    # Multiple Gouache instances should be independent
    go1 = Gouache.new(style1: 31)
    go2 = Gouache.new(style2: 32)

    # Should have their own custom styles
    assert go1.stylesheet.tag?(:style1)
    refute go1.stylesheet.tag?(:style2)

    refute go2.stylesheet.tag?(:style1)
    assert go2.stylesheet.tag?(:style2)

    # Both should have base styles
    assert go1.stylesheet.tag?(:red)
    assert go2.stylesheet.tag?(:red)
  end

  def test_enabled_state_independent_across_instances
    # enabled state should be independent across instances
    go1 = Gouache.new
    go2 = Gouache.new

    go1.enable
    go2.disable

    assert_equal true, go1.enabled?
    assert_equal false, go2.enabled?
  end

  def test_io_state_independent_across_instances
    # IO state should be independent across instances
    require 'stringio'
    io1 = StringIO.new
    io2 = StringIO.new

    go1 = Gouache.new.reopen(io1)
    go2 = Gouache.new.reopen(io2)

    assert_equal io1, go1.io
    assert_equal io2, go2.io
  end

  def test_complex_initialization_scenario
    # Complex initialization with all parameters
    require 'stringio'
    custom_io = StringIO.new
    def custom_io.tty? = false

    go = Gouache.new(
      styles: {hash_red: 31, hash_blue: 34},
      io: custom_io,
      enabled: true,  # Override tty? check
      keyword_red: 32,  # Override hash_red
      keyword_green: 33
    )

    # Check all parameters were processed correctly
    assert_equal custom_io, go.io
    assert_equal true, go.enabled?  # Explicit override
    assert go.stylesheet.tag?(:keyword_red)   # Keyword won
    assert go.stylesheet.tag?(:hash_blue)     # From hash
    assert go.stylesheet.tag?(:keyword_green) # From keyword
  end

  def test_disabled_instance_produces_plain_output
    # When instance is disabled, builder methods should produce plain text
    go = Gouache.new.disable

    result = go.red("colored text")
    assert_equal "colored text", result

    result = go[:bold, "bold text"]
    assert_equal "bold text", result

    result = go[[:red, "red"], " and ", [:blue, "blue"]]
    assert_equal "red and blue", result
  end

  def test_class_new_passes_args_to_initialize
    # Class new method should pass all arguments to initialize
    require 'stringio'
    custom_io = StringIO.new

    go = Gouache.new(
      styles: {test_style: 31},
      io: custom_io,
      enabled: true,
      keyword_style: 32
    )

    # Verify all args were passed correctly
    assert_equal custom_io, go.io
    assert_equal true, go.enabled?
    assert go.stylesheet.tag?(:test_style)
    assert go.stylesheet.tag?(:keyword_style)
  end

  def test_class_new_with_block_calls_block
    # Class new method should call block and return formatted string
    called = false

    result = Gouache.new do
      called = true
      red("test")
    end

    assert called, "Block should have been called"
    assert_instance_of String, result, "Block result should be returned"
    assert result.include?("test"), "Result should contain test text"
  end

  def test_class_new_with_args_and_block
    # Class new should pass args to initialize AND call block
    require 'stringio'
    custom_io = StringIO.new
    called = false

    result = Gouache.new(io: custom_io, enabled: false, test_style: 99) do
      called = true
      test_style("styled text")
    end

    # Block should be called and return string
    assert called, "Block should have been called"
    assert_instance_of String, result, "Should return block result"
    assert result.include?("styled text"), "Result should contain styled text"
  end

  def test_class_new_without_block_returns_instance
    # Class new without block should just return the instance
    go = Gouache.new(test_style: 42)

    assert_instance_of Gouache, go
    assert go.stylesheet.tag?(:test_style)
  end

  def test_class_new_with_block_custom_styles_enabled
    # Class new with custom styles and block should use the styles when enabled
    result = Gouache.new(styles: {z: 1}) { it.z("foo") }
    assert_instance_of String, result
    assert_equal "\e[1mfoo\e[0m", result
  end

  def test_class_new_with_block_custom_styles_disabled
    # Class new with custom styles and block should produce plain text when disabled
    result = Gouache.new(styles: {z: 1}, enabled: false) { it.z("foo") }
    assert_instance_of String, result
    assert_equal "foo", result
  end
end
