lib = File.expand_path "lib", __dir__
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib
require "activerecord_spanner_adapter/version"

Gem::Specification.new do |spec|
  spec.name          = "activerecord-spanner-adapter"
  spec.version       = ActiveRecordSpannerAdapter::VERSION
  spec.authors       = ["Google LLC"]
  spec.email         = ["cloud-spanner-developers@googlegroups.com"]

  spec.summary       = %q{Rails ActiveRecord connector for Google Spanner Database}
  spec.description   = %q{Rails ActiveRecord connector for Google Spanner Database}
  spec.homepage      = "https://github.com/googleapis/ruby-spanner-activerecord"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir File.expand_path(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match %r{^(test|spec|features)/} }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename f }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"

  spec.add_dependency "google-cloud-spanner", "~> 2.18"
  spec.add_runtime_dependency "activerecord", [">= 6.0.0", "< 7.2"]

  spec.add_development_dependency "autotest-suffix", "~> 1.1"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "google-style", "~> 1.24.0"
  spec.add_development_dependency "minitest", "~> 5.10"
  spec.add_development_dependency "minitest-autotest", "~> 1.0"
  spec.add_development_dependency "minitest-focus", "~> 1.1"
  spec.add_development_dependency "minitest-rg", "~> 5.2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "redcarpet", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.9"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "yard-doctest", "~> 0.1.13"
end
