# frozen_string_literal: true

require_relative "test_helper"

class TestRepaint < Minitest::Test
  using Gouache::Wrap

  def setup
    super
    @go = Gouache.new.enable  # Ensure enabled for default tests
  end

  def test_repaint_plain_text_passes_through_enabled
    # Plain text without SGR codes should pass through unchanged when enabled
    result = @go.repaint("plain text")
    assert_equal "plain text", result
  end

  def test_repaint_plain_text_passes_through_disabled
    # Plain text should pass through unchanged when disabled
    @go.disable
    result = @go.repaint("plain text")
    assert_equal "plain text", result
  end

  def test_repaint_fixes_reset_code_leakage_enabled
    # \e[0m would reset all styles - should be transformed to specific resets when enabled
    problematic = "text with \e[31mred\e[0m reset"
    result = @go.repaint(problematic)
    expected = "text with \e[31mred\e[0m reset"
    assert_equal expected, result
  end

  def test_repaint_strips_sgr_when_disabled
    # When disabled, repaint should strip SGR codes like unpaint
    @go.disable
    problematic = "text with \e[31mred\e[0m reset"
    result = @go.repaint(problematic)
    expected = "text with red reset"  # All SGR codes stripped
    assert_equal expected, result
  end

  def test_repaint_fixes_multiple_reset_codes
    # Multiple reset codes should all be transformed to specific resets
    problematic = "start \e[1mbold\e[0m middle \e[31mred\e[0m end"
    result = @go.repaint(problematic)
    expected = "start \e[1mbold\e[0m middle \e[31mred\e[0m end"
    assert_equal expected, result
  end

  def test_repaint_handles_complex_sgr_sequences
    # Complex multi-code SGR sequences should be properly ordered and reset incrementally
    problematic = "text \e[1;31;4mbold red underline\e[0m end"
    result = @go.repaint(problematic)
    expected = "text \e[31;4;1mbold red underline\e[0m end"
    assert_equal expected, result
  end

  def test_repaint_preserves_non_sgr_escapes
    # Non-SGR escape sequences should pass through unchanged
    text_with_cursor = "line1\e[2Jclear\e[H home"
    result = @go.repaint(text_with_cursor)
    assert_equal text_with_cursor, result
  end

  def test_repaint_handles_incomplete_escapes
    # Incomplete escape sequences should pass through unchanged
    malformed = "text \e[31 incomplete and \e[ empty"
    result = @go.repaint(malformed)
    assert_equal malformed, result
  end

  def test_repaint_with_wrapped_content_inside
    # Wrapped content within string should be processed correctly
    content_to_wrap = "wrapped \e[32mgreen\e[0m content"
    text_with_wrap = "before #{content_to_wrap.wrap} after \e[31mred\e[0m end"
    result = @go.repaint(text_with_wrap)
    expected = "before wrapped \e[32mgreen\e[0m content after \e[31mred\e[0m end"
    assert_equal expected, result
  end

  def test_repaint_nested_wrapped_content
    # Multiple levels of wrapping should be handled
    inner = "inner \e[1mbold\e[0m"
    outer = "outer #{inner.wrap} \e[31mred\e[0m"
    text_with_nested = "start #{outer.wrap} end"
    result = @go.repaint(text_with_nested)
    expected = "start outer inner \e[1mbold\e[0m \e[31mred\e[0m end"
    assert_equal expected, result
  end

  def test_repaint_string_ending_with_problematic_code
    # String ending with reset code - final 0m preserved as-is
    problematic = "styled text \e[31mred\e[0m"
    result = @go.repaint(problematic)
    expected = "styled text \e[31mred\e[0m"  # Final 0m not transformed when at end
    assert_equal expected, result
  end

  def test_repaint_string_starting_with_problematic_code
    # String starting with SGR codes should be processed with bold prefix
    problematic = "\e[1mbold start\e[0m normal end"
    result = @go.repaint(problematic)
    expected = "\e[1mbold start\e[0m normal end"
    assert_equal expected, result
  end

  def test_repaint_only_sgr_codes
    # String containing only SGR codes with no text produces empty result
    only_sgr = "\e[31m\e[1m\e[0m\e[32m\e[0m"
    result = @go.repaint(only_sgr)
    expected = ""  # No actual text content results in empty output
    assert_equal expected, result
  end

  def test_repaint_mixed_good_and_bad_codes
    # Mix of problematic and non-problematic SGR codes - only 0m gets transformed
    mixed = "text \e[31mred \e[1mbold\e[22m unbold \e[39m default\e[0m reset"
    result = @go.repaint(mixed)
    expected = "text \e[31mred \e[1mbold\e[22m unbold \e[0m default reset"
    assert_equal expected, result
  end

  def test_repaint_empty_string
    # Empty string should return empty string
    result = @go.repaint("")
    assert_equal "", result
  end

  def test_repaint_whitespace_only
    # Whitespace-only string should pass through
    whitespace = "   \n\t  "
    result = @go.repaint(whitespace)
    assert_equal whitespace, result
  end

  def test_repaint_multiple_consecutive_resets
    # Multiple consecutive reset codes - only first processed, rest ignored
    consecutive_resets = "text\e[0m\e[0m\e[0m"
    result = @go.repaint(consecutive_resets)
    expected = "text"  # Consecutive 0m codes after first are ignored
    assert_equal expected, result
  end

  def test_repaint_interleaved_wraps_and_sgr
    # Wrapped content interleaved with unwrapped SGR codes
    wrap1 = "wrap1 \e[32mgreen\e[0m".wrap
    wrap2 = "wrap2 \e[4munder\e[0m".wrap
    complex = "start #{wrap1} middle \e[31mred\e[0m #{wrap2} end"
    result = @go.repaint(complex)
    expected = "start wrap1 \e[32mgreen\e[0m middle \e[31mred\e[0m wrap2 \e[4munder\e[0m end"
    assert_equal expected, result
  end

  def test_repaint_background_color_codes
    # Background color codes should get proper background reset
    bg_problematic = "text \e[41mred bg\e[0m normal"
    result = @go.repaint(bg_problematic)
    expected = "text \e[41mred bg\e[0m normal"
    assert_equal expected, result
  end

  def test_repaint_mixed_fg_bg_codes
    # Mixed foreground and background colors get specific resets for each
    mixed_colors = "text \e[31;41mred fg red bg\e[0m normal"
    result = @go.repaint(mixed_colors)
    expected = "text \e[31;41mred fg red bg\e[0m normal"
    assert_equal expected, result
  end

  def test_repaint_256_color_codes
    # 256-color codes should be preserved
    color256 = "text \e[38;5;196mbright red\e[0m normal"
    result = @go.repaint(color256)
    expected = "text \e[38;5;196mbright red\e[0m normal"
    assert_equal expected, result
  end

  def test_repaint_truecolor_codes
    # Truecolor (RGB) codes should be preserved
    truecolor = "text \e[38;2;255;0;0mred rgb\e[0m normal"
    result = @go.repaint(truecolor)
    expected = "text \e[38;2;255;0;0mred rgb\e[0m normal"
    assert_equal expected, result
  end

  def test_repaint_with_custom_styles_context
    # repaint should work with custom styled Gouache instances
    custom_go = Gouache.new(custom_red: 91)
    problematic = "text \e[31mstandard red\e[0m normal"
    result = custom_go.repaint(problematic)
    expected = "text \e[31mstandard red\e[0m normal"
    assert_equal expected, result
  end

  def test_repaint_extremely_long_string
    # Long strings with many SGR codes should be handled efficiently
    long_parts = Array.new(100) { |i| "part#{i} \e[3#{i%8}mcolor\e[0m" }
    long_string = long_parts.join(" ")
    result = @go.repaint(long_string)

    # With the new behavior, all intermediate 0m resets stay as 0m
    expected_pattern = /part\d+ \e\[3[0-7]mcolor\e\[0m/
    assert_match expected_pattern, result

    # Should not add extra final reset since each section already ends with 0m
    refute result.end_with?(" \e[0m")

    # Verify the pattern repeats throughout the string
    matches = result.scan(expected_pattern)
    assert_equal 100, matches.size, "Should have 100 color sections"
  end

  def test_repaint_unicode_with_sgr
    # Unicode text with SGR codes should be handled correctly without corruption
    unicode_sgr = "emoji 🌈 \e[31mred text\e[0m unicode ñoño"
    result = @go.repaint(unicode_sgr)
    expected = "emoji 🌈 \e[31mred text\e[0m unicode ñoño"  # Unicode preserved, using 0m reset
    assert_equal expected, result
  end

  def test_repaint_contains_sgr_when_enabled
    # repaint should contain SGR codes when enabled
    problematic = "test \e[1;31mbold red\e[0m end"
    result = @go.repaint(problematic)

    # Should contain SGR codes when enabled
    assert_match(/\e\[\d/, result)  # Contains escape sequences
    refute_equal "test bold red end", result  # Not just plain text
  end

  def test_repaint_vs_unpaint_consistency_when_disabled
    # repaint should produce identical result to unpaint when disabled
    @go.disable
    problematic = "test \e[1;31mbold red\e[0m end"

    # unpaint call (what repaint does internally when disabled)
    unpaint_result = @go.unpaint(problematic)

    # repaint method call - should be identical when disabled
    repaint_result = @go.repaint(problematic)

    assert_equal unpaint_result, repaint_result  # Both methods produce same output
  end

  def test_repaint_enabled_state_switching
    # repaint behavior should change based on current enabled state
    problematic = "text \e[31mred\e[0m end"

    # When enabled - should process SGR codes
    @go.enable
    enabled_result = @go.repaint(problematic)
    assert_includes enabled_result, "\e[31m"  # Contains SGR codes

    # When disabled - should strip SGR codes
    @go.disable
    disabled_result = @go.repaint(problematic)
    refute_includes disabled_result, "\e[31m"  # No SGR codes
    assert_equal "text red end", disabled_result
  end
end
