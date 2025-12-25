# frozen_string_literal: true

require_relative "test_helper"

class TestEmitter < Minitest::Test
  def setup
    @gouache = Gouache.new

    # Override basic_colors to always return ANSI16 without hitting osc
    Gouache::Term.singleton_class.alias_method :basic_colors_original, :basic_colors
    Gouache::Term.singleton_class.undef_method :basic_colors
    Gouache::Term.singleton_class.define_method(:basic_colors) { Gouache::Term::ANSI16.dup.freeze }

    # Override term_seq to raise and prevent OSC calls
    Gouache::Term.singleton_class.alias_method :term_seq_original, :term_seq
    Gouache::Term.singleton_class.undef_method :term_seq
    Gouache::Term.singleton_class.define_method(:term_seq) { |*args| raise "OSC calls not allowed in tests" }

    # Reset memoized colors
    Gouache::Term.instance_variable_set(:@colors, nil)
    Gouache::Term.instance_variable_set(:@fg_color, nil)
    Gouache::Term.instance_variable_set(:@bg_color, nil)
    Gouache::Term.instance_variable_set(:@basic_colors, nil)
    # Reset class variable for color indices cache
    Gouache::Term.class_variable_set(:@@color_indices, {})

    @emitter = Gouache::Emitter.new(instance: @gouache)
  end

  def teardown
    # Restore original methods
    Gouache::Term.singleton_class.undef_method :basic_colors
    Gouache::Term.singleton_class.alias_method :basic_colors, :basic_colors_original
    Gouache::Term.singleton_class.undef_method :basic_colors_original

    Gouache::Term.singleton_class.undef_method :term_seq
    Gouache::Term.singleton_class.alias_method :term_seq, :term_seq_original
    Gouache::Term.singleton_class.undef_method :term_seq_original

    # Reset memoized colors
    Gouache::Term.instance_variable_set(:@colors, nil)
    Gouache::Term.instance_variable_set(:@fg_color, nil)
    Gouache::Term.instance_variable_set(:@bg_color, nil)
    Gouache::Term.instance_variable_set(:@basic_colors, nil)
    Gouache::Term.class_variable_set(:@@color_indices, {})
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
    assert_equal "\e[22;31;1mtext\e[0m", result
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
    assert_equal "\e[22;31;1mtext\e[0m", result
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
    assert_equal "\e[22;31;4;1mtext\e[0m", result
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
    assert_equal "\e[22;31;1mtext1\e[39mtext2\e[0m", result
  end

  def test_multiple_sgr_pushes
    @emitter.push_sgr("1")   # bold
    @emitter.push_sgr("31")  # red
    @emitter.push_sgr("4")   # underline
    @emitter << "text"

    result = @emitter.emit!
    assert_equal "\e[22;31;4;1mtext\e[0m", result
  end

  def test_scan_sgr_integration
    @emitter.push_sgr("1;31;4")  # bold red underline as string
    @emitter << "text"
    result = @emitter.emit!
    assert_equal "\e[22;31;4;1mtext\e[0m", result
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
    assert_equal "\e[22;31;1mtext\e[0m", result
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
    assert_equal "\e[22;4;1mstyled\e[0m", result
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
    expected << "\e[22;39mplain-again "

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
    assert_equal "\e[22;31;4;1mtext\e[0m", result
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
    assert_equal "\e[22;31;4;1mtext\e[0m", result
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
    assert_equal "\e[22;31;4;1mdeep\e[0m", result
  end

  def test_begin_sgr_then_close_tag_cleanup
    @emitter.open_tag(:bold)
    @emitter.begin_sgr
    @emitter.push_sgr("31")  # red in sgr block
    @emitter << "text"
    @emitter.close_tag       # should clean up open sgr block

    result = @emitter.emit!
    assert_equal "\e[22;31;1mtext\e[0m", result
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
    assert_equal "\e[22;31;1mtext\e[0m", result
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
    assert_equal "\e[22;31;4;1mtext\e[0m", result
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
    assert_equal "\e[22;31;7;4;1mcomplex\e[0m", result
  end

  def test_method_chaining_with_new_methods
    result = @emitter.open_tag(:bold).begin_sgr.push_sgr("31") << "chained"
    assert_same @emitter, result

    result = @emitter.end_sgr.close_tag
    assert_same @emitter, result

    final_result = @emitter.emit!
    assert_equal "\e[22;31;1mchained\e[0m", final_result
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

  def test_bold_dim_basic_transitions
    @emitter.open_tag(:bold)
    @emitter << "bold "
    @emitter.open_tag(:dim)
    @emitter << "bold-dim "
    @emitter.close_tag
    @emitter << "bold"

    result = @emitter.emit!
    assert_equal "\e[22;1mbold \e[1;2mbold-dim \e[22;1mbold\e[0m", result
  end

  def test_dim_bold_alternating
    @emitter.open_tag(:dim)
    @emitter << "dim "
    @emitter.open_tag(:bold)
    @emitter << "dim-bold "
    @emitter.close_tag
    @emitter << "dim"

    result = @emitter.emit!
    assert_equal "\e[22;2mdim \e[1;2mdim-bold \e[22;2mdim\e[0m", result
  end

  def test_bold_dim_with_intermediate_styles
    @emitter.open_tag(:bold)
    @emitter << "bold "
    @emitter.open_tag(:red)
    @emitter << "bold-red "
    @emitter.open_tag(:underline)
    @emitter << "bold-red-underline "
    @emitter.open_tag(:dim)
    @emitter << "bold-red-underline-dim "
    @emitter.close_tag  # close dim
    @emitter << "bold-red-underline "
    @emitter.close_tag  # close underline
    @emitter << "bold-red "
    @emitter.close_tag  # close red
    @emitter << "bold"

    result = @emitter.emit!
    assert_equal "\e[22;1mbold \e[31mbold-red \e[4mbold-red-underline \e[1;2mbold-red-underline-dim \e[22;1mbold-red-underline \e[24mbold-red \e[39mbold\e[0m", result
  end

  def test_bold_other_stuff_dim_pop_sequence
    @emitter.open_tag(:bold)
    @emitter.open_tag(:red)
    @emitter.open_tag(:italic)
    @emitter.open_tag(:underline)
    @emitter.open_tag(:dim)
    @emitter << "all-styles "

    # Pop dim
    @emitter.close_tag
    @emitter << "no-dim "

    # Pop underline
    @emitter.close_tag
    @emitter << "no-underline "

    # Pop italic
    @emitter.close_tag
    @emitter << "no-italic "

    # Pop red
    @emitter.close_tag
    @emitter << "no-red "

    # Pop bold
    @emitter.close_tag
    @emitter << "plain"

    result = @emitter.emit!
    assert_equal "\e[31;3;4;1;2mall-styles \e[22;1mno-dim \e[24mno-underline \e[23mno-italic \e[39mno-red \e[22mplain\e[0m", result
  end

  def test_bold_dim_combined_single_tag
    gouache = Gouache.new(bold_dim: [1, 2])
    emitter = Gouache::Emitter.new(instance: gouache)

    emitter.open_tag(:bold_dim)
    emitter << "combined "
    emitter.close_tag
    emitter << "plain"

    result = emitter.emit!
    assert_equal "\e[1;2mcombined \e[22mplain\e[0m", result
  end

  def test_complex_bold_dim_scenario
    @emitter.open_tag(:bold)
    @emitter.open_tag(:green)
    @emitter.open_tag(:italic)
    @emitter << "bold-green-italic "

    @emitter.open_tag(:dim)
    @emitter << "add-dim "

    @emitter.open_tag(:blue)
    @emitter << "change-to-blue "

    @emitter.open_tag(:underline)
    @emitter << "add-underline "

    # Start popping
    @emitter.close_tag  # close underline
    @emitter << "remove-underline "

    @emitter.close_tag  # close blue
    @emitter << "back-to-green "

    @emitter.close_tag  # close dim
    @emitter << "remove-dim "

    @emitter.close_tag  # close italic
    @emitter << "remove-italic "

    @emitter.close_tag  # close green
    @emitter << "remove-green "

    @emitter.close_tag  # close bold
    @emitter << "remove-bold"

    result = @emitter.emit!
    assert_equal "\e[22;32;3;1mbold-green-italic \e[1;2madd-dim \e[34mchange-to-blue \e[4madd-underline \e[24mremove-underline \e[32mback-to-green \e[22;1mremove-dim \e[23mremove-italic \e[39mremove-green \e[22mremove-bold\e[0m", result
  end

  def test_sgr_bold_dim_interactions
    @emitter.begin_sgr
    @emitter.push_sgr("1")  # bold via SGR
    @emitter << "sgr-bold "

    @emitter.open_tag(:dim)
    @emitter << "tag-dim "

    @emitter.push_sgr("31")  # red via SGR
    @emitter << "add-red "

    @emitter.close_tag  # close dim tag
    @emitter << "remove-dim "

    @emitter.end_sgr  # close SGR block
    @emitter << "plain"

    result = @emitter.emit!
    assert_equal "\e[22;1msgr-bold \e[1;2mtag-dim \e[31madd-red \e[22;39;1mremove-dim \e[22mplain\e[0m", result
  end

  def test_nested_bold_dim_tags
    @emitter.open_tag(:bold)
    @emitter.open_tag(:bold)  # nested bold
    @emitter << "double-bold "

    @emitter.open_tag(:dim)
    @emitter << "bold-bold-dim "

    @emitter.close_tag  # close dim
    @emitter << "back-to-double-bold "

    @emitter.close_tag  # close inner bold
    @emitter << "single-bold "

    @emitter.close_tag  # close outer bold
    @emitter << "plain"

    result = @emitter.emit!
    assert_equal "\e[22;1mdouble-bold \e[1;2mbold-bold-dim \e[22;1mback-to-double-bold single-bold \e[22mplain\e[0m", result
  end

  def test_bold_dim_no_text_compaction
    @emitter.open_tag(:bold)
    @emitter.open_tag(:dim)
    @emitter.close_tag
    @emitter.close_tag

    result = @emitter.emit!
    assert_equal "", result
  end

  def test_bold_dim_text_forces_sgr_flush
    @emitter.open_tag(:bold)
    # No text yet - nothing should be emitted

    @emitter.open_tag(:dim)
    # Still no text

    @emitter << "text"  # This forces SGR flush
    @emitter.close_tag
    @emitter.close_tag

    result = @emitter.emit!
    assert_equal "\e[1;2mtext\e[0m", result
  end

  def test_bold_dim_intermediate_text_flushes
    @emitter.open_tag(:bold)
    @emitter << "bold1"  # Forces initial bold SGR

    @emitter.open_tag(:dim)
    # Dim overlay causes immediate SGR change
    @emitter << "bold-dim"

    @emitter.close_tag  # Pop dim
    @emitter << "bold2"  # Forces SGR for back to bold

    result = @emitter.emit!
    assert_equal "\e[22;1mbold1\e[1;2mbold-dim\e[22;1mbold2\e[0m", result
  end

  def test_bold_dim_no_text_between_operations
    @emitter.open_tag(:bold)
    @emitter.open_tag(:red)
    @emitter.open_tag(:dim)
    @emitter.open_tag(:underline)
    # No text added yet

    @emitter.close_tag  # close underline
    @emitter.close_tag  # close dim
    @emitter.close_tag  # close red
    @emitter.close_tag  # close bold

    result = @emitter.emit!
    assert_equal "", result  # Should be optimized away
  end

  def test_mixed_sgr_tag_bold_dim_flush_behavior
    @emitter.begin_sgr
    @emitter.push_sgr("1")  # bold via SGR
    # No text yet

    @emitter.open_tag(:dim)
    # Still no text - operations should be queued

    @emitter.push_sgr("31")  # red via SGR
    @emitter << "first"  # This flushes all pending SGR

    @emitter.end_sgr
    @emitter << "second"  # This flushes the SGR pop

    @emitter.close_tag
    @emitter << "third"   # This flushes the tag pop

    result = @emitter.emit!
    assert_equal "\e[31;1;2mfirstsecond\e[22;39;1mthird\e[0m", result
  end

  def test_bold_dim_empty_tag_optimization
    @emitter.open_tag(:bold)
    @emitter.open_tag(:dim)
    @emitter.open_tag(:red)
    # Open several tags but add no text
    @emitter.close_tag
    @emitter.close_tag
    @emitter.close_tag

    # Then add a completely different style
    @emitter.open_tag(:underline)
    @emitter << "underline-only"
    @emitter.close_tag

    result = @emitter.emit!
    assert_equal "\e[4munderline-only\e[0m", result
  end

  def test_bold_dim_partial_flush_scenarios
    @emitter.open_tag(:bold)
    @emitter << "bold "  # Flushes bold

    @emitter.open_tag(:dim)
    # Dim immediately changes output

    @emitter.open_tag(:red)
    @emitter << "bold-dim-red "  # Flushes dim+red overlay

    @emitter.close_tag  # Close red
    @emitter.close_tag  # Close dim - should trigger reset+reapply
    @emitter << "back-to-bold"

    result = @emitter.emit!
    assert_equal "\e[22;1mbold \e[31;1;2mbold-dim-red \e[22;39;1mback-to-bold\e[0m", result
  end

  def test_flush_uses_fallback_truecolor
    Gouache::Term.stub :color_level, :truecolor do
      gouache = Gouache.new(test_color: Gouache::Color.rgb(255, 128, 64))
      emitter = Gouache::Emitter.new(instance: gouache)
      emitter.open_tag(:test_color)
      emitter << "text"
      emitter.close_tag
      result = emitter.emit!
      assert_equal "\e[38;2;255;128;64mtext\e[0m", result
    end
  end

  def test_flush_uses_fallback_256
    Gouache::Term.stub :color_level, :_256 do
      gouache = Gouache.new(test_color: Gouache::Color.rgb(255, 0, 0))
      emitter = Gouache::Emitter.new(instance: gouache)
      emitter.open_tag(:test_color)
      emitter << "text"
      emitter.close_tag
      result = emitter.emit!
      assert_match(/\e\[38;5;\d+mtext\e\[0m/, result)
    end
  end

  def test_flush_uses_fallback_basic
    Gouache::Term.stub :color_level, :basic do
      gouache = Gouache.new(test_color: Gouache::Color.rgb(255, 0, 0))
      emitter = Gouache::Emitter.new(instance: gouache)
      emitter.open_tag(:test_color)
      emitter << "text"
      emitter.close_tag
      result = emitter.emit!
      assert_equal "\e[91mtext\e[0m", result
    end
  end

  def test_flush_uses_fallback_basic_background
    Gouache::Term.stub :color_level, :basic do
      gouache = Gouache.new(test_color: Gouache::Color.on_rgb(255, 0, 0))
      emitter = Gouache::Emitter.new(instance: gouache)
      emitter.open_tag(:test_color)
      emitter << "text"
      emitter.close_tag
      result = emitter.emit!
      assert_equal "\e[101mtext\e[0m", result
    end
  end

  def test_merge_color_fallback_truecolor
    Gouache::Term.stub :color_level, :truecolor do
      gouache = Gouache.new(test_color: [Gouache::Color.rgb(255, 128, 64), Gouache::Color.cube(5, 0, 0), Gouache::Color.sgr(31)])
      emitter = Gouache::Emitter.new(instance: gouache)
      emitter.open_tag(:test_color)
      emitter << "text"
      emitter.close_tag
      result = emitter.emit!
      assert_equal "\e[38;2;255;128;64mtext\e[0m", result
    end
  end

  def test_merge_color_fallback_256
    Gouache::Term.stub :color_level, :_256 do
      gouache = Gouache.new(test_color: [Gouache::Color.rgb(255, 128, 64), Gouache::Color.cube(5, 0, 0), Gouache::Color.sgr(31)])
      emitter = Gouache::Emitter.new(instance: gouache)
      emitter.open_tag(:test_color)
      emitter << "text"
      emitter.close_tag
      result = emitter.emit!
      assert_equal "\e[38;5;196mtext\e[0m", result
    end
  end

  def test_merge_color_fallback_basic
    Gouache::Term.stub :color_level, :basic do
      gouache = Gouache.new(test_color: [Gouache::Color.rgb(255, 128, 64), Gouache::Color.cube(5, 0, 0), Gouache::Color.sgr(31)])
      emitter = Gouache::Emitter.new(instance: gouache)
      emitter.open_tag(:test_color)
      emitter << "text"
      emitter.close_tag
      result = emitter.emit!
      assert_equal "\e[31mtext\e[0m", result
    end
  end

  def test_merge_color_fallback_mixed_roles
    Gouache::Term.stub :color_level, :basic do
      gouache = Gouache.new(test_color: [
        Gouache::Color.rgb(255, 0, 0),
        Gouache::Color.on_cube(0, 5, 0),
        Gouache::Color.sgr(31),
        Gouache::Color.sgr(42)
      ])
      emitter = Gouache::Emitter.new(instance: gouache)
      emitter.open_tag(:test_color)
      emitter << "text"
      emitter.close_tag
      result = emitter.emit!
      assert_equal "\e[31;42mtext\e[0m", result
    end
  end
end
