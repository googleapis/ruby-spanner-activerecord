source "https://rubygems.org"

# Specify your gem's dependencies in activerecord-spanner.gemspec
gemspec

ar_version = ENV.fetch("AR_VERSION", "~> 7.1.0")
gem "activerecord", ar_version
gem "ostruct"
gem "minitest", "~> 5.27.0"
gem "minitest-rg", "~> 5.4.0"
gem "pry", "~> 0.16.0"
gem "pry-byebug", "~> 3.12.0"
gem "readline"
gem "mutex_m"
gem "irb"
# Add sqlite3 for testing for compatibility with other adapters.
gem 'sqlite3'

# Required for samples and testing.
install_if -> { ar_version.dup.to_s.sub("~>", "").strip < "7.1.0" && !ENV["SKIP_COMPOSITE_PK"] } do
  gem "composite_primary_keys"
end

# Required for samples
gem "docker-api"
gem "sinatra-activerecord"

# Force google-protobuf to compile from source to avoid ABI issues in CI
if ENV["CI"]
  gem "google-protobuf", force_ruby_platform: true
end
