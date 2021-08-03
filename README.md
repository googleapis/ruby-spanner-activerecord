# ActiveRecord Cloud Spanner Adapter

# 🚨THIS CODE IS STILL UNDER DEVELOPMENT🚨

[Google Cloud Spanner](https://cloud.google.com/spanner) adapter for ActiveRecord.

![rubocop](https://github.com/googleapis/ruby-spanner-activerecord/workflows/rubocop/badge.svg)

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

## Examples

See the [examples/snippets](examples/snippets) directory for a list of short self-contained code examples that show how
to use ActiveRecord with Cloud Spanner. Each example is directly runnable without the need to setup a Cloud Spanner
database, as all samples will automatically start a Cloud Spanner emulator in a Docker container and execute the sample
code against that emulator. All samples can be executed by navigating to the sample directory on your local machine and
then executing the command `bundle exec rake run`. Example:

```bash
cd ruby-spanner-activerecord/examples/snippets/quickstart
bundle exec rake run
```

__NOTE__: You do need to have [Docker](https://docs.docker.com/get-docker/) installed on your local system to run these examples.

Some noteworthy examples in the snippets directory:
- [quickstart](examples/snippets/quickstart): A simple application that shows how to create and query a simple database containing two tables.
- [migrations](examples/snippets/migrations): Shows a best-practice for executing migrations on Cloud Spanner.
- [read-write-transactions](examples/snippets/read-write-transactions): Shows how to execute transactions on Cloud Spanner.
- [read-only-transactions](examples/snippets/read-only-transactions): Shows how to execute read-only transactions on Cloud Spanner.
- [bulk-insert](examples/snippets/bulk-insert): Shows the best way to insert a large number of new records.
- [mutations](examples/snippets/mutations): Shows how you can use [mutations instead of DML](https://cloud.google.com/spanner/docs/dml-versus-mutations)
  for inserting, updating and deleting data in a Cloud Spanner database. Mutations can have a significant performance
  advantage compared to DML statements, but do not allow read-your-writes semantics during a transaction.
- [interleaved-tables](examples/snippets/interleaved-tables): Shows how to create and work with a hierarchy of `INTERLEAVED IN` tables.
- [array-data-type](examples/snippets/array-data-type): Shows how to work with `ARRAY` data types.

## Limitations

Limitation|Comment|Resolution
---|---|---
Lack of DEFAULT for columns [change_column_default](https://apidock.com/rails/v5.2.3/ActiveRecord/ConnectionAdapters/SchemaStatements/change_column_default)|Cloud Spanner does not support DEFAULT values for columns. The use of default must be enforced in your controller logic| Always set a value in your model or controller logic.
Lack of sequential and auto-assigned IDs|Cloud Spanner doesn't autogenerate IDs and this integration instead creates UUID4 to avoid [hotspotting](https://cloud.google.com/spanner/docs/schema-design#uuid_primary_key) so you SHOULD NOT rely on IDs being sorted| UUID4s are automatically generated for primary keys.
Table without Primary Key| Cloud Spanner support does not support tables without a primary key.| Always define a primary key for your table.
Table names CANNOT have spaces within them whether back-ticked or not|Cloud Spanner DOES NOT support tables with spaces in them for example `Entity ID`|Ensure that your table names don't contain spaces.
Table names CANNOT have punctuation marks and MUST contain valid UTF-8|Cloud Spanner DOES NOT support punctuation marks e.g. periods ".", question marks "?" in table names|Ensure that your table names don't contain punctuation marks.
Index with fields length [add_index](https://apidock.com/rails/v5.2.3/ActiveRecord/ConnectionAdapters/SchemaStatements/add_index)|Cloud Spanner does not support index with fields length | Ensure that your database definition does not include index definitions with field lengths.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/googleapis/ruby-spanner-activerecord. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Activerecord::Spanner project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/googleapis/ruby-spanner-activerecord/blob/master/CODE_OF_CONDUCT.md).

# 🚨THIS CODE IS STILL UNDER DEVELOPMENT🚨

