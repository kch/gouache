# frozen_string_literal: true

require_relative "test_helper"

class TestEmitter < Minitest::Test
  def setup
    @gouache = Gouache.new
    @emitter = Gouache::Emitter.new(instance: @gouache)
  end

  def test_initialize_with_gouache_instance
    gouache = Gouache.new(styles: { red: 31 })
    emitter = Gouache::Emitter.new(instance: gouache)
    assert_kind_of Gouache::Emitter, emitter
  end

  def test_open_tag_applies_style
    @emitter.open_tag(:bold)
    @emitter << "text"
    result = @emitter.emit!
    assert_equal "\e[22;1mtext\e[0m", result
  end

  def test_close_tag_no_overlap_with_bold
    @emitter.open_tag(:bold)
    @emitter.close_tag
    @emitter << "text"
    result = @emitter.emit!
    # Bold still emits SGR because 22 cancels dim (special case)
    assert_equal "text", result
  end

  def test_close_tag_no_overlap_simple_style
    @emitter.open_tag(:yellow)
    @emitter.close_tag
    @emitter << "text"
    result = @emitter.emit!
    # No SGR should be emitted since yellow was opened and closed without overlap
    assert_equal "text", result
  end

  def test_open_tag_with_text
    result = (@emitter.open_tag(:bold) << "text").emit!
    assert_equal "\e[22;1mtext\e[0m", result
  end

  def test_multiple_tags_with_text
    @emitter.open_tag(:bold)
    @emitter.open_tag(:red)
    @emitter << "text"
    @emitter.close_tag
    @emitter.close_tag

    result = @emitter.emit!
    assert_equal "\e[31;22;1mtext\e[0m", result
  end

  def test_push_sgr_single_code
    @emitter.push_sgr("31") # red
    @emitter << "text"
    result = @emitter.emit!
    assert_equal "\e[31mtext\e[0m", result
  end

  def test_push_sgr_multiple_codes
    @emitter.push_sgr("1;31") # bold red
    @emitter << "text"
    result = @emitter.emit!
    assert_equal "\e[31;22;1mtext\e[0m", result
  end

  def test_pop_sgr_until_tag
    @emitter.open_tag(:bold)    # tagged layer
    @emitter.push_sgr("31")     # untagged sgr
    @emitter.push_sgr("4")      # untagged sgr
    @emitter.pop_sgr           # should pop until tag
    @emitter << "text"
    result = @emitter.emit!
    # Should have bold but not the red/underline that were popped
    assert_equal "\e[22;1mtext\e[0m", result
  end

  def test_chaining_returns_self
    result = @emitter.open_tag(:bold).push_sgr("31") << "text"
    assert_same @emitter, result

    result = @emitter.pop_sgr.close_tag
    assert_same @emitter, result
  end

  def test_operations_without_text_emit_nothing
    @emitter.open_tag(:bold)
    @emitter.close_tag
    result = @emitter.emit!
    assert_equal "", result
  end

  def test_emit_freezes_output
    result = @emitter.emit!
    assert result.frozen?
  end

  def test_emit_returns_frozen_if_already_frozen
    first_result = @emitter.emit!
    second_result = @emitter.emit!
    assert_same first_result, second_result
  end

  def test_to_s_calls_emit
    @emitter.open_tag(:bold)
    @emitter << "text"

    result1 = @emitter.to_s
    result2 = @emitter.emit!

    assert_equal result1, result2
  end

  def test_empty_emitter_emit
    result = @emitter.emit!
    assert_equal "", result
  end

  def test_emit_adds_reset_when_sgr_was_used
    @emitter.open_tag(:bold)
    @emitter << "text"
    result = @emitter.emit!

    assert_includes result, "\e[0m"
  end

  def test_emit_no_reset_when_no_sgr
    @emitter << "plain text"
    result = @emitter.emit!

    refute_includes result, "\e[0m"
    assert_equal "plain text", result
  end

  def test_multiple_operations_before_text
    @emitter.open_tag(:bold)
    @emitter.push_sgr("31")
    @emitter.push_sgr("4")
    @emitter << "text"

    result = @emitter.emit!
    assert_equal "\e[31;4;22;1mtext\e[0m", result
  end

  def test_empty_text_ignored
    @emitter.open_tag(:bold)
    @emitter << ""
    @emitter << "text"

    result = @emitter.emit!
    assert_equal "\e[22;1mtext\e[0m", result
  end

  def test_custom_styles_via_gouache
    gouache = Gouache.new(styles: { custom: 35 })
    emitter = Gouache::Emitter.new(instance: gouache)

    emitter.open_tag(:custom)
    emitter << "text"
    result = emitter.emit!

    assert_equal "\e[35mtext\e[0m", result
  end

  def test_nonexistent_tag_returns_empty_layer
    @emitter.open_tag(:nonexistent)
    @emitter << "text"
    result = @emitter.emit!

    # Should just have text with no SGR
    assert_equal "text", result
  end

  def test_complex_tag_sgr_interaction
    @emitter.open_tag(:bold)      # tagged layer
    @emitter.push_sgr("31")     # red sgr
    @emitter << "text1"
    @emitter.pop_sgr             # pop until tag (removes red)
    @emitter << "text2"
    @emitter.close_tag           # close bold tag

    result = @emitter.emit!
    assert_equal "\e[31;22;1mtext1\e[39mtext2\e[0m", result
  end

  def test_multiple_sgr_pushes
    @emitter.push_sgr("1")   # bold
    @emitter.push_sgr("31")  # red
    @emitter.push_sgr("4")   # underline
    @emitter << "text"

    result = @emitter.emit!
    assert_equal "\e[31;4;22;1mtext\e[0m", result
  end

  def test_scan_sgr_integration
    @emitter.push_sgr("1;31;4")  # bold red underline as string
    @emitter << "text"
    result = @emitter.emit!
    assert_equal "\e[31;4;22;1mtext\e[0m", result
  end

  def test_operations_work_with_text
    @emitter.open_tag(:bold)
    @emitter << "text"

    result = @emitter.emit!
    assert_equal "\e[22;1mtext\e[0m", result
  end

  def test_layered_tag_behavior
    @emitter.open_tag(:bold)
    @emitter.open_tag(:red)
    @emitter << "text"
    @emitter.close_tag  # close red
    @emitter.close_tag  # close bold

    result = @emitter.emit!
    assert_equal "\e[31;22;1mtext\e[0m", result
  end

  def test_sgr_without_tag_pops_to_base
    @emitter.push_sgr("1")   # bold
    @emitter.push_sgr("31")  # red
    @emitter.push_sgr("4")   # underline
    @emitter.pop_sgr      # should pop all since no tags

    result = @emitter.emit!
    # Should be empty or just reset
    refute_includes result, "\e[22;1m"
    refute_includes result, "\e[31m"
    refute_includes result, "\e[4m"
  end

  def test_mixed_operations_order
    @emitter.open_tag(:bold)
    @emitter.push_sgr("31")
    @emitter.pop_sgr
    @emitter.open_tag(:underline)
    @emitter << "styled"
    @emitter.close_tag
    @emitter.close_tag

    result = @emitter.emit!
    assert_equal "\e[4;22;1mstyled\e[0m", result
    assert result.frozen?
  end

  def test_comprehensive_stress_test
    expected = +""

    # Text before any styles
    @emitter << "plain "
    expected << "plain "

    # Open bold tag
    @emitter.open_tag(:bold)
    @emitter << "bold "
    expected << "\e[22;1mbold "

    # Open red tag
    @emitter.open_tag(:red)
    @emitter << "bold-red "
    expected << "\e[31mbold-red "

    # Push underline SGR
    @emitter.push_sgr("4")
    @emitter << "bold-red-underline "
    expected << "\e[4mbold-red-underline "

    # Push inverse SGR
    @emitter.push_sgr("7")
    @emitter << "bold-red-underline-inverse "
    expected << "\e[7mbold-red-underline-inverse "

    # Pop inverse SGR (must pop before tag ops)
    @emitter.pop_sgr
    # Pop underline SGR
    @emitter.pop_sgr
    @emitter << "bold-red "
    expected << "\e[27;24mbold-red "

    # Close red tag
    @emitter.close_tag
    @emitter << "bold "
    expected << "\e[39mbold "

    # Open green tag
    @emitter.open_tag(:green)
    @emitter << "bold-green "
    expected << "\e[32mbold-green "

    # Close green and bold
    @emitter.close_tag
    @emitter.close_tag
    @emitter << "plain-again "
    expected << "\e[39;22mplain-again "

    # Reopen after everything closed
    @emitter.open_tag(:cyan)
    @emitter.push_sgr("3")
    @emitter << "cyan-italic "
    expected << "\e[36;3mcyan-italic "

    # Pop SGR before opening new tag
    @emitter.pop_sgr
    @emitter.open_tag(:magenta)
    @emitter << "magenta "
    expected << "\e[35;23mmagenta "

    # Close everything
    @emitter.close_tag
    @emitter.close_tag
    @emitter << "final"
    expected << "\e[39mfinal"

    # Add final reset
    expected << "\e[0m"

    result = @emitter.emit!
    assert_equal expected, result
  end

  def test_cannot_open_tag_with_sgr_on_stack
    @emitter.open_tag(:bold)
    @emitter.push_sgr("31")
    assert_raises(RuntimeError, "open_tag called with sgr on top of stack") do
      @emitter.open_tag(:red)
    end
  end

  def test_cannot_pop_sgr_with_tag_on_stack
    @emitter.open_tag(:bold)
    @emitter.open_tag(:red)
    assert_raises(RuntimeError, "pop_sgr called with open tag on top of stack") do
      @emitter.pop_sgr
    end
  end

  def test_cannot_pop_sgr_on_empty
    assert_raises(RuntimeError, "pop_sgr called on empty stack") do
      @emitter.pop_sgr
    end
  end

  def test_close_tag_over_sgr
    @emitter.open_tag(:bold)
    @emitter.push_sgr("31")
    assert_raises(RuntimeError, "close_tag called without open tag on top of stack") do
      @emitter.close_tag
    end
  end

  def test_close_tag_without_open_tag
    assert_raises(RuntimeError, "close_tag called without open tag on top of stack") do
      @emitter.close_tag
    end
  end
end
