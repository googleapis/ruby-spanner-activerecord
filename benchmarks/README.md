# Benchmarks

Benchmarks the Spanner ActiveRecord adapter using a small set of standardized use cases. The benchmarks consists of two
separate runs:
* Execute each use case separately and measure the time needed for each use case.
* Batch all use cases together and execute multiple batches in parallel, measuring the time needed to finish all
  batches. The number of batches varies between 1 and 400. The session pool is configured to contain at most 400
  connections.

Change the configuration in the file `config/database.yml` before running the benchmarks. The instance and database in
the configuration must exist. The tables that are needed will automatically be created by the benchmark script.

Run the benchmark with the command

```bash
bundle exec rake run
```
