source "https://rubygems.org"

# Specify your gem's dependencies in activerecord-spanner.gemspec
gemspec

gem "activerecord", ENV.fetch("AR_VERSION", "~> 6.1.6.1")
gem "minitest", "~> 5.20.0"
gem "minitest-rg", "~> 5.3.0"
gem "pry", "~> 0.13.0"
gem "pry-byebug", "~> 3.9.0"

# Required for samples and testing.
install_if -> { ENV.fetch("AR_VERSION", "~> 6.1.6.1").dup.to_s.sub!("~>", "").strip < "7.1.0" && !ENV["SKIP_COMPOSITE_PK"] } do
  gem "composite_primary_keys"
end

# Required for samples
gem "docker-api"
gem "sinatra-activerecord"
