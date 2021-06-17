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
  keyfile ||= ENV["SPANNER_TEST_KEYFILE"] || ENV["GCLOUD_TEST_KEYFILE"]
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
    t.test_files = FileList["acceptance/#{tests}/*_test.rb"]
    t.warning = false
  end

  Rake::Task["run"].invoke
end

desc 'Runs a simple ActiveRecord tutorial on a Spanner emulator.'
task :example do |t|
  t.libs << "examples/snippets"
  t.libs << "lib"

  container = Docker::Container.create(
    'Image' => 'gcr.io/cloud-spanner-emulator/emulator',
    'ExposedPorts' => { '9010/tcp' => {} },
    'HostConfig' => {
      'PortBindings' => {
        '9010/tcp' => [{ 'HostPort' => '9010' }]
      }
    }
  )
  begin
    container.start!
    sh 'ruby examples/snippets/bin/create_emulator_instance.rb'
    sh 'rake db:migrate'
    sh 'rake db:seed'
    sh 'ruby examples/snippets/quickstart/application.rb'
  ensure
    container.stop!
  end
end
