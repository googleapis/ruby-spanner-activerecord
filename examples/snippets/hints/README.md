# Sample - Query Hints

This example shows how to use query hints Spanner ActiveRecord adapter. Statement hints and
table hints can be specified using the optimizer_hints method. Join hints must be specified
in a join string.

See https://cloud.google.com/spanner/docs/query-syntax#sql_syntax for more information on
the supported query hints.

## Running the Sample

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
