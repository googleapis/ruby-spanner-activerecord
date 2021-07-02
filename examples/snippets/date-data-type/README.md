# Sample - Date Data Type

This example shows how to use the `DATE` data type with the Spanner ActiveRecord adapter. A `DATE` is a
timezone-independent date. It does not designate a specific point in time, such as UTC midnight of the date.
If you create a timezone-specific date/time object in Ruby and assign it to a `DATE` attribute, all time and timezone
information will be lost after saving and reloading the object.

Use the `TIMESTAMP` data type for attributes that represent a specific point in time.

## Running the Sample

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
