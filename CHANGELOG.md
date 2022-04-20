# Changelog

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
