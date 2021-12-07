# Sample - Partitioned DML

This example shows how to use Partitioned DML with the Spanner ActiveRecord adapter.

See https://cloud.google.com/spanner/docs/dml-partitioned for more information on Partitioned DML.

## Running the Sample

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
