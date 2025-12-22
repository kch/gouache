# frozen_string_literal: true

require_relative "test_helper"

class TestSafeEmitSgr < Minitest::Test
  using Gouache::Wrap

  def setup
    @go = Gouache.new
  end

  def test_string_without_sgr_passes_through
    result = @go["plain text"]
    assert_equal "plain text", result
  end

  def test_string_with_manual_sgr_isolated
    # Manual SGR codes in string should be contained and not affect following tags
    text_with_sgr = "before \e[31mred\e[0m after"
    result = @go[text_with_sgr, :bold, "bold"]
    expected = "before \e[31mred\e[39m after\e[22;1mbold\e[0m"  # 0→39 transformation, bold gets reset prefix
    assert_equal expected, result
  end

  def test_multiple_manual_sgr_codes_contained
    # Multiple SGR sequences should all be processed independently
    text_with_multiple_sgr = "text \e[1mbold\e[22m \e[31mred\e[39m end"
    result = @go[text_with_multiple_sgr, :underline, "underlined"]
    expected = "text \e[22;1mbold\e[22m \e[31mred\e[39m end\e[4munderlined\e[0m"  # bold gets reset prefix
    assert_equal expected, result
  end

  def test_manual_sgr_does_not_leak_to_tags
    # Valid SGR should be preserved and not affect subsequent tags
    text_with_sgr = "start \e[31mred text"
    result = @go[text_with_sgr, :bold, "should be bold not red"]
    expected = "start \e[31mred text\e[39;22;1mshould be bold not red\e[0m"  # 31 preserved, reset to default, then bold applied
    assert_equal expected, result
  end

  def test_wrapped_content_isolated
    # Wrapped content should have SGR codes isolated within the wrap boundary
    content_to_wrap = "wrapped \e[31mred\e[0m content"
    result = @go["before #{content_to_wrap.wrap} after", :bold, "bold"]
    expected = "before wrapped \e[31mred\e[39m content after\e[22;1mbold\e[0m"  # wrap isolates SGR
    assert_equal expected, result
  end

  def test_nested_wrapped_content
    # Multiple levels of wrapping should work correctly
    inner_content = "inner \e[1mbold\e[22m"
    outer_content = "outer #{inner_content.wrap} text"  # wrap inner first
    result = @go["start #{outer_content.wrap} end"]      # then wrap outer
    expected = "start outer inner \e[22;1mbold\e[22m text end\e[0m"
    assert_equal expected, result
  end

  def test_builder_method_with_manual_sgr
    # Builder blocks should handle manual SGR codes in appended text
    result = @go.red { |r|
      r << "plain "
      r << "text with \e[31mmanual red\e[0m "  # manual SGR in appended text
      r.bold("bold text")                      # then a tagged section
    }
    expected = "\e[31mplain text with manual red\e[39m \e[31;22;1mbold text\e[0m"
    assert_equal expected, result
  end

  def test_multiple_manual_resets_in_sequence
    # Multiple manual reset codes should be properly handled
    result = @go.blue { |b|
      b << "start \e[31mred\e[0m middle \e[32mgreen\e[0m end"
      b.bold("final")
    }
    expected = "\e[34mstart \e[31mred\e[39m middle \e[32mgreen\e[39m end\e[34;22;1mfinal\e[0m"
    assert_equal expected, result
  end

  def test_nested_manual_sgr_with_builder_tags
    # Manual SGR nested within builder tag contexts
    result = @go.red { |r|
      r.bold { |b|
        b << "bold with \e[33myellow\e[0m inside"
      }
      r << " after bold"
    }
    expected = "\e[31;22;1mbold with \e[33myellow\e[39;22m inside\e[31m after bold\e[0m"
    assert_equal expected, result
  end

  def test_manual_reset_before_builder_method
    # Manual reset immediately before builder method call
    result = @go.green { |g|
      g << "text \e[31mred\e[0m"  # manual reset
      g.italic("italic")          # should start fresh from green context
    }
    expected = "\e[32mtext \e[31mred\e[32;3mitalic\e[0m"
    assert_equal expected, result
  end

  def test_partial_manual_sgr_codes
    # Manual SGR codes that don't fully reset (like 39, 49, etc.)
    result = @go.red { |r|
      r << "red \e[32mgreen\e[39m back"  # 39 resets foreground only
      r.bold("bold")
    }
    expected = "\e[31mred \e[32mgreen\e[39m back\e[31;22;1mbold\e[0m"
    assert_equal expected, result
  end

  def test_mixed_sgr_and_wrapping_complex
    content1 = "wrap1 \e[32mgreen\e[39m"
    content2 = "wrap2 \e[4munderline\e[24m"
    middle_text = " middle \e[31mmanual red\e[39m "

    result = @go[
      "start ",
      :bold, "bold #{content1.wrap} continue",
      middle_text,
      :italic, "italic #{content2.wrap} end"
    ]

    expected = "start " +
               "\e[22;1mbold wrap1 \e[32mgreen\e[39m continue" +
               " middle \e[31mmanual red\e[39m " +
               "\e[3mitalic wrap2 \e[4munderline\e[24m end" +
               "\e[0m"
    assert_equal expected, result
  end

  def test_empty_wrapped_content
    empty_content = ""
    result = @go["before #{empty_content.wrap} after", :bold, "bold"]
    expected = "before  after\e[22;1mbold\e[0m"
    assert_equal expected, result
  end

  def test_unwrapped_string_with_sgr
    text_with_sgr = "plain \e[31mred\e[39m text"
    result = @go[text_with_sgr, :bold, "bold"]
    expected = "plain \e[31mred\e[39m text\e[22;1mbold\e[0m"
    assert_equal expected, result
  end

  def test_unwrapped_with_wrapped_inside
    content_to_wrap = "wrapped \e[4munderline\e[24m"
    text_after = " after \e[31mred\e[39m end"
    result = @go["before #{content_to_wrap.wrap}#{text_after}"]
    expected = "before wrapped \e[4munderline\e[24m after \e[31mred\e[39m end\e[0m"
    assert_equal expected, result
  end
  def test_malformed_sgr_incomplete_escape
    # Incomplete SGR sequences (missing 'm') should pass through unchanged
    malformed_text = "text \e[31 incomplete and \e[4 another"
    result = @go[malformed_text, :bold, "bold"]
    expected = "text \e[31 incomplete and \e[4 another\e[22;1mbold\e[0m"  # passed through as-is
    assert_equal expected, result
  end

  def test_complex_sgr_sequences
    # Multi-code SGR sequences should be processed with proper ordering
    complex_sgr = "start \e[1;31;4mbold red underline\e[0m end"
    result = @go[complex_sgr, :italic, "italic"]
    expected = "start \e[31;4;22;1mbold red underline\e[39;24;22m end\e[3mitalic\e[0m"  # bold/dim at end
    assert_equal expected, result
  end

  def test_non_sgr_escape_sequences
    # Non-SGR escape sequences (cursor, clear, etc.) should pass through unchanged
    cursor_text = "line1\e[2Jclear\e[H home"
    result = @go[cursor_text, :bold, "bold"]
    expected = "line1\e[2Jclear\e[H home\e[22;1mbold\e[0m"  # non-SGR escapes preserved
    assert_equal expected, result
  end

  def test_deeply_nested_wrapping
    # Deep nesting of wrapped content should flatten correctly
    level3 = "level3 \e[35mmagenta\e[39m"
    level2 = "level2 #{level3.wrap} text"      # wrap level3 inside level2
    level1 = "level1 #{level2.wrap} text"      # wrap level2 inside level1
    result = @go["start #{level1.wrap} end"]   # wrap level1 at top
    expected = "start level1 level2 level3 \e[35mmagenta\e[39m text text end\e[0m"
    assert_equal expected, result
  end

  def test_empty_wraps_in_middle
    # Empty wrapped content should not interfere with processing
    empty1 = ""
    empty2 = ""
    content = "middle \e[32mgreen\e[39m"
    result = @go["start #{empty1.wrap} #{content.wrap} #{empty2.wrap} end"]  # mix empty + content
    expected = "start  middle \e[32mgreen\e[39m  end\e[0m"  # empty wraps become spaces
    assert_equal expected, result
  end

  def test_mismatched_wrap_markers_extra_close
    # Extra wrap close markers should be treated as literal text
    text_with_extra = "text#{Gouache::WRAP_CLOSE}extra"
    result = @go[text_with_extra, :bold, "bold"]
    expected = "text#{Gouache::WRAP_CLOSE}extra\e[22;1mbold\e[0m"  # close marker as literal
    assert_equal expected, result
  end

  def test_mismatched_wrap_markers_extra_open
    # Extra wrap open markers should be treated as literal text
    text_with_extra = "text#{Gouache::WRAP_OPEN}extra"
    result = @go[text_with_extra, :bold, "bold"]
    expected = "text#{Gouache::WRAP_OPEN}extra\e[22;1mbold\e[0m"  # open marker as literal
    assert_equal expected, result
  end

  def test_builder_chaining_with_wrapped_content
    # Builder chaining should work with wrapped content inside tag arguments
    content_with_sgr = "wrapped \e[31mred\e[39m content"
    result = @go.bold { |b|
      b << "before "
      b.italic("italic #{content_with_sgr.wrap} text")  # wrap inside tag argument
      b << " after"
    }
    expected = "\e[22;1mbefore \e[3mitalic wrapped \e[31mred\e[39m content text\e[23m after\e[0m"
    assert_equal expected, result
  end

  def test_multiple_wrap_levels_with_builder_tags
    # Multiple wrap levels combined with builder tags should work correctly
    inner = "inner \e[4munderline\e[24m"
    middle = "middle #{inner.wrap} text"        # first wrap level
    result = @go.red { |r|
      r.bold("bold #{middle.wrap} content")     # second wrap level inside builder
    }
    expected = "\e[31;22;1mbold middle inner \e[4munderline\e[24m text content\e[0m"
    assert_equal expected, result
  end

  def test_wrap_markers_at_string_start
    # Strings with wrap markers at start should be processed correctly
    content = "\e[33myellow\e[39m start"
    # Manually create string starting with wrap marker
    wrapped_start = "#{Gouache::WRAP_OPEN}#{content}#{Gouache::WRAP_CLOSE}rest"
    result = @go[wrapped_start, :bold, "bold"]
    expected = "\e[33myellow\e[39m startrest\e[22;1mbold\e[0m"  # wrapped content extracted
    assert_equal expected, result
  end

  def test_wrap_markers_at_string_end
    # Strings with wrap markers at end should be processed correctly
    content = "end \e[33myellow\e[39m"
    # Manually create string ending with wrap marker
    wrapped_end = "start#{Gouache::WRAP_OPEN}#{content}#{Gouache::WRAP_CLOSE}"
    result = @go[wrapped_end, :bold, "bold"]
    expected = "startend \e[33myellow\e[39;22;1mbold\e[0m"  # wrapped content extracted
    assert_equal expected, result
  end

  def test_complex_interpolation_multiple_variables
    var1 = "first \e[31mred\e[39m"
    var2 = "second \e[32mgreen\e[39m"
    var3 = "third \e[33myellow\e[39m"
    manual_sgr = " manual \e[34mblue\e[39m "

    result = @go[
      "start #{var1.wrap} middle",
      manual_sgr,
      :bold, "bold #{var2.wrap} content #{var3.wrap} end"
    ]

    expected = "start first \e[31mred\e[39m middle manual \e[34mblue\e[39m " +
               "\e[22;1mbold second \e[32mgreen\e[39m content third \e[33myellow\e[39m end\e[0m"
    assert_equal expected, result
  end

  def test_class_wrap_method
    # Class method Gouache.wrap should work in interpolations
    content_with_sgr = "class wrap \e[31mred\e[39m test"
    result = @go["before #{Gouache.wrap content_with_sgr} after", :bold, "bold"]
    expected = "before class wrap \e[31mred\e[39m test after\e[22;1mbold\e[0m"
    assert_equal expected, result
  end

  def test_class_embed_alias
    # Class method Gouache.embed (alias for wrap) should work in interpolations
    content_with_sgr = "class embed \e[32mgreen\e[39m test"
    result = @go["before #{Gouache.embed content_with_sgr} after", :bold, "bold"]
    expected = "before class embed \e[32mgreen\e[39m test after\e[22;1mbold\e[0m"
    assert_equal expected, result
  end

  def test_instance_wrap_method
    # Instance method @go.wrap should work in interpolations
    content_with_sgr = "instance wrap \e[33myellow\e[39m test"
    result = @go["before #{@go.wrap content_with_sgr} after", :bold, "bold"]
    expected = "before instance wrap \e[33myellow\e[39m test after\e[22;1mbold\e[0m"
    assert_equal expected, result
  end

  def test_instance_embed_alias
    # Instance method @go.embed (alias for wrap) should work in interpolations
    content_with_sgr = "instance embed \e[34mblue\e[39m test"
    result = @go["before #{@go.embed content_with_sgr} after", :bold, "bold"]
    expected = "before instance embed \e[34mblue\e[39m test after\e[22;1mbold\e[0m"
    assert_equal expected, result
  end

  def test_mixed_class_instance_wrap_methods
    # Mixing class and instance wrap/embed methods should work together
    content1 = "class \e[35mmagenta\e[39m"
    content2 = "instance \e[36mcyan\e[39m"

    result = @go[
      "start #{Gouache.wrap content1} middle",    # class method
      :bold, "bold #{@go.embed content2} end"     # instance method (alias)
    ]

    expected = "start class \e[35mmagenta\e[39m middle" +
               "\e[22;1mbold instance \e[36mcyan\e[39m end\e[0m"
    assert_equal expected, result
  end
end
