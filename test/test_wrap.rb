# frozen_string_literal: true

require_relative "test_helper"

class TestWrap < Minitest::Test
  using Gouache::Wrap

  def test_has_sgr_with_simple_sgr
    # Simple SGR sequence should be detected
    text = "hello \e[31mworld\e[0m"
    assert text.has_sgr?
  end

  def test_has_sgr_with_complex_sgr
    # Complex multi-code SGR sequence should be detected
    text = "text \e[1;31;4mcomplex\e[0m end"
    assert text.has_sgr?
  end

  def test_has_sgr_without_sgr
    # Plain text without any escape sequences
    text = "plain text"
    refute text.has_sgr?
  end

  def test_has_sgr_with_non_sgr_escape
    # Non-SGR escape sequences should not be detected as SGR
    text = "cursor \e[2J clear"
    refute text.has_sgr?
  end

  def test_wrapped_with_proper_markers
    # String with both wrap markers should be detected as wrapped
    text = "#{Gouache::WRAP_OPEN}content#{Gouache::WRAP_CLOSE}"
    assert text.wrapped?
  end

  def test_wrapped_without_markers
    # String without wrap markers should not be detected as wrapped
    text = "plain content"
    refute text.wrapped?
  end

  def test_wrapped_with_only_start_marker
    # String with only start marker should not be detected as wrapped
    text = "#{Gouache::WRAP_OPEN}content"
    refute text.wrapped?
  end

  def test_wrapped_with_only_end_marker
    # String with only end marker should not be detected as wrapped
    text = "content#{Gouache::WRAP_CLOSE}"
    refute text.wrapped?
  end

  def test_wrap_bang_adds_markers
    # wrap! should always add markers regardless of content
    text = "content with \e[31mred\e[39m"
    result = text.wrap!
    expected = "#{Gouache::WRAP_OPEN}#{text}#{Gouache::WRAP_CLOSE}"
    assert_equal expected, result
  end

  def test_wrap_bang_on_plain_text
    # wrap! should add markers even to plain text
    text = "plain content"
    result = text.wrap!
    expected = "#{Gouache::WRAP_OPEN}#{text}#{Gouache::WRAP_CLOSE}"
    assert_equal expected, result
  end

  def test_wrap_with_sgr_not_wrapped
    # wrap should add markers to SGR content that isn't already wrapped
    text = "content \e[31mred\e[39m text"
    result = text.wrap
    expected = "#{Gouache::WRAP_OPEN}#{text}#{Gouache::WRAP_CLOSE}"
    assert_equal expected, result
  end

  def test_wrap_with_sgr_already_wrapped
    # wrap should not double-wrap already wrapped SGR content
    text = "#{Gouache::WRAP_OPEN}content \e[31mred\e[39m#{Gouache::WRAP_CLOSE}"
    result = text.wrap
    assert_equal text, result  # Should return unchanged
  end

  def test_wrap_without_sgr
    # wrap should not wrap plain text without SGR
    text = "plain content"
    result = text.wrap
    assert_equal text, result  # Should return unchanged
  end

  def test_wrap_empty_string
    # wrap should handle empty strings gracefully
    text = ""
    result = text.wrap
    assert_equal text, result  # Should return unchanged
  end

  def test_wrap_only_sgr
    # wrap should wrap strings containing only SGR codes
    text = "\e[31m\e[0m"
    result = text.wrap
    expected = "#{Gouache::WRAP_OPEN}#{text}#{Gouache::WRAP_CLOSE}"
    assert_equal expected, result
  end
end
