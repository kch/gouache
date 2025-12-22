# frozen_string_literal: true

require_relative "test_helper"

class TestRepaint < Minitest::Test
  using Gouache::Wrap

  def setup
    @go = Gouache.new
  end

  def test_repaint_plain_text_passes_through
    # Plain text without SGR codes should pass through unchanged
    result = @go.repaint("plain text")
    assert_equal "plain text", result
  end

  def test_repaint_fixes_reset_code_leakage
    # \e[0m would reset all styles - should be transformed to specific resets
    problematic = "text with \e[31mred\e[0m reset"
    result = @go.repaint(problematic)
    expected = "text with \e[31mred\e[39m reset\e[0m"  # 0m -> 39m (default fg), final 0m added
    assert_equal expected, result
  end

  def test_repaint_fixes_multiple_reset_codes
    # Multiple reset codes should all be transformed to specific resets
    problematic = "start \e[1mbold\e[0m middle \e[31mred\e[0m end"
    result = @go.repaint(problematic)
    expected = "start \e[22;1mbold\e[22m middle \e[31mred\e[39m end\e[0m"  # First 0m -> 22m, second 0m -> 39m
    assert_equal expected, result
  end

  def test_repaint_handles_complex_sgr_sequences
    # Complex multi-code SGR sequences should be properly ordered and reset incrementally
    problematic = "text \e[1;31;4mbold red underline\e[0m end"
    result = @go.repaint(problematic)
    expected = "text \e[31;4;22;1mbold red underline\e[39;24;22m end\e[0m"  # 0m -> specific closes for each style
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
    expected = "before wrapped \e[32mgreen\e[39m content after \e[31mred\e[39m end\e[0m"
    assert_equal expected, result
  end

  def test_repaint_nested_wrapped_content
    # Multiple levels of wrapping should be handled
    inner = "inner \e[1mbold\e[0m"
    outer = "outer #{inner.wrap} \e[31mred\e[0m"
    text_with_nested = "start #{outer.wrap} end"
    result = @go.repaint(text_with_nested)
    expected = "start outer inner \e[22;1mbold\e[22m \e[31mred\e[39m end\e[0m"
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
    expected = "\e[22;1mbold start\e[22m normal end\e[0m"  # Bold gets 22 prefix, 0m -> 22m, final 0m added
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
    expected = "text \e[31mred \e[22;1mbold\e[22m unbold \e[39m default reset\e[0m"  # Only the final 0m removed, rest preserved
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
    expected = "start wrap1 \e[32mgreen\e[39m middle \e[31mred\e[39m wrap2 \e[4munder\e[24m end\e[0m"
    assert_equal expected, result
  end

  def test_repaint_background_color_codes
    # Background color codes should get proper background reset
    bg_problematic = "text \e[41mred bg\e[0m normal"
    result = @go.repaint(bg_problematic)
    expected = "text \e[41mred bg\e[49m normal\e[0m"  # 0m -> 49m (bg reset), final 0m added
    assert_equal expected, result
  end

  def test_repaint_mixed_fg_bg_codes
    # Mixed foreground and background colors get specific resets for each
    mixed_colors = "text \e[31;41mred fg red bg\e[0m normal"
    result = @go.repaint(mixed_colors)
    expected = "text \e[31;41mred fg red bg\e[39;49m normal\e[0m"  # 0m -> 39m (fg) + 49m (bg)
    assert_equal expected, result
  end

  def test_repaint_256_color_codes
    # 256-color codes should be preserved
    color256 = "text \e[38;5;196mbright red\e[0m normal"
    result = @go.repaint(color256)
    expected = "text \e[38;5;196mbright red\e[39m normal\e[0m"
    assert_equal expected, result
  end

  def test_repaint_truecolor_codes
    # Truecolor (RGB) codes should be preserved
    truecolor = "text \e[38;2;255;0;0mred rgb\e[0m normal"
    result = @go.repaint(truecolor)
    expected = "text \e[38;2;255;0;0mred rgb\e[39m normal\e[0m"
    assert_equal expected, result
  end

  def test_repaint_with_custom_styles_context
    # repaint should work with custom styled Gouache instances
    custom_go = Gouache.new(custom_red: 91)
    problematic = "text \e[31mstandard red\e[0m normal"
    result = custom_go.repaint(problematic)
    expected = "text \e[31mstandard red\e[39m normal\e[0m"
    assert_equal expected, result
  end

  def test_repaint_extremely_long_string
    # Long strings with many SGR codes should be handled efficiently
    long_parts = Array.new(100) { |i| "part#{i} \e[3#{i%8}mcolor\e[0m" }
    long_string = long_parts.join(" ")
    result = @go.repaint(long_string)

    # Should transform internal 0m codes to 39m, but preserve final 0m terminator
    assert_includes result, "\e[39m"  # Internal resets become 39m
    assert result.end_with?("\e[0m")  # Final complete reset preserved
  end

  def test_repaint_unicode_with_sgr
    # Unicode text with SGR codes should be handled correctly without corruption
    unicode_sgr = "emoji 🌈 \e[31mred text\e[0m unicode ñoño"
    result = @go.repaint(unicode_sgr)
    expected = "emoji 🌈 \e[31mred text\e[39m unicode ñoño\e[0m"  # Unicode preserved, 0m -> 39m
    assert_equal expected, result
  end

  def test_repaint_vs_safe_emit_consistency
  # repaint should produce identical result to direct safe_emit_sgr call
  problematic = "test \e[1;31mbold red\e[0m end"

  # Direct call to safe_emit_sgr (what repaint does internally)
  emitter = @go.mk_emitter
  Gouache::Builder.safe_emit_sgr(problematic, emitter: emitter)
  direct_result = emitter.emit!

  # repaint method call - should be identical
  repaint_result = @go.repaint(problematic)

  assert_equal direct_result, repaint_result  # Both methods produce same output
  end
end
