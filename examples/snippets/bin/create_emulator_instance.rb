# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "google/cloud/spanner"

spanner  = Google::Cloud::Spanner.new project: 'test-project', emulator_host: 'localhost:9010'
job = spanner.create_instance 'test-instance',
                              name:   'Test Instance',
                              config: "emulator-config",
                              nodes:  1
job.wait_until_done!

instance = spanner.instance 'test-instance'
job = instance.create_database 'testdb', statements: []
job.wait_until_done!
