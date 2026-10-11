# frozen_string_literal: true

require_relative "lib/solargraph/dr_talon/version"

Gem::Specification.new do |spec|
  spec.name = "solargraph-dr_talon"
  spec.version = Solargraph::DrTalon::VERSION
  spec.authors = ["Austin Simmons"]
  spec.email = ["austin_simmons@fastmail.com"]

  spec.summary = "Solargraph plugin providing Talon game framework completion for DragonRuby"
  spec.description = "Teaches Solargraph the metaprogramming in the Talon game framework for DragonRuby: " \
    "Talon::Concern mixins (class_methods, included), the prop and state DSLs, and on_* lifecycle hook blocks, " \
    "so LSP editors get autocomplete, hover and go-to-definition in Talon games."
  spec.homepage = "https://github.com/asimmons91/solargraph-dr_talon"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .standard.yml rakelib/ mise.toml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Solargraph's node processor and convention internals change between minor
  # releases, so bump this deliberately after re-running tests.
  spec.add_dependency "solargraph", "~> 0.61.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
