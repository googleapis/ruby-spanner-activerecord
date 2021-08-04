## activerecord-spanner-adapter for Rails tutorial

This example shows how to use activerecord-spanner-adapter for Cloud Spanner as a backend database for [Rails's tutorials](https://guides.rubyonrails.org/getting_started.html)

### Walkthrough the introduction to Rails

### Ensure you have a Cloud Spanner database already created
If you haven't already, please follow the steps to install [Cloud Spanner](https://cloud.google.com/spanner/docs/getting-started/set-up),
or visit this [codelab](https://opencensus.io/codelabs/spanner/#0)

**You'll need to ensure that your Google Application Default Credentials are properly downloaded and saved in your environment.**

### Follow the tutorial
Please follow the [guide](https://guides.rubyonrails.org/getting_started.html#creating-the-blog-application) in until the end with a following DISTINCTION:

### Use Cloud Spanner adapter in Gemfile
Edit Gemfile file and add `activerecord-spanner-adapter` gem.

```ruby
gem 'activerecord-spanner-adapter', git: 'https://github.com/orijtech/activerecord-spanner-adapter.git'
```

Install gems.

```shell
bundle install
```

### Update your database.yml file to use Google Spanner.
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
  database: blog_dev

test:
  <<: *default
  database: blog_test

production:
  <<: *default
  database: blog
```

and for example here is a filled in database where:

* `PROJECT_ID`: spanner-appdev
* `SPANNER_INSTANCE_ID`: instance
* `SPANNER_PROJECT_KEYFILE`:  credentials key file path. i.e "/app/keyfile.json".

### Create database

Please run:
```shell
$ ./bin/rails db:create
```

```shell
Created database 'blog-dev'
```

### Apply the migrations
Please run:
```shell
$ ./bin/rails db:migrate
```

and that'll take a while running, but when done, it will look like the following

<details>

```shell
$ ./bin/rails db:migrate
== 20200326185018 CreateArticles: migrating ===================================
-- create_table(:articles)
   -> 0.0007s
== 20200326185018 CreateArticles: migrated (0.0008s) ==========================

== 20200404080014 AddPublishedAtToArticles: migrating =========================
-- add_column(:articles, :published_at, :datetime)
   -> 0.0002s
== 20200404080014 AddPublishedAtToArticles: migrated (0.0003s) ================
```
</details>

### Now run your server
After those migrations are completed, that will be all. Please continue on with the guides.

```shell
./bin/rails s
```

### References

Resource|URL
---|---
Cloud Spanner homepage|https://cloud.google.com/spanner/
activerecord-spanner-adapter project's source code|https://github.com/orijtech/activerecord-spanner-adapter
