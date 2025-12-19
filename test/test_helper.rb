# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/gouache"

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
