# Sample - Timestamp Data Type

This example shows how to use the `TIMESTAMP` data type with the Spanner ActiveRecord adapter. A `TIMESTAMP` represents
a specific point in time. Cloud Spanner always stores the timestamp in UTC, and it is not possible to include a
specific timezone in a timestamp value in Cloud Spanner. Instead, a separate column containing a timezone can be used
if your application needs to store both a timestamp and a timezone. This sample shows how to do this.

## Running the Sample

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
