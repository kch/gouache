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

  def test_end_sgr_closes_sgr_block
    @emitter.open_tag(:bold)    # tagged layer
    @emitter.begin_sgr          # start sgr block
    @emitter.push_sgr("31")     # red in sgr block
    @emitter.push_sgr("4")      # underline in sgr block
    @emitter.end_sgr            # close sgr block
    @emitter << "text"
    result = @emitter.emit!
    # Should have bold but not the red/underline from closed sgr block
    assert_equal "\e[22;1mtext\e[0m", result
  end

  def test_chaining_returns_self
    result = @emitter.open_tag(:bold).begin_sgr.push_sgr("31") << "text"
    assert_same @emitter, result

    result = @emitter.end_sgr.close_tag
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

    assert_equal "\e[22;1mtext\e[0m", result
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
    @emitter.begin_sgr            # start sgr block
    @emitter.push_sgr("31")       # red sgr
    @emitter << "text1"
    @emitter.end_sgr              # end sgr block (removes red)
    @emitter << "text2"
    @emitter.close_tag            # close bold tag

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

  def test_sgr_without_tag_ends_cleanly
    @emitter.begin_sgr       # start sgr block
    @emitter.push_sgr("1")   # bold
    @emitter.push_sgr("31")  # red
    @emitter.push_sgr("4")   # underline
    @emitter.end_sgr         # end sgr block

    result = @emitter.emit!
    # Should be empty since no text was added
    assert_equal "", result
  end

  def test_mixed_operations_order
    @emitter.open_tag(:bold)
    @emitter.begin_sgr
    @emitter.push_sgr("31")
    @emitter.end_sgr
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
    @emitter.begin_sgr
    @emitter.push_sgr("4")
    @emitter << "bold-red-underline "
    expected << "\e[4mbold-red-underline "

    # Push inverse SGR
    @emitter.push_sgr("7")
    @emitter << "bold-red-underline-inverse "
    expected << "\e[7mbold-red-underline-inverse "

    # End SGR block containing inverse and underline
    @emitter.begin_sgr
    @emitter.push_sgr("7")
    @emitter.push_sgr("4")
    @emitter.end_sgr
    @emitter << "bold-red "
    expected << "bold-red "

    # Close red tag
    @emitter.close_tag
    @emitter << "bold "
    expected << "\e[39;27;24mbold "

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
    @emitter.begin_sgr
    @emitter.push_sgr("3")
    @emitter << "cyan-italic "
    expected << "\e[36;3mcyan-italic "

    # End SGR before opening new tag
    @emitter.end_sgr
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

  def test_open_tag_with_sgr_overlays_styles
    @emitter.open_tag(:bold)
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red
    @emitter.open_tag(:underline)  # should work now
    @emitter << "text"
    result = @emitter.emit!
    assert_equal "\e[31;4;22;1mtext\e[0m", result
  end

  def test_close_tag_closes_sgr_blocks
    @emitter.open_tag(:bold)
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red in sgr block
    @emitter.begin_sgr
    @emitter.push_sgr("4")   # underline in nested sgr block
    @emitter << "text"
    @emitter.close_tag       # should close all sgr blocks inside
    result = @emitter.emit!
    assert_equal "\e[31;4;22;1mtext\e[0m", result
  end

  def test_begin_sgr_creates_new_block
    @emitter.begin_sgr
    @emitter.push_sgr("31")
    @emitter << "red "
    @emitter.end_sgr
    @emitter << "normal"
    result = @emitter.emit!
    assert_equal "\e[31mred \e[39mnormal\e[0m", result
  end

  def test_end_sgr_noop_when_no_block
    @emitter.end_sgr  # should not raise
    @emitter << "text"
    result = @emitter.emit!
    assert_equal "text", result
  end

  def test_end_sgr_restores_previous_sgr_state
    # Test with different codes to avoid optimization
    @emitter.push_sgr("4")     # underline (direct push)
    @emitter.push_sgr("31")    # red (direct push)
    @emitter << "before-block "

    @emitter.begin_sgr         # start block
    @emitter.push_sgr("7")     # inverse (in block)
    @emitter.push_sgr("32")    # green (in block, should override red)
    @emitter << "in-block "

    @emitter.end_sgr           # end block - should restore underline+red
    @emitter << "after-block"

    result = @emitter.emit!
    # Should restore the original underline+red state after end_sgr
    assert_equal "\e[31;4mbefore-block \e[32;7min-block \e[31;27mafter-block\e[0m", result
  end

  def test_close_tag_without_open_tag
    assert_raises(RuntimeError, "attempted to close tag without open tag") do
      @emitter.close_tag
    end
  end

  def test_nested_sgr_blocks
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red
    @emitter << "outer "

    @emitter.begin_sgr       # nested block
    @emitter.push_sgr("4")   # underline
    @emitter << "inner "
    @emitter.end_sgr         # close nested block

    @emitter << "outer-again "
    @emitter.end_sgr         # close outer block
    @emitter << "normal"

    result = @emitter.emit!
    assert_equal "\e[31mouter \e[4minner \e[24mouter-again \e[39mnormal\e[0m", result
  end

  def test_multiple_nested_sgr_blocks
    @emitter.begin_sgr
    @emitter.push_sgr("1")   # bold
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red
    @emitter.begin_sgr
    @emitter.push_sgr("4")   # underline
    @emitter << "deep"
    @emitter.end_sgr         # close underline block
    @emitter.end_sgr         # close red block
    @emitter.end_sgr         # close bold block

    result = @emitter.emit!
    assert_equal "\e[31;4;22;1mdeep\e[0m", result
  end

  def test_begin_sgr_then_close_tag_cleanup
    @emitter.open_tag(:bold)
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red in sgr block
    @emitter << "text"
    @emitter.close_tag       # should clean up open sgr block

    result = @emitter.emit!
    assert_equal "\e[31;22;1mtext\e[0m", result
  end

  def test_multiple_begin_sgr_without_end_sgr
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red
    @emitter.begin_sgr       # second block without closing first
    @emitter.push_sgr("4")   # underline
    @emitter << "text"
    @emitter.end_sgr         # close only the last block
    @emitter << "more"       # need text after to see reset codes

    result = @emitter.emit!
    assert_equal "\e[31;4mtext\e[24mmore\e[0m", result
  end

  def test_push_sgr_behavior_inside_vs_outside_blocks
    # Outside block
    @emitter.push_sgr("31")  # red (direct)
    @emitter << "direct "

    # Inside block
    @emitter.begin_sgr
    @emitter.push_sgr("4")   # underline (in block)
    @emitter << "in-block "
    @emitter.end_sgr

    @emitter << "after-block"

    result = @emitter.emit!
    assert_equal "\e[31mdirect \e[4min-block \e[24mafter-block\e[0m", result
  end

  def test_tags_opened_inside_sgr_blocks
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red
    @emitter.open_tag(:bold) # tag inside sgr block
    @emitter << "text"
    @emitter.close_tag
    @emitter.end_sgr

    result = @emitter.emit!
    assert_equal "\e[31;22;1mtext\e[0m", result
  end

  def test_sgr_blocks_inside_nested_tags
    @emitter.open_tag(:bold)
    @emitter.open_tag(:red)
    @emitter.begin_sgr
    @emitter.push_sgr("4")   # underline in sgr block
    @emitter << "text"
    @emitter.end_sgr
    @emitter.close_tag
    @emitter.close_tag

    result = @emitter.emit!
    assert_equal "\e[31;4;22;1mtext\e[0m", result
  end

  def test_complex_tag_sgr_block_interleaving
    @emitter.open_tag(:bold)
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red
    @emitter.open_tag(:underline)
    @emitter.push_sgr("7")   # inverse
    @emitter << "complex"
    @emitter.close_tag       # close underline
    @emitter.end_sgr         # close sgr block
    @emitter.close_tag       # close bold

    result = @emitter.emit!
    assert_equal "\e[31;7;4;22;1mcomplex\e[0m", result
  end

  def test_method_chaining_with_new_methods
    result = @emitter.open_tag(:bold).begin_sgr.push_sgr("31") << "chained"
    assert_same @emitter, result

    result = @emitter.end_sgr.close_tag
    assert_same @emitter, result

    final_result = @emitter.emit!
    assert_equal "\e[31;22;1mchained\e[0m", final_result
  end

  def test_unmatched_end_sgr_is_noop
    @emitter.end_sgr         # no matching begin_sgr
    @emitter << "text"
    @emitter.end_sgr         # another unmatched end_sgr

    result = @emitter.emit!
    assert_equal "text", result
  end

  def test_empty_sgr_blocks
    @emitter.begin_sgr
    @emitter.end_sgr         # empty block, no content
    @emitter << "text"

    result = @emitter.emit!
    assert_equal "text", result
  end

  def test_sgr_blocks_with_no_text_between_operations
    @emitter.begin_sgr
    @emitter.push_sgr("31")
    @emitter.push_sgr("4")
    @emitter.begin_sgr
    @emitter.push_sgr("7")
    @emitter.end_sgr
    @emitter.end_sgr
    @emitter << "final"

    result = @emitter.emit!
    assert_equal "final", result
  end
end
