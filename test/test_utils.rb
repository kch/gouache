# frozen_string_literal: true
require_relative "test_helper"

class TestUtils < Minitest::Test
  using Gouache::RegexpWrap

  def test_regexp_wrap_module
    rx = /\d+/
    wrapped = rx.w

    assert_equal "\\A(?-mix:\\d+)\\z", wrapped.source
    assert wrapped.match?("123")
    refute wrapped.match?("abc123def")
  end

  def test_range_union_initialization_with_ranges
    union = Gouache::RangeUnion.new(30..39, 90..97)

    assert union.member?(31)
    assert union.member?(35)
    assert union.member?(91)
    assert union.member?(95)

    refute union.member?(29)
    refute union.member?(40)
    refute union.member?(89)
    refute union.member?(98)
  end

  def test_range_union_initialization_with_numeric
    union = Gouache::RangeUnion.new(5, 25)

    assert union.member?(5)
    assert union.member?(25)

    refute union.member?(4)
    refute union.member?(6)
    refute union.member?(24)
    refute union.member?(26)
  end

  def test_range_union_initialization_mixed_types
    union = Gouache::RangeUnion.new(30..39, 5, 25, 90..97)

    # Range values
    assert union.member?(31)
    assert union.member?(35)
    assert union.member?(91)
    assert union.member?(95)

    # Numeric values
    assert union.member?(5)
    assert union.member?(25)

    # Non-matches
    refute union.member?(29)
    refute union.member?(40)
    refute union.member?(6)
    refute union.member?(26)
  end

  def test_range_union_case_equality_alias
    union = Gouache::RangeUnion.new(30..39, 90..97)

    assert union === 31
    assert union === 35
    assert union === 91
    assert union === 95

    refute union === 29
    refute union === 40
    refute union === 89
    refute union === 98
  end

  def test_range_union_in_case_when
    union = Gouache::RangeUnion.new(30..39, 90..97)

    result = case 35
             when union then :matched
             else :no_match
             end
    assert_equal :matched, result

    result = case 50
             when union then :matched
             else :no_match
             end
    assert_equal :no_match, result
  end

  def test_range_union_in_case_in
    union = Gouache::RangeUnion.new(30..39, 90..97)

    result = case 35
             in ^union then :matched
             else :no_match
             end
    assert_equal :matched, result

    result = case 50
             in ^union then :matched
             else :no_match
             end
    assert_equal :no_match, result
  end

  def test_range_union_with_nested_range_union
    inner_union = Gouache::RangeUnion.new(30..32, 35..37)
    outer_union = Gouache::RangeUnion.new(inner_union, 40..42)

    # Inner union values
    assert outer_union.member?(31)
    assert outer_union.member?(36)

    # Outer range values
    assert outer_union.member?(41)

    # Non-matches
    refute outer_union.member?(33)
    refute outer_union.member?(34)
    refute outer_union.member?(43)
  end

  def test_range_exclusion_initialization
    exclusion = Gouache::RangeExclusion.new(0..10, 3..5, 8)

    # Should include values in range but not in excludes
    assert exclusion.member?(0)
    assert exclusion.member?(1)
    assert exclusion.member?(2)
    refute exclusion.member?(3)  # excluded by 3..5
    refute exclusion.member?(4)  # excluded by 3..5
    refute exclusion.member?(5)  # excluded by 3..5
    assert exclusion.member?(6)
    assert exclusion.member?(7)
    refute exclusion.member?(8)  # excluded by 8
    assert exclusion.member?(9)
    assert exclusion.member?(10)

    # Outside range
    refute exclusion.member?(-1)
    refute exclusion.member?(11)
  end

  def test_range_exclusion_case_equality_alias
    exclusion = Gouache::RangeExclusion.new(0..10, 3..5)

    assert exclusion === 2
    refute exclusion === 4
    assert exclusion === 7
  end

  def test_range_exclusion_in_case_when
    exclusion = Gouache::RangeExclusion.new(0..10, 3..5)

    result = case 2
             when exclusion then :included
             else :excluded
             end
    assert_equal :included, result

    result = case 4
             when exclusion then :included
             else :excluded
             end
    assert_equal :excluded, result
  end

  def test_range_exclusion_in_case_in
    exclusion = Gouache::RangeExclusion.new(0..10, 3..5)

    result = case 7
             in ^exclusion then :included
             else :excluded
             end
    assert_equal :included, result

    result = case 4
             in ^exclusion then :included
             else :excluded
             end
    assert_equal :excluded, result
  end

  def test_range_exclusion_with_complex_excludes
    # Test RU_SGR_NC equivalent: 0..107 excluding RU_BASIC, 38, 48
    basic_ranges = Gouache::RangeUnion.new(39, 49, 30..37, 40..47, 90..97, 100..107)
    sgr_nc = Gouache::RangeExclusion.new(0..107, basic_ranges, 38, 48)

    # Should include non-color SGR codes
    assert sgr_nc.member?(0)   # reset
    assert sgr_nc.member?(1)   # bold
    assert sgr_nc.member?(22)  # normal intensity
    assert sgr_nc.member?(50)  # between ranges
    assert sgr_nc.member?(89)  # just below bright fg

    # Should exclude basic color codes
    refute sgr_nc.member?(31)  # red fg
    refute sgr_nc.member?(42)  # green bg
    refute sgr_nc.member?(91)  # bright red fg
    refute sgr_nc.member?(102) # bright green bg
    refute sgr_nc.member?(39)  # default fg
    refute sgr_nc.member?(49)  # default bg

    # Should exclude extended color prefixes
    refute sgr_nc.member?(38)  # extended fg
    refute sgr_nc.member?(48)  # extended bg

    # Outside range
    refute sgr_nc.member?(-1)
    refute sgr_nc.member?(108)
  end

end
