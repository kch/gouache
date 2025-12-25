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

end
