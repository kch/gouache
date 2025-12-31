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

  def test_gouache_wrap_class_method
    # Gouache.wrap should work without refinement
    text = "content \e[31mred\e[39m text"
    result = Gouache.wrap(text)
    expected = "#{Gouache::WRAP_OPEN}#{text}#{Gouache::WRAP_CLOSE}"
    assert_equal expected, result
  end

  def test_gouache_wrap_plain_text
    # Gouache.wrap should not wrap plain text
    text = "plain content"
    result = Gouache.wrap(text)
    assert_equal text, result
  end

  def test_gouache_instance_wrap
    # Gouache instance .wrap method
    go = Gouache.new
    text = "content \e[31mred\e[39m text"
    result = go.wrap(text)
    expected = "#{Gouache::WRAP_OPEN}#{text}#{Gouache::WRAP_CLOSE}"
    assert_equal expected, result
  end

  def test_nested_sgr_wrap_vs_no_wrap_comparison
    # Compare wrap vs no-wrap behavior in single test to verify wrap solves the problem
    go = Gouache.new

    # WITHOUT wrap: nested interpolation breaks SGR sequences
    inner_no_wrap = go.green("green")
    outer_no_wrap = go.blue.bold("blue #{inner_no_wrap} bold")
    result_no_wrap = go.red("xx #{outer_no_wrap} xx")

    # WITH wrap: nested styling preserved with markers
    inner_with_wrap = Gouache.wrap(go.green("green"))
    outer_with_wrap = Gouache.wrap(go.blue.bold("blue #{inner_with_wrap} bold"))
    result_with_wrap = "xx #{outer_with_wrap} xx"

    # Key difference: wrap should preserve nested color structure
    # No wrap: green resets kill outer blue bold styling
    assert result_no_wrap.include?("\e[32mgreen\e[22;39m")  # green followed by reset to default

    # With wrap: markers preserve styling boundaries
    assert result_with_wrap.include?(Gouache::WRAP_OPEN)
    assert result_with_wrap.include?(Gouache::WRAP_CLOSE)
    assert result_with_wrap.include?("\e[32mgreen")

    # Verify wrap maintains color context better than no-wrap
    refute_equal result_no_wrap, result_with_wrap
  end

  def test_nested_sgr_with_wrap_and_repaint_clean_output
    # Reproduce user example: repaint removes markers and fixes SGR
    go = Gouache.new

    # With wrap then repaint: clean final output
    inner_wrapped = Gouache.wrap(go.green("green"))
    outer_wrapped = Gouache.wrap(go.blue.bold("blue #{inner_wrapped} bold"))
    wrapped_result = "xx #{outer_wrapped} xx"
    final_result = go.repaint(wrapped_result)

    expected_clean = "xx \e[34;1mblue \e[32mgreen\e[34m bold\e[22;39m xx\e[0m"
    assert_equal expected_clean, final_result

    # Should not contain wrap markers
    refute final_result.include?(Gouache::WRAP_OPEN)
    refute final_result.include?(Gouache::WRAP_CLOSE)
  end

  def test_wrap_manual_vs_gouache_builder_equivalence
    # Compare manual SGR string vs Gouache builder - should produce identical results after repaint
    go = Gouache.new

    # Manual SGR string approach with wrap
    manual_inner = "\e[32mgreen\e[39m"
    wrapped_manual_inner = Gouache.wrap(manual_inner)
    manual_outer = "\e[34;1mblue #{wrapped_manual_inner} bold\e[22;39m"
    wrapped_manual_outer = Gouache.wrap(manual_outer)
    manual_wrapped = "xx #{wrapped_manual_outer} xx"

    # Gouache builder approach that should match
    builder_inner = go[:green, "green"]
    wrapped_builder_inner = Gouache.wrap(builder_inner)
    builder_outer = go[:blue, :bold, "blue #{wrapped_builder_inner} bold"]
    wrapped_builder_outer = Gouache.wrap(builder_outer)
    builder_wrapped = "xx #{wrapped_builder_outer} xx"

    # Repaint both to clear wrap markers
    manual_result = go.repaint(manual_wrapped)
    builder_result = go.repaint(builder_wrapped)

    # After repaint, both approaches should produce identical clean output
    assert_equal manual_result, builder_result

    # Both should not contain wrap markers after repaint
    refute manual_result.include?(Gouache::WRAP_OPEN)
    refute builder_result.include?(Gouache::WRAP_OPEN)
  end
end
