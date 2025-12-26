# frozen_string_literal: true

require_relative "lib/gouache/version"

Gem::Specification.new do |spec|
  spec.name          = "gouache"
  spec.version       = Gouache::VERSION
  spec.authors       = ["Caio Chassot"]
  spec.email         = ["dev@caiochassot.com"]

  spec.summary       = "A flexible terminal color library for Ruby"
  spec.description   = "Gouache provides a powerful and flexible way to add colors and styling to terminal output in Ruby applications. It supports multiple color formats (RGB, OKLCH, 256-color, basic), fallback modes, custom stylesheets, refinements for String, and advanced features like color shifting and effects."
  spec.homepage      = "https://github.com/kch/gouache"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kch/gouache"
  # spec.metadata["changelog_uri"] = "https://github.com/kch/gouache/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "matrix", "~> 0.4.2"

  # Development dependencies
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
