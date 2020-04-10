# ActiverecordSpannerAdapter

# 🚨THIS CODE IS STILL UNDER DEVELOPMENT🚨

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
  project: "<google project name>"
  instance: "<google instance name>"
  credentials: "<google credentails file path>"
  database: "app-dev"
```

## Limitations

Limitation|Comment|Resolution
---|---|---
Lack of DEFAULT for columns [change_column_default](https://apidock.com/rails/v5.2.3/ActiveRecord/ConnectionAdapters/SchemaStatements/change_column_default)|Cloud Spanner doesn't support using DEFAULT for columns thus the use of default values might have to enforced in your controller logic| Cloud Spanner added support for  default value then need to alter column using migration for default value.
Lack of FOREIGN KEY constraints|Cloud Spanner doesn't support foreign key constraints thus they have to be defined in code
Lack of sequential and auto-assigned IDs|Cloud Spanner doesn't autogenerate IDs and this integration instead creates UUID4 to avoid [hotspotting](https://cloud.google.com/spanner/docs/schema-design#uuid_primary_key) so you SHOULD NOT rely on IDs being sorted|We generate UUID4s for each Primary key
Table without Primary Key| Cloud Spanner support does not support table without primary key for inserting more than one records.
Decimal values are saved as FLOAT64|Cloud Spanner doesn't support the NUMERIC type thus we might have precision losses|Decimal and Numeric are translated to FLOAT64. If Cloud Spanner adds Decimal in the future, you might need to migrate your columns
Table names CANNOT have spaces within them whether back-ticked or not|Cloud Spanner DOEST NOT support tables with spaces in them for example `Entity ID`|Ensure that your table names don't have spaces within them
Table names CANNOT have punctuation marks and MUST contain valid UTF-8|Cloud Spanner DOEST NOT support punctuation marks e.g. periods ".", question marks "?" in table names|Ensure that your table names don't have punctuation marks
Index with fields length [add_index](https://apidock.com/rails/v5.2.3/ActiveRecord/ConnectionAdapters/SchemaStatements/add_index)|Cloud Spanner does not supports index with fields length | If Cloud Spanner adds Index field length in the future, you might need to recreate indexes using migration

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/activerecord-spanner-adapter. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Activerecord::Spanner project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/activerecord-spanner-adapter/blob/master/CODE_OF_CONDUCT.md).

# 🚨THIS CODE IS STILL UNDER DEVELOPMENT🚨
