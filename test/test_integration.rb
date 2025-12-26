# frozen_string_literal: true

require_relative "test_helper"

class TestIntegration < Minitest::Test
  using Gouache::Wrap

  def setup
    super
    @go = Gouache.new(enabled: true)
    @C = Gouache::Color  # Convenience alias like in usage example
  end

  # Test the provided usage example
  def test_underline_color_usage_example
    go = Gouache.new(ul: [:underline, @C.over_rgb(255, 0, 0)])
    result = go[:blue, :ul, 'test text']
    expected = "\e[34;4;58;2;255;0;0mtest text\e[0m"
    assert_equal expected, result
  end

  # Test underline color with various combinations
  def test_underline_color_combinations
    # Basic underline color only
    go = Gouache.new(red_ul: @C.over_rgb(255, 0, 0))
    result = go[:red_ul, "text"]
    assert_equal "\e[58;2;255;0;0mtext\e[0m", result

    # Underline color with regular underline
    go = Gouache.new(combo: [:underline, @C.over_rgb(0, 255, 0)])
    result = go[:combo, "text"]
    assert_equal "\e[4;58;2;0;255;0mtext\e[0m", result

    # Underline color with double underline
    go = Gouache.new(double_combo: [:double_underline, @C.over_rgb(255, 255, 0)])
    result = go[:double_combo, "text"]
    assert_equal "\e[21;58;2;255;255;0mtext\e[0m", result

    # Underline color with foreground and background
    result = @go[:red, :on_blue, @C.over_rgb(255, 255, 0), "colorful"]
    assert_equal "\e[31;44;58;2;255;255;0mcolorful\e[0m", result
  end

  # Test full color spectrum integration
  def test_full_color_spectrum_integration
    # Foreground, background, and underline colors together
    fg = @C.rgb(255, 100, 50)     # orange foreground
    bg = @C.on_rgb(50, 50, 200)   # blue background
    ul = @C.over_rgb(0, 255, 100) # green underline

    go = Gouache.new(triple: [fg, bg, ul])
    result = go[:triple, "rainbow"]
    expected = "\e[38;2;255;100;50;48;2;50;50;200;58;2;0;255;100mrainbow\e[0m"
    assert_equal expected, result
  end

  # Test underline color fallback scenarios
  def test_underline_color_fallback_integration
    # Test basic fallback converts to 256-color format
    ul_color = @C.over_rgb(200, 50, 75)  # Complex color
    go = Gouache.new(ul_style: ul_color)

    # Simulate basic terminal
    original_level = Gouache::Term.color_level
    begin
      Gouache::Term.color_level = :basic
      result = go[:ul_style, "fallback_test"]
      # Should use 58;5;n format where n is 0-15
      assert_match(/\e\[58;5;([0-9]|1[0-5])mfallback_test\e\[0m/, result)
    ensure
      Gouache::Term.color_level = original_level
    end
  end

  # Test complex stylesheet with underline colors
  def test_complex_stylesheet_with_underline_colors
    complex_styles = {
      error: [:bold, :red, @C.over_rgb(255, 0, 0)],        # red underline
      warning: [:italic, :yellow, @C.over_rgb(255, 165, 0)], # orange underline
      success: [:green, @C.over_rgb(0, 255, 0)],           # green underline
      info: [:blue, :underline, @C.over_rgb(135, 206, 235)] # sky blue underline with regular underline
    }

    go = Gouache.new(styles: complex_styles)

    # Test error style
    result = go[:error, "Critical error"]
    expected = "\e[22;31;58;2;255;0;0;1mCritical error\e[0m"
    assert_equal expected, result

    # Test warning with both italic and underline color
    result = go[:warning, "Warning message"]
    expected = "\e[33;3;58;2;255;165;0mWarning message\e[0m"
    assert_equal expected, result

    # Test info with both regular underline and underline color
    result = go[:info, "Information"]
    expected = "\e[34;4;58;2;135;206;235mInformation\e[0m"
    assert_equal expected, result
  end

  # Test double underline with underline color combinations
  def test_double_underline_with_underline_color
    # Test double underline only
    result = @go[:double_underline, "double underlined"]
    assert_equal "\e[21mdouble underlined\e[0m", result

    # Test double underline with underline color
    ul_color = @C.over_rgb(128, 0, 255)  # purple underline
    go = Gouache.new(purple_double: [:double_underline, ul_color])
    result = go[:purple_double, "double with color"]
    expected = "\e[21;58;2;128;0;255mdouble with color\e[0m"
    assert_equal expected, result

    # Test mixed underline types with color
    go = Gouache.new(mixed: [:underline, :double_underline, @C.over_rgb(255, 165, 0)])
    result = go[:mixed, "mixed underlines"]
    # Double underline should override regular underline
    expected = "\e[21;58;2;255;165;0mmixed underlines\e[0m"
    assert_equal expected, result

    # Test underline color affects both regular and double underline
    go = Gouache.new(
      regular: [:underline, @C.over_rgb(255, 0, 0)],
      double: [:double_underline, @C.over_rgb(255, 0, 0)]
    )

    regular_result = go[:regular, "regular"]
    double_result = go[:double, "double"]

    assert_includes regular_result, "4;58;2;255;0;0"    # regular underline with color
    assert_includes double_result, "21;58;2;255;0;0"    # double underline with color
  end

  # Test layered composition with underline colors
  def test_layered_composition_with_underline_colors
    # Test incremental styling changes
    result = @go["Start ", :bold, "bold ", @C.over_rgb(255, 0, 0), "with underline color ", :italic, "and italic"]
    expected = "Start \e[22;1mbold \e[58;2;255;0;0mwith underline color \e[3mand italic\e[0m"
    assert_equal expected, result
  end

  # Test underline color with merge functionality
  def test_underline_color_merge_integration
    # Test merging different color representations for underline
    rgb_ul = @C.over_rgb(255, 128, 64)
    cube_ul = @C.over_cube(5, 2, 1)
    sgr_ul = @C.sgr("58;5;196")

    # Merge all representations
    merged_ul = rgb_ul.merge(cube_ul).merge(sgr_ul)
    go = Gouache.new(merged: merged_ul)

    result = go[:merged, "merged underline"]
    expected = "\e[58;2;255;128;64mmerged underline\e[0m"
    assert_equal expected, result

    # Test fallback behavior with merged color
    original_level = Gouache::Term.color_level
    begin
      Gouache::Term.color_level = :_256
      result = go[:merged, "256 fallback"]
      expected = "\e[58;5;209m256 fallback\e[0m"  # cube(5,2,1) = 209
      assert_equal expected, result
    ensure
      Gouache::Term.color_level = original_level
    end
  end

  # Test underline colors in nested structures
  def test_underline_colors_in_nested_structures
    ul1 = @C.over_rgb(255, 0, 0)    # red
    ul2 = @C.over_rgb(0, 255, 0)    # green
    ul3 = @C.over_rgb(0, 0, 255)    # blue

    result = @go[
      "Start",
      [:bold, ul1, "red underline",
        [:italic, ul2, "green underline",
          [:dim, ul3, "blue underline"]
        ]
      ]
    ]

    expected = "Start\e[22;58;2;255;0;0;1mred underline\e[3;58;2;0;255;0mgreen underline\e[58;2;0;0;255;1;2mblue underline\e[0m"
    assert_equal expected, result
  end

  # Test disabled gouache with underline colors
  def test_disabled_gouache_with_underline_colors
    disabled_go = Gouache.new(enabled: false, ul_style: @C.over_rgb(255, 0, 0))
    result = disabled_go[:ul_style, "no colors"]
    assert_equal "no colors", result
  end

  # Test underline colors with effects
  def test_underline_colors_with_effects
    # Stub OSC calls to avoid test environment restrictions
    Gouache::Term.stub(:fg_color, [205, 0, 0]) do
      effect = proc do |top, under|
        # Copy foreground color to underline color position
        if under&.fg
          top.underline_color = under.fg.change_role(58)
        end
      end

      go = Gouache.new(effect_style: [effect, :red])
      result = go[:effect_style, "dynamic underline"]

      # Should have red foreground and red-derived underline color
      assert_includes result, "\e[31"        # red foreground
      assert_includes result, "58;2;"        # RGB underline color
      assert_includes result, "dynamic underline"
    end
  end

  # Test all constructor methods integration
  def test_all_constructor_methods_integration
    styles = {
      rgb_ul: @C.over_rgb(255, 100, 50),
      hex_ul: @C.over_hex("#ff6432"),
      cube_ul: @C.over_cube(5, 2, 1),
      gray_ul: @C.over_gray(15),
      oklch_ul: @C.over_oklch(0.7, 0.15, 30),
      sgr_ul: @C.sgr("58;5;196")
    }

    go = Gouache.new(styles: styles)

    # Test each constructor produces underline color
    styles.each do |style_name, _|
      result = go[style_name, "test"]
      assert_match(/\e\[58[;,]/, result, "#{style_name} should produce underline color escape")
    end

    # Test they can be combined
    result = go[:rgb_ul, :hex_ul, :cube_ul, "multiple"]
    # Last one wins due to incremental layer building
    assert_match(/58;5;209/, result)  # cube(5,2,1) = 209
  end

  # Test underline color role changes
  def test_underline_color_role_changes
    ul_color = @C.over_rgb(200, 100, 50)

    # Convert underline to foreground
    fg_color = ul_color.change_role(38)
    assert_equal 38, fg_color.role
    assert_equal [200, 100, 50], fg_color.rgb

    # Convert underline to background
    bg_color = ul_color.change_role(48)
    assert_equal 48, bg_color.role
    assert_equal [200, 100, 50], bg_color.rgb

    # Test in actual usage
    go = Gouache.new(
      ul_style: ul_color,
      fg_style: fg_color,
      bg_style: bg_color
    )

    ul_result = go[:ul_style, "underline"]
    fg_result = go[:fg_style, "foreground"]
    bg_result = go[:bg_style, "background"]

    assert_includes ul_result, "58;2;200;100;50"
    assert_includes fg_result, "38;2;200;100;50"
    assert_includes bg_result, "48;2;200;100;50"
  end

  # Test underline color with block syntax
  def test_underline_color_with_block_syntax
    go = Gouache.new(ul: @C.over_rgb(255, 0, 255))

    result = go[] do |g|
      g << "Before "
      g.ul("underlined text")
      g << " after"
    end

    expected = "Before \e[58;2;255;0;255munderlined text\e[59m after\e[0m"
    assert_equal expected, result
  end

  # Test underline color persistence across method calls
  def test_underline_color_persistence
    go = Gouache.new

    # Test that underline color doesn't interfere with other colors
    result1 = go[@C.rgb(255, 0, 0), "red text"]
    result2 = go[@C.over_rgb(0, 255, 0), "green underline"]
    result3 = go[@C.on_rgb(0, 0, 255), "blue background"]

    assert_includes result1, "38;2;255;0;0"
    assert_includes result2, "58;2;0;255;0"
    assert_includes result3, "48;2;0;0;255"

    # Each should be independent
    refute_includes result1, "58;"
    refute_includes result1, "48;"
    refute_includes result2, "38;"
    refute_includes result2, "48;"
    refute_includes result3, "38;"
    refute_includes result3, "58;"
  end

  # Test real-world logging scenario
  def test_real_world_logging_scenario
    # Simulate a logging system with different severity levels
    logger_styles = {
      debug: [@C.rgb(128, 128, 128), @C.over_rgb(200, 200, 200)],  # gray with light gray underline
      info: [@C.rgb(0, 150, 255), @C.over_rgb(135, 206, 235)],    # blue with sky blue underline
      warn: [@C.rgb(255, 165, 0), @C.over_rgb(255, 140, 0), :bold], # orange with dark orange underline, bold
      error: [@C.rgb(255, 69, 0), @C.over_rgb(220, 20, 60), :bold, :underline], # red-orange with crimson underline, bold + underline
      fatal: [@C.rgb(255, 255, 255), @C.on_rgb(139, 0, 0), @C.over_rgb(255, 0, 0), :bold, :blink] # white on dark red with red underline, bold + blink
    }

    go = Gouache.new(styles: logger_styles)

    # Test each log level
    debug_result = go[:debug, "[DEBUG] Application started"]
    info_result = go[:info, "[INFO] User logged in"]
    warn_result = go[:warn, "[WARN] Deprecated API used"]
    error_result = go[:error, "[ERROR] Database connection failed"]
    fatal_result = go[:fatal, "[FATAL] System crash imminent"]

    # Verify each contains appropriate escape sequences
    assert_includes debug_result, "38;2;128;128;128"    # gray foreground
    assert_includes debug_result, "58;2;200;200;200"    # light gray underline

    assert_includes info_result, "38;2;0;150;255"       # blue foreground
    assert_includes info_result, "58;2;135;206;235"     # sky blue underline

    assert_includes warn_result, "38;2;255;165;0"       # orange foreground
    assert_includes warn_result, "58;2;255;140;0"       # dark orange underline
    assert_includes warn_result, "\e[22;"               # bold reset prefix

    assert_includes error_result, "38;2;255;69;0"       # red-orange foreground
    assert_includes error_result, "58;2;220;20;60"      # crimson underline
    assert_includes error_result, "1m"                  # bold
    assert_includes error_result, "4;"                  # underline

    assert_includes fatal_result, "38;2;255;255;255"    # white foreground
    assert_includes fatal_result, "48;2;139;0;0"        # dark red background
    assert_includes fatal_result, "58;2;255;0;0"        # red underline
    assert_includes fatal_result, "5;"                  # blink
  end

  # Test performance with many underline colors
  def test_performance_with_many_underline_colors
    # Create many different underline colors
    colors = 100.times.map do |i|
      @C.over_rgb(i * 2 % 256, (i * 3) % 256, (i * 5) % 256)
    end

    go = Gouache.new

    # Test that many colors don't cause performance issues
    start_time = Time.now

    result = go[*colors, "many colors"]

    end_time = Time.now
    duration = end_time - start_time

    # Should complete in reasonable time (< 0.1 seconds)
    assert_operator duration, :<, 0.1, "Many colors processing took too long: #{duration}s"

    # Should contain the last color's underline sequence
    expected_r = (99 * 2) % 256
    expected_g = (99 * 3) % 256
    expected_b = (99 * 5) % 256
    assert_includes result, "58;2;#{expected_r};#{expected_g};#{expected_b}"
  end

  # Test underline color with repaint functionality
  def test_underline_color_repaint_integration
    # Test that repaint correctly handles underline color sequences
    original = "Plain text \e[31mred\e[0m and \e[58;2;255;0;0mred underline\e[0m"

    go = Gouache.new(new_style: [@C.rgb(0, 255, 0), @C.over_rgb(0, 0, 255)])
    result = go.repaint(original)

    # Should contain the original sequences (repaint without style replacement)
    assert_includes result, "31m"              # original red
    assert_includes result, "58;2;255;0;0"     # original underline color
    assert_includes result, "Plain text"       # preserve text
  end

  # Test edge cases and error conditions
  def test_edge_cases_and_error_conditions
    # Test with nil underline color (should be ignored gracefully)
    go = Gouache.new(mixed: [:bold, nil, @C.over_rgb(255, 0, 0)])
    result = go[:mixed, "test"]
    assert_includes result, "58;2;255;0;0"
    assert_includes result, "1m"  # bold

    # Test empty underline color merge
    empty_colors = []
    fg, bg, ul = @C.merge(*empty_colors)
    assert_nil fg
    assert_nil bg
    assert_nil ul

    # Test mixed role merge with underline
    mixed = [
      @C.rgb(255, 0, 0),       # fg
      @C.on_rgb(0, 255, 0),    # bg
      @C.over_rgb(0, 0, 255),  # ul
      @C.rgb(128, 128, 128)    # another fg
    ]

    fg, bg, ul = @C.merge(*mixed)
    assert_equal 38, fg.role
    assert_equal 48, bg.role
    assert_equal 58, ul.role
  end

  # Complex pipeline integration tests
  def test_complex_builder_chain_with_blocks
    # Test complex chaining with nested blocks and mixed syntax
    result = @go.red.bold { |x|
      x.blue("nested blue ")
      x << "plain red bold "
      x.italic { |y|
        y.green("green italic ")
        y.underline("underlined green italic")
      }
    }

    expected = "\e[22;34;1mnested blue " +
               "\e[31mplain red bold " +
               "\e[32;3mgreen italic " +
               "\e[31;4munderlined green italic" +
               "\e[0m"
    assert_equal expected, result
  end

  def test_mixed_bracket_and_builder_syntax
    # Mix bracket syntax with builder methods
    ul_color = @C.over_rgb(255, 165, 0)
    result = @go.red { |x|
      x["start "]
      x[:blue, "bracket blue "]
      x.italic("builder italic ")
      x[ul_color, "orange underline"]
    }

    # Just verify it contains the expected elements
    assert result.include?("start")
    assert result.include?("bracket blue")
    assert result.include?("builder italic")
    assert result.include?("orange underline")
    assert result.include?("58;2;255;165;0")  # underline color
  end

  def test_complex_array_nesting_with_variables
    # Test complex array structures with variables
    fg_style = @C.rgb(255, 100, 50)
    bg_style = @C.on_rgb(50, 50, 200)
    ul_style = @C.over_rgb(0, 255, 100)

    nested_array = [:italic, "italic text ", [:strike, "struck italic"]]

    result = @go[
      "prefix ",
      fg_style,
      bg_style,
      ul_style,
      [:bold, "bold colored ", nested_array],
      " suffix"
    ]

    expected = "prefix " +
               "\e[22;38;2;255;100;50;48;2;50;50;200;58;2;0;255;100;1mbold colored " +
               "\e[3mitalic text " +
               "\e[9mstruck italic" +
               "\e[22;23;29m suffix" +
               "\e[0m"
    assert_equal expected, result
  end

  def test_call_method_variations
    # Test different call method patterns
    styles = {
      highlight: [:bold, @C.rgb(255, 255, 0), @C.on_rgb(255, 0, 255)],
      error: [:red, @C.over_rgb(255, 0, 0), :underline]
    }
    go = Gouache.new(styles: styles)

    # Call with block only
    result1 = go.() { |x|
      x.highlight("highlighted ")
      x.error("error text")
    }

    # Call with content and block
    result2 = go.("prefix ") { |x|
      x[:green, "green "]
      x << "appended"
    }

    # Call method variation
    result3 = go.() {
      highlight("built ")
      error("content")
    }

    # Verify key styling elements are present
    assert result1.include?("highlighted")
    assert result1.include?("error text")
    assert result1.include?("38;2;255;255;0")  # yellow highlight
    assert result1.include?("58;2;255;0;0")    # red underline

    assert result2.include?("prefix")
    assert result2.include?("green")
    assert result2.include?("appended")

    assert result3.include?("built")
    assert result3.include?("content")
    assert result3.include?("38;2;255;255;0")  # yellow highlight
  end

  def test_arity_detection_with_complex_styling
    # Test arity detection with complex styling combinations
    complex_styles = {
      banner: [:bold, :yellow, @C.on_rgb(128, 0, 128), @C.over_rgb(255, 255, 255)],
      code: [:dim, @C.rgb(200, 200, 200), @C.on_rgb(40, 40, 40)]
    }
    go = Gouache.new(styles: complex_styles)

    # Arity 0 - no parameters
    result_0 = go.banner {
      code("function() { return 42; }")
      self << " // JavaScript"
    }

    # Arity 1 - it parameter
    result_1 = go.banner { |it|
      it.code("def method\n  42\nend")
      it << " # Ruby"
    }

    # Arity 2 - explicit x parameter
    result_2 = go.banner { |x|
      x.code("fn main() { println!(\"42\"); }")
      x << " // Rust"
    }

    expected_0 = "\e[38;2;200;200;200;48;2;40;40;40;58;2;255;255;255;1;2mfunction() { return 42; }" +
                 "\e[22;33;48;2;128;0;128;1m // JavaScript" +
                 "\e[0m"

    expected_1 = "\e[38;2;200;200;200;48;2;40;40;40;58;2;255;255;255;1;2mdef method\n  42\nend" +
                 "\e[22;33;48;2;128;0;128;1m # Ruby" +
                 "\e[0m"

    expected_2 = "\e[38;2;200;200;200;48;2;40;40;40;58;2;255;255;255;1;2mfn main() { println!(\"42\"); }" +
                 "\e[22;33;48;2;128;0;128;1m // Rust" +
                 "\e[0m"

    assert_equal expected_0, result_0
    assert_equal expected_1, result_1
    assert_equal expected_2, result_2
  end

  def test_custom_base_styles_with_complex_overrides
    # Test custom base styles with complex declarations
    custom_base = [:bold, @C.rgb(253, 204, 0), @C.on_rgb(83, 0, 0)]

    go = Gouache.new(
      _base: custom_base,
      gold: [:italic, @C.rgb(255, 215, 0)],
      silver: [@C.rgb(192, 192, 192), @C.over_rgb(128, 128, 128)]
    )

    result = go["default "] { |x|
      x.gold("golden ") {
        silver("silver overlay")
      }
    }

    expected = "\e[22;38;2;253;204;0;48;2;83;0;0;1mdefault " +
               "\e[38;2;255;215;0;3mgolden " +
               "\e[38;2;192;192;192;58;2;128;128;128msilver overlay" +
               "\e[0m"
    assert_equal expected, result
  end

  def test_deeply_nested_with_all_color_types
    # Test deep nesting with all color representation types
    styles = {
      level1: [@C.sgr(31)],                          # basic SGR
      level2: [@C.sgr("38;5;196")],                  # 256-color SGR
      level3: [@C.rgb(0, 255, 128)],                 # RGB
      level4: [@C.on_cube(2, 4, 1)],                 # 256-color cube background
      level5: [@C.over_gray(18)],                    # grayscale underline
      level6: [@C.oklch(0.6, 0.2, 270)]             # OKLCH
    }
    go = Gouache.new(styles: styles)

    result = go.level1 { |l1|
      l1["L1 "]
      l1.level2 { |l2|
        l2["L2 "]
        l2.level3 { |l3|
          l3["L3 "]
          l3.level4 { |l4|
            l4["L4 "]
            l4.level5 { |l5|
              l5["L5 "]
              l5.level6("L6")
            }
          }
        }
      }
    }

    # This creates a deeply nested structure with incremental styling
    assert result.start_with?("\e[31mL1 ")
    assert result.include?("L6")
    assert result.end_with?("\e[0m")
    assert result.include?("\e[38;5;196m")  # level2 256-color
    assert result.include?("\e[38;2;0;255;128m")  # level3 RGB
    assert result.include?("58;5;250")  # level5 grayscale underline (232+18)
  end

  def test_real_world_terminal_ui_simulation
    # Simulate a complex terminal UI with status bars, menus, etc
    ui_styles = {
      statusbar: [:bold, @C.rgb(255, 255, 255), @C.on_rgb(0, 120, 215)],
      menu_item: [@C.rgb(220, 220, 220)],
      menu_selected: [:bold, @C.rgb(255, 255, 255), @C.on_rgb(0, 95, 175)],
      error_highlight: [:bold, @C.rgb(255, 255, 255), @C.on_rgb(196, 49, 75), @C.over_rgb(255, 0, 0)],
      success_indicator: [@C.rgb(0, 200, 0), @C.over_rgb(0, 255, 0)],
      warning_badge: [:italic, @C.rgb(255, 193, 7), @C.over_rgb(255, 152, 0)]
    }
    go = Gouache.new(styles: ui_styles)

    # Simulate a status bar with multiple sections
    status_result = go.statusbar { |status|
      status["File: main.rb "]
      status.success_indicator("✓ Saved ")
      status.warning_badge("⚠ 3 warnings")
    }

    # Simulate a menu with selection
    menu_result = go.() { |x|
      x.menu_item("1. Open File")
      x << "\n"
      x.menu_selected("2. Save File")  # Currently selected
      x << "\n"
      x.menu_item("3. Exit")
      x << "\n"
      x.error_highlight("Error: Permission denied")
    }

    # Verify complex escape sequences are generated
    assert status_result.include?("38;2;255;255;255")  # statusbar white text
    assert status_result.include?("48;2;0;120;215")    # statusbar blue background
    assert status_result.include?("38;2;0;200;0")      # success green text
    assert status_result.include?("58;2;0;255;0")      # success green underline

    assert menu_result.include?("38;2;220;220;220")    # menu_item gray
    assert menu_result.include?("48;2;0;95;175")       # menu_selected blue background
    assert menu_result.include?("58;2;255;0;0")        # error red underline
  end

  # Test using refinement with complex styling - requires separate class
end

class TestIntegrationWithRefinement < Minitest::Test
  @@go = Gouache.new(
    highlight: [:bold, Gouache::Color.rgb(255, 255, 0), Gouache::Color.on_rgb(255, 0, 255)],
    code: [:dim, Gouache::Color.rgb(200, 200, 200), Gouache::Color.on_rgb(40, 40, 40)]
  )
  using @@go.refinement

  def test_string_refinement_with_complex_styling
    # Test that strings get styling methods via refinement
    result = "hello".highlight + " world".code

    # Should contain styling escape sequences
    assert result.include?("hello")
    assert result.include?(" world")
    assert result.include?("38;2;255;255;0")  # yellow text
    assert result.include?("48;2;255;0;255")  # magenta background
    assert result.include?("38;2;200;200;200") # gray text
    assert result.include?("48;2;40;40;40")    # dark background
  end
end
