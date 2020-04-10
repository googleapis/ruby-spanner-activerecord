## activerecord-spanner-adapter on Solidus

This example shows how to use activerecord-spanner-adapter for Cloud Spanner as a backend database for https://solidus.io.

#### Table of contents
- [Ensure you have a Cloud Spanner database already created](#ensure-you-have-a-Cloud-Spanner-database-already-created)
- [Create a Rails application and install Solidus](#create-a-rails-application-and-install-solidus)
- [Update database.yml](#update-database.yml)
- [Create application database](#create-application-database)
- [Apply the migrations](#apply-the-migrations)
- [Go view the results on Cloud Spanner UI](#go-view-the-results-on-Cloud-Spanner-UI)
- [Run the application](#run-the-application)
- [References](#references)

### Ensure you have a Cloud Spanner database already created
If you haven't already, please follow the steps to install [Cloud Spanner](https://cloud.google.com/spanner/docs/getting-started/set-up),
or visit this [codelab](https://opencensus.io/codelabs/spanner/#0)

**You'll need to ensure that your Google Application Default Credentials are properly downloaded and saved in your environment.**

### Create a Rails application and install Solidus

Create a Rails application.
```shell
rails new e-store
cd e-store
```
Add `solidus` and  `activerecord-spanner-adapter` gem to Gemfile.

Gemfile
```ruby
gem 'solidus'
gem 'activerecord-spanner-adapter', git: 'https://github.com/orijtech/activerecord-spanner-adapter.git'
```

```shell
bundle install
```

### Use Cloud Spanner adapter in Gemfile
Edit Gemfile file and add `activerecord-spanner-adapter` gem.

```ruby
gem 'activerecord-spanner-adapter', git: 'https://github.com/orijtech/activerecord-spanner-adapter.git'
```

Install gems.

```shell
bundle install
```

After installing gems, you'll have to run the generator to create necessary configuration files and migrations.

```shell
bin/rails g spree:install
```

### Update database.yml

Update `db/database.yml` to use `activerecord-spanner-adapter`

After we have a Cloud Spanner database created, we'll need a few variables:
* Project id
* Instance id
* Database name
* Credential: Credential keyfile path or Export `GOOGLE_CLOUD_KEYFILE`environment variable.

Once in, please edit the file `config/database.yml` and make the section `DATABASES` into the following:

```yml
default: &default
  adapter: "spanner"
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 10 } %>
  project: PROJECT_ID
  instance: SPANNER_INSTANCE_ID
  credentials: SPANNER_PROJECT_KEYFILE

development:
  <<: *default
  database: e-store-dev

test:
  <<: *default
  database: e-store-test

production:
  <<: *default
  database: e-store
```

and for example here is a filled in database where:

* `PROJECT_ID`: spanner-appdev
* `SPANNER_INSTANCE_ID`: instance
* `SPANNER_PROJECT_KEYFILE`:  credentials key file path. i.e "/app/keyfile.json".

###  Create application database

Please run:
```shell
$ ./bin/rails db:create
```

```shell
Created database e-store-dev
```

### Apply the migrations
Please run:
```shell
$ ./bin/rails db:migrate
```

and that'll take a while running, it will look like the following

<details>

```shell
$ ./bin/rails db:migrate
== 20200410055855 CreateActiveStorageTables: migrating ========================
-- create_table(:active_storage_blobs, {})
   -> 0.0011s
-- create_table(:active_storage_attachments, {})
   -> 0.0010s
== 20200410055855 CreateActiveStorageTables: migrated (0.0023s) ===============

..... MANY MORE MIGRATION LOG LINES
```
</details>

### Now run your server
After those migrations run application server.

```shell
./bin/rails s
```
<details>

```
./bin/rails s
Puma starting in single mode...
* Version 4.3.3 (ruby 2.6.3-p62), codename: Mysterious Traveller
* Min threads: 5, max threads: 5
* Environment: development
* Listening on tcp://127.0.0.1:3000
* Listening on tcp://[::1]:3000
Use Ctrl-C to stop
Started GET "/" for ::1 at 2020-04-10 11:42:00 +0530
   (563.0ms)  SELECT `schema_migrations`.`version` FROM `schema_migrations` ORDER BY `schema_migrations`.`version` ASC
Processing by Spree::HomeController#index as HTML
  Spree::Store Load (507.9ms)  SELECT `spree_stores`.* FROM `spree_stores` WHERE (`spree_stores`.`url` = 'localhost' OR `spree_stores`.`default` = TRUE) ORDER BY `spree_stores`.`default` ASC LIMIT 1
  Rendering /Users/jiren/work/spanner_orm/solidus/frontend/app/views/spree/home/index.html.erb within spree/layouts/spree_application
  Spree::Taxonomy Load (571.6ms)  SELECT `spree_taxonomies`.* FROM `spree_taxonomies` ORDER BY `spree_taxonomies`.`position` ASC
```

</details>

### References

Resource|URL
---|---
Solidus application|https://solidus.io/
Solidus application source code|https://github.com/solidusio/solidus
Cloud Spanner homepage|https://cloud.google.com/spanner/
activerecord-spanner-adapter project's source code|https://github.com/orijtech/activerecord-spanner-adapter
