# Changelog

### 1.6.0 (2023-12-20)

#### Features

* interleaved tables with built-in composite pk ([#282](https://github.com/googleapis/ruby-spanner-activerecord/issues/282)) 
* support Query Logs ([#291](https://github.com/googleapis/ruby-spanner-activerecord/issues/291)) 
* support Rails 7.1 ([#278](https://github.com/googleapis/ruby-spanner-activerecord/issues/278)) 

### 1.5.1 (2023-12-12)

#### Bug Fixes

* more permissive arg passthrough for insert_all and upsert_all ([#283](https://github.com/googleapis/ruby-spanner-activerecord/issues/283)) 

### 1.5.0 (2023-11-03)

#### Features

* Drop support for Ruby 2.6 ([#270](https://github.com/googleapis/ruby-spanner-activerecord/issues/270)) 
* translate annotate to tags ([#267](https://github.com/googleapis/ruby-spanner-activerecord/issues/267)) 
#### Documentation

* update README to reference PGAdapter for PG ([#263](https://github.com/googleapis/ruby-spanner-activerecord/issues/263)) 
* update README to reference PGAdapter for PG ([#263](https://github.com/googleapis/ruby-spanner-activerecord/issues/263)) ([#268](https://github.com/googleapis/ruby-spanner-activerecord/issues/268)) 

### 1.4.4 (2023-09-06)

#### Bug Fixes

* Support for changes in Rails 7.0.7. ([#260](https://github.com/googleapis/ruby-spanner-activerecord/issues/260)) 

### 1.4.3 (2023-06-09)

#### Bug Fixes

* unquote string default value ([#253](https://github.com/googleapis/ruby-spanner-activerecord/issues/253)) 

### 1.4.2 (2023-06-01)

#### Bug Fixes

* allow functions to be default values ([#252](https://github.com/googleapis/ruby-spanner-activerecord/issues/252)) 
* use original types for composite primary keys ([#246](https://github.com/googleapis/ruby-spanner-activerecord/issues/246)) 

### 1.4.1 (2023-03-01)

#### Bug Fixes

* wrap default values in () as required ([#238](https://github.com/googleapis/ruby-spanner-activerecord/issues/238)) 
#### Documentation

* call out best practices and dialect compatibility ([#240](https://github.com/googleapis/ruby-spanner-activerecord/issues/240)) 

### 1.4.0 (2023-01-18)

#### Features

* dropped support for Ruby 2.5 ([#236](https://github.com/googleapis/ruby-spanner-activerecord/issues/236)) 

### 1.3.1 (2022-12-15)

#### Bug Fixes

* build error for ruby 2.5 ([#216](https://github.com/googleapis/ruby-spanner-activerecord/issues/216)) 

### 1.3.0 (2022-12-08)

#### Features

* add check constraint support to migrations ([#205](https://github.com/googleapis/ruby-spanner-activerecord/issues/205)) 
* allows passing of type parameter when creating parent_key column ([#195](https://github.com/googleapis/ruby-spanner-activerecord/issues/195)) 
* include index options in the output of SchemaDumper ([#203](https://github.com/googleapis/ruby-spanner-activerecord/issues/203)) 
* schema_dumper should use DDL batch ([#207](https://github.com/googleapis/ruby-spanner-activerecord/issues/207)) 
* support column DEFAULT expressions in migrations ([#196](https://github.com/googleapis/ruby-spanner-activerecord/issues/196)) 
#### Bug Fixes

* ignore no database when recreating ([#208](https://github.com/googleapis/ruby-spanner-activerecord/issues/208)) 
#### Documentation

* fix typo in example of interleaved-tables ([#209](https://github.com/googleapis/ruby-spanner-activerecord/issues/209)) 

### 1.2.2 (2022-08-29)

#### Documentation

* add ActiveRecord 7 as a supported version to the README ([#189](https://github.com/googleapis/ruby-spanner-activerecord/issues/189)) 
* update limitation on interleaved tables and default column values ([#190](https://github.com/googleapis/ruby-spanner-activerecord/issues/190)) 

### 1.2.1 (2022-08-28)

#### Bug Fixes

* Corrected the namespace for the transaction selector class ([#187](https://github.com/googleapis/ruby-spanner-activerecord/issues/187)) 

### 1.2.0 (2022-08-03)

#### Features

* support composite primary keys for interleaved tables ([#175](https://github.com/googleapis/ruby-spanner-activerecord/issues/175)) 

### 1.1.0 (2022-06-24)

#### Features

* Support insert_all and upsert_all with DML and mutations

### 1.0.1 (2022-04-21)

#### Bug Fixes

* ActiveRecord::Type::Spanner::Array does not use element type

#### Documentation

* add limitation of interleaved tables
* fix a couple of minor formatting issues

### 1.0.0 (2021-12-07)

* GA release

### 0.7.1 (2021-11-21)

#### Performance Improvements

* inline BeginTransaction with first statement in the transaction

### 0.7.0 (2021-10-03)

#### Features

* add support for query hints

### 0.6.0 (2021-09-09)

#### Features

* support JSON data type
* support single stale reads
* support stale reads in read-only transactions

### 0.5.0 (2021-08-31)

#### Features

* Add support for NUMERIC type
* Add support for ARRAY data type
* google-cloud-spanner version upgraded to 2.2
* retry session not found
* support and test multiple ActiveRecord versions
* support DDL batches on connection
* support generated columns
* support interleaved indexes + test other index features
* support optimistic locking
* support PDML transactions
* support prepared statements and query cache
* support read only transactions
* support setting attributes to commit timestamp

#### Performance Improvements

* add benchmarks
