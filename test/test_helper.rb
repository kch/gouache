# frozen_string_literal: true

require_relative "../lib/gouache"
require "minitest/autorun"

module MethodHelpers
  def self.replace_method(target, name, &definition)
    target.alias_method :"#{name}_original", name
    target.undef_method name
    target.define_method(name, &definition)
  end

  def self.restore_method(target, name)
    target.undef_method name
    target.alias_method name, :"#{name}_original"
    target.undef_method :"#{name}_original"
  end
end

# Disable OSC calls globally for all tests
MethodHelpers.replace_method(Gouache::Term.singleton_class, :term_seq) { |*args| raise "OSC calls not allowed in tests" }

module TestTermHelpers

  def setup_term_isolation
    # Override basic_colors to always return ANSI16 without hitting osc
    MethodHelpers.replace_method(Gouache::Term.singleton_class, :basic_colors) { Gouache::Term::ANSI16.dup.freeze }

    # Reset all memoized colors
    Gouache::Term.instance_variable_set(:@colors, nil)
    Gouache::Term.instance_variable_set(:@fg_color, nil)
    Gouache::Term.instance_variable_set(:@bg_color, nil)
    Gouache::Term.instance_variable_set(:@basic_colors, nil)
    Gouache::Term.class_variable_set(:@@color_indices, {})
  end

  def teardown_term_isolation
    # Restore original methods
    MethodHelpers.restore_method(Gouache::Term.singleton_class, :basic_colors)

    # Reset all memoized colors
    Gouache::Term.instance_variable_set(:@colors, nil)
    Gouache::Term.instance_variable_set(:@fg_color, nil)
    Gouache::Term.instance_variable_set(:@bg_color, nil)
    Gouache::Term.instance_variable_set(:@basic_colors, nil)
    Gouache::Term.class_variable_set(:@@color_indices, {})
  end
end

module Minitest
  module Assertions
    alias_method :old_mu_pp_for_diff, :mu_pp_for_diff

    # render the colored string directly to term, along with the inspect version
    def mu_pp_for_diff(obj)
      return old_mu_pp_for_diff obj unless String === obj && obj =~ /\e/
      # escape \e's that are not SGR; let the SGR render
      [ obj.gsub(/\e(?!\[[\d;]*?m|\\)/, "\\e") + "\e[0m",
        obj.inspect].join("\n")
    end
  end
end
