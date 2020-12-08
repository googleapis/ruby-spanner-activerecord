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
task :acceptance, :project, :keyfile, :instance do |t, args|
  project = args[:project]
  project ||= ENV["SPANNER_TEST_PROJECT"] || ENV["GCLOUD_TEST_PROJECT"]
  keyfile = args[:keyfile]
  keyfile ||= ENV["SPANNER_TEST_KEYFILE"] || ENV["GCLOUD_TEST_KEYFILE"]
  if keyfile
    keyfile = File.read keyfile
  else
    keyfile ||= ENV["SPANNER_TEST_KEYFILE_JSON"] || ENV["GCLOUD_TEST_KEYFILE_JSON"]
  end
  if project.nil? || keyfile.nil?
    fail "You must provide a project and keyfile."
  end
  instance = args[:instance]
  instance ||= ENV["SPANNER_TEST_INSTANCE"]

  # clear any env var already set
  require "google/cloud/spanner/credentials"
  Google::Cloud::Spanner::Credentials.env_vars.each do |path|
    ENV[path] = nil
  end

  # always overwrite when running tests
  ENV["SPANNER_PROJECT"] = project
  ENV["SPANNER_KEYFILE_JSON"] = keyfile
  ENV["SPANNER_TEST_INSTANCE"] = instance

  Rake::TestTask.new :run do |t|
    t.libs << "acceptance"
    t.libs << "lib"
    t.test_files = FileList["acceptance/**/*_test.rb"]
    t.warning = false
  end

  Rake::Task["run"].invoke
end
