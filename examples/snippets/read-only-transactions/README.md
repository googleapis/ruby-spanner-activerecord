# Sample - Read-only transactions

In addition to locking read-write transactions, Cloud Spanner offers read-only transactions.
Use a read-only transaction when you need to execute more than one read at the same timestamp.

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
