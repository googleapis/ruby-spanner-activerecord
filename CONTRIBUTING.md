# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement. You (or your employer) retain the copyright to your contribution;
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to <https://cla.developers.google.com/> to see
your current agreements on file or to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Code reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

## Community Guidelines

This project follows [Google's Open Source Community
Guidelines](https://opensource.google/conduct/).

## Tests

### Functional tests
We have functional tests for individual components that can be run by
```shell
bundle exec rake test
```

### ActiveRecord integration tests
We run full integration tests with continuous integration on Google Cloud Build with Kokoro.

Command : `bundle exec rake acceptance[project,keyfile,instance]`

Variable|Description|Comment
---|---|---
`project`|The project id of the Google Application credentials being used|For example `appdev-soda-spanner-staging`
`keyfile`|The Google Application Credentials file|For example `~/Downloads/creds.json`
`instance`|The Cloud Spanner instance to use, it MUST exist before running tests| For example
`activerecord_tests`

#### Example

```shell
bundle exec rake acceptance[appdev-soda-spanner-staging,/home/Downloads/creds.json,activerecord_tests]
```

You can also use the [Cloud Spanner emulator](https://cloud.google.com/spanner/docs/emulator).

```shell
docker run -d --rm -p 9010:9010 gcr.io/cloud-spanner-emulator/emulator
export SPANNER_EMULATOR_HOST=localhost:9010
bundle exec rake "acceptance[dummy-project,,dummy-instance,]"
```

If you want to run only one test, you can specify a test file.

```shell
bundle exec rake "acceptance[dummy-project,,dummy-instance,]" \
  TEST=acceptance/cases/models/default_value_test.rb
```

## Coding Style

Please follow the established coding style in the library. The style is is
largely based on [The Ruby Style
Guide](https://github.com/bbatsov/ruby-style-guide) with a few exceptions based
on seattle-style:

* Avoid parenthesis when possible, including in method definitions.
* Always use double quotes strings. ([Option
  B](https://github.com/bbatsov/ruby-style-guide#strings))

You can check your code against these rules by running Rubocop like so:

```sh
$ cd ruby-spanner-activerecord
$ bundle exec rubocop
```

The rubocop settings depend on [googleapis/ruby-style](https://github.com/googleapis/ruby-style/), in addition to [.rubocop.yml](https://github.com/googleapis/ruby-spanner-activerecord/blob/main/.rubocop.yml).

## Code of Conduct

Please note that this project is released with a Contributor Code of Conduct. By
participating in this project you agree to abide by its terms. See
[Code of Conduct](CODE_OF_CONDUCT.md) for more information.
