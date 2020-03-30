# ActiverecordSpannerAdapter

Google Clound Sanner ActiveRecord adapter. https://cloud.google.com/spanner

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activerecord-spanner-adapter'
```

If you would like to use latest adapter version from github then specify

```ruby
gem 'activerecord-spanner-adapter', :git => 'git@github.com:orijtech/activerecord-spanner-adapter.git'
```

And then execute:

    $ bundle

## Usage

### Database Connection
In Rails application config/database.yml

```
development:
  adapter: "spanner"
  project: "google project name"
  instance: "google instance name"
  credentials: "google credentails file path"
  database: "app-dev"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/activerecord-spanner-adapter. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Activerecord::Spanner project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/activerecord-spanner-adapter/blob/master/CODE_OF_CONDUCT.md).
