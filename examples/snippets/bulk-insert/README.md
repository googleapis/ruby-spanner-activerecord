# Sample - Bulk Insert

It is important to use the correct strategy when bulk creating new records in Spanner using ActiveRecord.
ActiveRecord will by default create a separate insert statement for each entity that you create. The Spanner
ActiveRecord adapter is able to translate this into a set of insert Mutations instead of a list of insert DML
statements, which will execute a lot faster.

There are two ways to achieve this:
1. Create a batch of entities without an explicit transaction.
2. Use a read/write transaction with isolation level `:buffered_mutations`

See also the `Mutations` sample in this repository.

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
