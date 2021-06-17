# Sample - Quickstart

This sample shows how to create and use a very simple Cloud Spanner database with ActiveRecord.
The database consists of two tables:
- Singers
- Albums

Albums references Singers with a [foreign key](https://cloud.google.com/spanner/docs/foreign-keys/overview).

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

This sample will:
1. Create the sample database by calling `rake db:migrate`. This will execute the migrations in the folder `db/migrate`.
2. Fill the sample database with some data by calling `rake db:seed`. This will execute the script in `db/seeds.rb`.
The seed script fills the database with 10 random singers and 30 random albums.
3. Run the `application.rb` file. This application will:
3.1. List all known singers and albums.
3.2. Select a random singer and update the name of this singer.
3.3. Select all singers whose last name start with an 'A'.

Run the application with the command

```bash
bundle exec rake run
```
