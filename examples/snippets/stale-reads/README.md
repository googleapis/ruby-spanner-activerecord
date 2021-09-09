# Sample - Stale reads

Read and query operations outside of a transaction block will by default be executed using a
single-use read-only transaction with strong timestamp bound. This means that the read is
guaranteed to return all data that has been committed at the time of the read. It is also possible
to specify that the Spanner ActiveRecord provider should execute a stale read. This is done by
specifying an optimizer hint for the read or query operation. The hints that are available are:

* `max_staleness: <seconds>`
* `exact_staleness: <seconds>`
* `min_read_timestamp: <timestamp>`
* `read_timestamp: <timestamp>`

See https://cloud.google.com/spanner/docs/timestamp-bounds for more information on what the
different timestamp bounds in Cloud Spanner mean.

NOTE: These optimizer hints ONLY work OUTSIDE transactions. See the read-only-transactions
samples for more information on how to specify a timestamp bound for a read-only transaction.

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
