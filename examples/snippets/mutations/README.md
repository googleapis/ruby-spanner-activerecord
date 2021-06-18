# Sample - Mutations

Writing data to a Cloud Spanner database can be done using two different features:
* Data Modification Language (DML)
* Mutations

Changes that are written using DML can be read back during the same read/write transaction. Changes that are
written using Mutations are however buffered locally in the client and only sent to Cloud Spanner when the
transaction is committed. Mutations are therefore not readable during the same read/write transaction. The
Spanner ActiveRecord adapter will use DML by default when modifications are made during a read/write transaction.
Mutations can however be executed more efficiently by Cloud Spanner, which can significantly reduce the execution
time for read/write transactions that modify a large number of records. The Spanner ActiveRecord adapter will
therefore use Mutations in the following cases:

1. No explicit transaction block: When entities are modified outside of an explicit transaction block, ActiveRecord
   will automatically create an implicit transaction and save the data to the database. This means that the data can
   never be read back during the same transaction. The Spanner ActiveRecord adapter recognizes this situation and
   automatically switches to using Mutations for these transactions to optimize the execution speed.
2. Using a custom isolation level: The Spanner ActiveRecord adapter supports the custom isolation level
   `:buffered_mutations` that will instruct the underlying Spanner transaction to use Mutations instead
   of DML for all data operations in the transaction that can be executed using Mutations. Transactions with this
   isolation level do not support read-your-writes.
   
This sample shows how to use the `:buffered_mutations` isolation level to instruct the Spanner ActiveRecord
adapter to use mutations instead of DML during a transaction.

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
