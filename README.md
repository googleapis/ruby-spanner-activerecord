# ActiveRecord Cloud Spanner Adapter

[Google Cloud Spanner](https://cloud.google.com/spanner) adapter for ActiveRecord.

![rubocop](https://github.com/googleapis/ruby-spanner-activerecord/workflows/rubocop/badge.svg)

__This adapter only supports GoogleSQL-dialect Cloud Spanner databases. PostgreSQL-dialect
databases are not supported. You can use the standard PostgreSQL ActiveRecord adapter in
[combination with PGAdapter](https://github.com/GoogleCloudPlatform/pgadapter/blob/-/samples/ruby/activerecord)
for Cloud Spanner PostgreSQL-dialect databases.__

This project provides a Cloud Spanner adapter for ActiveRecord. It supports the following versions:

- ActiveRecord 6.0.x with Ruby 2.7.
- ActiveRecord 6.1.x with Ruby 2.7 and higher.
- ActiveRecord 7.0.x with Ruby 2.7 and higher.

Known limitations are listed in the [Limitations](#limitations) section.
Please report any problems that you might encounter by [creating a new issue](https://github.com/googleapis/ruby-spanner-activerecord/issues/new).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activerecord-spanner-adapter'
```

If you would like to use latest adapter version from github then specify

```ruby
gem 'activerecord-spanner-adapter', :git => 'git@github.com:googleapis/ruby-spanner-activerecord.git'
```

And then execute:

    $ bundle

## Usage

### Migrations
__Use DDL batching when executing migrations for the best possible performance.__

Executing multiple schema changes on Cloud Spanner can take a long time. It is therefore
strongly recommended that you limit the number of schema change operations. You can do
this by using DDL batching in your migrations. See [the migrations examples](examples/snippets/migrations)
for how to do this.

### Database Connection
In Rails application `config/database.yml`, make the change as the following:

```
development:
  adapter: "spanner"
  project: "<google project name>"
  instance: "<google instance name>"
  credentials: "<google credentails file path>"
  database: "app-dev"
```

## Examples
To get started with Rails, read the tutorial under [examples/rails/README.md](examples/rails/README.md).

You can also find a list of short self-contained code examples that show how
to use ActiveRecord with Cloud Spanner under the directory [examples/snippets](examples/snippets). Each example is directly runnable without the need to setup a Cloud Spanner
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
- [bit-reversed-sequences](examples/snippets/bit-reversed-sequence): Shows how to use bit-reversed sequences for primary keys.
- [read-write-transactions](examples/snippets/read-write-transactions): Shows how to execute transactions on Cloud Spanner.
- [read-only-transactions](examples/snippets/read-only-transactions): Shows how to execute read-only transactions on Cloud Spanner.
- [bulk-insert](examples/snippets/bulk-insert): Shows the best way to insert a large number of new records.
- [mutations](examples/snippets/mutations): Shows how you can use [mutations instead of DML](https://cloud.google.com/spanner/docs/dml-versus-mutations)
  for inserting, updating and deleting data in a Cloud Spanner database. Mutations can have a significant performance
  advantage compared to DML statements, but do not allow read-your-writes semantics during a transaction.
- [array-data-type](examples/snippets/array-data-type): Shows how to work with `ARRAY` data types.
- [interleaved-tables](examples/snippets/interleaved-tables-before-7.1): Shows how to work with [Interleaved Tables](https://cloud.google.com/spanner/docs/schema-and-data-model#create-interleaved-tables).

## Limitations

| Limitation                                                                                                                        | Comment                                                                                                                                                                                                                           | Resolution                                                                                  |
|-----------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| Interleaved tables require composite primary keys                                                                                 | Cloud Spanner requires composite primary keys for interleaved tables. See [this example](examples/snippets/interleaved-tables/README.md) for an example on how to use interleaved tables with ActiveRecord                        | Use composite primary keys.                                                                 |
| Lack of sequential IDs                                                                                                            | Cloud Spanner uses either using bit-reversed sequences or UUID4 to generated primary keys to avoid [hotspotting](https://cloud.google.com/spanner/docs/schema-design#uuid_primary_key) so you SHOULD NOT rely on IDs being sorted | Use either UUID4s or bit-reversed sequences to automatically generate primary keys.         |
| Table without Primary Key                                                                                                         | Cloud Spanner support does not support tables without a primary key.                                                                                                                                                              | Always define a primary key for your table.                                                 |
| Table names CANNOT have spaces within them whether back-ticked or not                                                             | Cloud Spanner DOES NOT support tables with spaces in them for example `Entity ID`                                                                                                                                                 | Ensure that your table names don't contain spaces.                                          |
| Table names CANNOT have punctuation marks and MUST contain valid UTF-8                                                            | Cloud Spanner DOES NOT support punctuation marks e.g. periods ".", question marks "?" in table names                                                                                                                              | Ensure that your table names don't contain punctuation marks.                               |
| Index with fields length [add_index](https://apidock.com/rails/v5.2.3/ActiveRecord/ConnectionAdapters/SchemaStatements/add_index) | Cloud Spanner does not support index with fields length                                                                                                                                                                           | Ensure that your database definition does not include index definitions with field lengths. |
| Only GoogleSQL-dialect databases                                                                                                  | Cloud Spanner supports both GoogleSQL- and PostgreSQL-dialect databases. This adapter only supports GoogleSQL-dialect databases.                                                                                                  | Ensure that your database uses the GoogleSQL dialect.                                       |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/googleapis/ruby-spanner-activerecord. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Activerecord::Spanner project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/googleapis/ruby-spanner-activerecord/blob/main/CODE_OF_CONDUCT.md).
