# Changelog

## 0.5.0 (2021-08-31)


### Features

* add mapping and tests for NUMERIC type ([#73](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/73)) ([176cf99](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/176cf99dc8c26b3fd34d9e85d82a91dbde2b15c8))
* Add support for ARRAY data type ([#86](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/86)) ([0c66a62](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/0c66a620cab968779de04faf48e03eec643ebea9))
* google-cloud-spanner version upgraded to 2.2 ([#55](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/55)) ([d7581d6](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/d7581d60bd9a9e7b9989565449119f73e2caa694))
* interleaved tables ([#83](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/83)) ([82265f9](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/82265f94ace79964639a2c65554714752be39724))
* retry session not found ([#81](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/81)) ([88fd3b7](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/88fd3b70a03a90de2b667bb0f2e86efe5dc9328b))
* support and test multiple ActiveRecord versions ([#107](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/107)) ([db9d96c](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/db9d96c44b9560f6904209df1a9aa42bf50a5844))
* support DDL batches on connection ([#72](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/72)) ([0d18cd4](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/0d18cd49641bdb567012d6ac88b1909461d42551))
* support generated columns ([#94](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/94)) ([68664eb](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/68664eb5c617abc2954dea274430f416e616a324))
* support interleaved indexes + test other index features ([#101](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/101)) ([812e0f7](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/812e0f7f60b36ec26a974f6fb48266de5d840652))
* support optimistic locking ([#92](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/92)) ([9eb71d8](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/9eb71d8a207a8df0406241bff5780593eb0afd34))
* support PDML transactions ([#106](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/106)) ([fa0599a](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/fa0599afe986a184bb6ab26340305eeaa753dafa))
* support prepared statements and query cache ([#74](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/74)) ([fed8258](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/fed825862c95e3e052410e3576de18fc3b7849b7))
* support read only transactions ([#80](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/80)) ([2d6097b](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/2d6097bd8f4530634a41dcdbcbb3a02614f482b8))
* support setting attributes to commit timestamp ([#89](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/89)) ([cdd8448](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/cdd844852da92fa4e2c43fd06eeef31310d6ff8a))


### Bug Fixes

* add_foreign_key def was changed in 6.0.3 ([#108](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/108)) ([dd6f707](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/dd6f707a37c5f76741f0a293e8a1e9568b63c8c9))
* change primary key to string and cleanup ([01d4abb](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/01d4abba73dd6c3a4485c022997ccc868f187e89))


### Performance Improvements

* add benchmarks ([#98](https://www.github.com/googleapis/ruby-spanner-activerecord/issues/98)) ([80cbadc](https://www.github.com/googleapis/ruby-spanner-activerecord/commit/80cbadc5063f2f257ca1e6e7bf563fc376967428))
