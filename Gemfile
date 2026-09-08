source "https://rubygems.org"

# Specify your gem's dependencies in activerecord-spanner.gemspec
gemspec

unless ENV["APPRAISAL_INITIALIZED"] || ENV["APPRAISAL_UNDER_TEST"] || (ENV["BUNDLE_GEMFILE"] && ENV["BUNDLE_GEMFILE"].include?("gemfiles/"))
  ar_version = ENV.fetch("AR_VERSION", "~> 7.1.0")
  gem "activerecord", ar_version
end
gem "docker-api"
gem "irb"
gem "minitest", "~> 6.0.0"
gem "minitest-rg", "~> 5.4.0"
gem "mutex_m"
gem "ostruct"
gem "pry", "~> 0.16.0"
gem "pry-byebug", "~> 3.12.0"
gem "readline"
gem "sinatra-activerecord"
# Add sqlite3 for testing for compatibility with other adapters.
gem "sqlite3"
