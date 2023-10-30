# Sample - Request tags and Transaction tags

Queries can be annotated with request tags and transaction tags. These can be used to give
you more insights in your queries and transactions.
See https://cloud.google.com/spanner/docs/introspection/troubleshooting-with-tags for more
information about request and transaction tags in Cloud Spanner.

You can use the [`annotate`](https://api.rubyonrails.org/classes/ActiveRecord/QueryMethods.html#method-i-annotate)
method in Ruby ActiveRecord to add a request and/or transaction tag to a __query__. You must
prefix the annotation with either `request_tag:` or `transaction_tag:` to instruct the
Cloud Spanner ActiveRecord provider to recognize the annotation as a tag.

__NOTE:__ Ruby ActiveRecord does not add comments for `INSERT`, `UPDATE` and `DELETE` statements
when you add annotations to a model. This means that these statements will not be tagged.

Example:

```ruby

```

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
