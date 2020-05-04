# The MIT License (MIT)
#
# Copyright (c) 2020 Google LLC.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# ITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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
  (Google::Cloud::Spanner::Credentials::PATH_ENV_VARS +
   Google::Cloud::Spanner::Credentials::JSON_ENV_VARS).each do |path|
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
