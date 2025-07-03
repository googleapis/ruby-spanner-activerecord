# Sample - Batch DML

This example shows how to use [Batch DML](https://cloud.google.com/spanner/docs/dml-tasks#use-batch)
with the Spanner ActiveRecord adapter.

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```