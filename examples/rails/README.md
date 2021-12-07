## activerecord-spanner-adapter for Rails tutorial

This example shows how to use activerecord-spanner-adapter for Cloud Spanner as a backend database for [Rails's tutorials](https://guides.rubyonrails.org/getting_started.html).

### Create a Spanner instance
This step will create a Cloud Spanner instance. Cloud Spanner is a billable component of the Google Cloud. For information on the cost of using Cloud Spanner, see [Pricing](https://cloud.google.com/spanner/pricing).

__Note__: If you want to try the tutorial without Cloud Spanner cost, you can use the emulator. Read the [doc](https://cloud.google.com/spanner/docs/emulator) for more details.

1. Set the project environment variable:
    ```shell
    export PROJECT_ID=[your-cloud-project-id]
    ```
1. Set the default project:
    ```shell
    gcloud config set project $PROJECT_ID
    ```
1. If you haven't enabled the Cloud Spanner service, enable it:
    ```shell
    gcloud services enable spanner.googleapis.com
    ```
1. Create an instance. This tutorial will use a one-node instance in `regional-us-central1`.
You can choose a region close to you:
    ```shell
    gcloud spanner instances create test-instance --config=regional-us-central1 \
      --description="Rails Demo Instance" --nodes=1
    ```
1. Verify the instance has been created:
    ```shell
    gcloud spanner instances list
    ```
    You should see output like the following:
    ```
    NAME           DISPLAY_NAME         CONFIG                NODE_COUNT  STATE
    test-instance  Rails Demo Instance  regional-us-central1  1           READY
    ```
1. Set the default instance:
    ```shell
    gcloud config set spanner/instance test-instance
    ```

Read the [Cloud Spanner setup guide](https://cloud.google.com/spanner/docs/getting-started/set-up) for more details.

### Create a Rails project

If you don't have Ruby and Rails installed, please follow the steps in the following links to install them:

- [Installing Ruby](https://www.ruby-lang.org/en/documentation/installation/)
- [Installing Rails](https://guides.rubyonrails.org/getting_started.html#creating-a-new-rails-project-installing-rails)

If you are not familiar with Active Record, you can read more about it on [Ruby on Rails Guides](https://guides.rubyonrails.org/)

1. Verify the Ruby and Rails versions:
    ```shell
    ruby --version
    rails --version
    ```
    The versions should be Ruby 2.6 or higher and Rails 6.0 or higher.
1. Create a new Rails project:

    ```shell
    rails new blog
    ```
1. The `blog` directory will have a number of generated files and folders that make up the structure of a Rails application. You can list them:
    ```shell
    cd blog
    ls -l
    ```
1. Starting up the web server and make sure the sample application works:
    ```shell
    bin/rails server
    ```
    After the server starts, open your browser and navigate to [http://localhost:3000](http://localhost:3000). You should see the default Rails page with the sentence: __Yay! You're on Rails!__

### Create a service account

1. Create a service account:
    ```shell
    gcloud iam service-accounts create activerecord-spanner
    ```
1. Grant an IAM role to access Cloud Spanner:
    ```shell
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:activerecord-spanner@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/spanner.databaseAdmin"
    ```
    Here the role `roles/spanner.databaseAdmin` is granted to the service account. If you want to restrict the permissions further, you can choose to create a custom role with proper permissions.
1. Create a key file and download it:
    ```shell
    gcloud iam service-accounts keys create activerecord-spanner-key.json \
    --iam-account=activerecord-spanner@${PROJECT_ID}.iam.gserviceaccount.com
    ```
    This tutorial uses the key file to access Cloud Spanner. If you are using services such as Compute Engine, Cloud Run, or Cloud Functions, you can associate the service account to the instance and avoid using the key file.
1. From the previous step, a key file should be created and downloaded. You can run the following command to view its content:
    ```shell
    cat activerecord-spanner-key.json
    ```

### Use Cloud Spanner adapter in Gemfile
1. Edit the Gemfile file of the `blog` app and add the `activerecord-spanner-adapter` gem:
    ```ruby
    gem 'activerecord-spanner-adapter'
    ```
1. Install gems:

    ```shell
    bundle install
    ```

### Update database.yml to use Cloud Spanner.
After the Cloud Spanner instance is running, you'll need a few variables:
* Cloud project id
* Cloud Spanner instance id, such as `test-instance`
* Database name, such as `blog_dev`
* Credential: Credential key file path or export `GOOGLE_CLOUD_KEYFILE`environment variable.

Edit the file `config/database.yml` and make the section `DATABASES` into the following:

```yml
default: &default
  adapter: "spanner"
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 10 } %>
  project: [PROJECT_ID]
  instance: test-instance
  credentials: activerecord-spanner-key.json

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

Replace `[PROJECT_ID]` with the project id you are currently using.

### Create database

You now can run the following command to create the database:
    ```shell
    ./bin/rails db:create
    ```
    You should see output like the following:
    ```
    Created database 'blog_dev'
    ```
### Generate a Model and apply the migration
1. Use the model generato to define a model:
    ```shell
    bin/rails generate model Article title:string body:text
    ```
1. Apply the migration:
    ```shell
    ./bin/rails db:migrate
    ```
    The command takes a while to complete. When it's done, you will have an output like the following:
    ```
    $ ./bin/rails db:migrate
    == 20210803025742 CreateArticles: migrating ===================================
    -- create_table(:articles)
      -> 23.5728s
    == 20210803025742 CreateArticles: migrated (23.5729s) =========================
    ```

### Use the CLI to interact with the database
1. Run the following command to start `irb`:
    ```shell
    bin/rails console
    ```
1. At the prompt, initialize a new `Article` object:
    ```ruby
    article = Article.new(title: "Hello Rails", body: "I am on Rails!")
    ```
1. Run the following command to save the object to the database:
    ```ruby
    article.save
    ```
1. Review the object and you can see the field `id`, `created_at`, and `updated_at` have been set:
    ```ruby
    article
    ```
    Sample output:
    ```
    => #<Article id: 4170057092403543076, title: "Hello Rails", body: "I am on Rails!", created_at: "2021-08-03 03:06:26.096275000 +0000", updated_at: "2021-08-03 03:06:26.096275000 +0000">
    ```
1. You can find `Article.find(id)` or `Article.all` to fetch data from the database. For example:
    ```ruby
    irb(main):007:0> Article.find(4170057092403543076)
    Article Load (49.2ms)  SELECT `articles`.* FROM `articles` WHERE `articles`.`id` = @p1 LIMIT @p2
    => #<Article id: 4170057092403543076, title: "Hello Rails", body: "I am on Rails!", created_at: "2021-08-03 03:06:26.096275000 +0000", updated_at: "2021-08-03 03:06:26.096275000 +0000">

    irb(main):008:0> Article.all
    Article Load (73.9ms)  SELECT `articles`.* FROM `articles` /* loading for inspect */ LIMIT @p1
    => #<ActiveRecord::Relation [#<Article id: 4170057092403543076, title: "Hello Rails", body: "I am on Rails!", created_at: "2021-08-03 03:06:26.096275000 +0000", updated_at: "2021-08-03 03:06:26.096275000 +0000">]>
    ```

### Update the app to show a list of records
1. Use the controller generator to create a controller:
    ```shell
    bin/rails generate controller Articles index
    ```
1. Open the file `app/controllers/articles_controller.rb`, and change the `index` action to fetch all articles from the database:
    ```ruby
    class ArticlesController < ApplicationController
      def index
        @articles = Article.all
      end
    end
    ```
1. Open `app/views/articles/index.html.erb`, and update the file as the following:
    ```html
    <h1>Articles</h1>
    <ul>
      <% @articles.each do |article| %>
        <li>
          <%= article.title %>
        </li>
      <% end %>
    </ul>
    ```
1. Run your server again
    ```shell
    ./bin/rails s
    ```
1. In your browser, navigate to the URL [http://localhost:3000/articles/index](http://localhost:3000/articles/index). And you will see the `Hello Rails` record you entered previously.
1. [Optional] you can follow the rest of the steps in the [Getting Started with Rails](https://guides.rubyonrails.org/getting_started.html) guide.

### Clean up

To avoid incurring charges to your Google Cloud account for the resources used in this tutorial, you can delete the resources you created. You can either 
delete the entire project or delete individual resources.

Deleting a project has the following effects:

* Everything in the project is deleted. If you used an existing project for this tutorial, when you delete it, you also delete any other work you've done in the
  project.
* Custom project IDs are lost. When you created this project, you might have created a custom project ID that you want to use in the future. To preserve the URLs
  that use the project ID, delete selected resources inside the project instead of deleting the whole project.

If you plan to explore multiple tutorials, reusing projects can help you to avoid exceeding project quota limits.

#### Delete the project

The easiest way to eliminate billing is to delete the project you created for the tutorial. 

1.  In the Cloud Console, go to the [**Manage resources** page](https://console.cloud.google.com/iam-admin/projects).  
1.  In the project list, select the project that you want to delete and then click **Delete**.
1.  In the dialog, type the project ID and then click **Shut down** to delete the project.

#### Delete the resources

If you don't want to delete the project, you can delete the provisioned resources:

    gcloud iam service-accounts delete \
    activerecord-spanner@${PROJECT_ID}.iam.gserviceaccount.com

    gcloud spanner instances delete test-instance
