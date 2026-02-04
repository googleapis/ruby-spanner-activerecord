source "https://rubygems.org"

# Specify your gem's dependencies in activerecord-spanner.gemspec
gemspec

ar_version = ENV.fetch("AR_VERSION", "~> 7.1.0")
gem "activerecord", ar_version
gem "ostruct"
gem "minitest", "~> 5.27.0"
gem "minitest-rg", "~> 5.4.0"
gem "pry", "~> 0.14.2"
gem "pry-byebug", "~> 3.11.0"
gem "mutex_m"
# Add sqlite3 for testing for compatibility with other adapters.
gem 'sqlite3'

# Required for samples and testing.
install_if -> { ar_version.dup.to_s.sub("~>", "").strip < "7.1.0" && !ENV["SKIP_COMPOSITE_PK"] } do
  gem "composite_primary_keys"
end

# Required for samples
gem "docker-api"
gem "sinatra-activerecord"
