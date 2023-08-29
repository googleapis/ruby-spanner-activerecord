# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "bundler/gem_tasks"
require "rake/testtask"
require "securerandom"

desc "Run tests."
Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task :default => :test

require "yard"
require "yard/rake/yardoc_task"
YARD::Rake::YardocTask.new do |y|
  # y.options << "--fail-on-warning"
end

desc "Run the spanner connector acceptance tests."
task :acceptance, [:project, :keyfile, :instance, :tests] do |t, args|
  project = args[:project]
  project ||= ENV["SPANNER_TEST_PROJECT"] || ENV["GCLOUD_TEST_PROJECT"]
  emulator_host = args[:emulator_host]
  emulator_host ||= ENV["SPANNER_EMULATOR_HOST"]
  keyfile = args[:keyfile]
  keyfile ||= ENV["SPANNER_TEST_KEYFILE"] || ENV["GCLOUD_TEST_KEYFILE"] || ENV["GOOGLE_APPLICATION_CREDENTIALS"]
  if keyfile
    keyfile = File.read keyfile
  else
    keyfile ||= ENV["SPANNER_TEST_KEYFILE_JSON"] || ENV["GCLOUD_TEST_KEYFILE_JSON"]
  end
  if project.nil? || (keyfile.nil? && emulator_host.nil?)
    fail "You must provide a project and keyfile or emulator host name."
  end
  instance = args[:instance]
  instance ||= ENV["SPANNER_TEST_INSTANCE"]
  if instance.nil?
    fail "You must provide an instance name"
  end

  # clear any env var already set
  require "google/cloud/spanner/credentials"
  Google::Cloud::Spanner::Credentials.env_vars.each do |path|
    ENV[path] = nil
  end

  tests = args[:tests]
  tests ||= "**"

  # always overwrite when running tests
  ENV["SPANNER_PROJECT"] = project
  ENV["SPANNER_KEYFILE_JSON"] = keyfile
  ENV["SPANNER_TEST_INSTANCE"] = instance
  ENV["SPANNER_EMULATOR_HOST"] = emulator_host

  Rake::TestTask.new :run do |t|
    t.libs << "acceptance"
    t.libs << "lib"

    t.test_files = FileList[
      # "acceptance/cases/migration/change_schema_test.rb",
      # "acceptance/cases/migration/change_table_test.rb",
      # "acceptance/cases/migration/column_attributes_test.rb",
      # "acceptance/cases/migration/column_positioning_test.rb",
      # "acceptance/cases/migration/columns_test.rb",
      # "acceptance/cases/migration/command_recorder_test.rb",
      # "acceptance/cases/migration/create_join_table_test.rb",
      # "acceptance/cases/migration/ddl_batching_test.rb",
      # "acceptance/cases/migration/foreign_key_test.rb",
      "acceptance/cases/migration/index_test.rb",
      # "acceptance/cases/migration/references_foreign_key_test.rb",
    ]

    # t.test_files = FileList["acceptance/#{tests}/*_test.rb"] unless tests.start_with? "exclude "
    # t.test_files = FileList.new("acceptance/**/*_test.rb") do |fl|
    #   fl.exclude "acceptance/#{tests.split(" ")[1]}/*_test.rb"
    #   puts "excluding acceptance/#{tests.split(" ")[1]}/*_test.rb"
    # end if tests.start_with? "exclude"
    t.warning = false
  end

  Rake::Task["run"].invoke
end

desc +"Runs the `examples/snippets/quickstart` example on a Spanner emulator. See the directory `examples/snippets`"
      "for more examples."
task :example do
  Dir.chdir("examples/snippets/quickstart") { sh "bundle exec rake run" }
end
