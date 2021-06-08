# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require_relative "statement_result"
require "grpc"
require "gapic/grpc/service_stub"
require "securerandom"

require "google/spanner/admin/database/v1/spanner_database_admin_pb"
require "google/spanner/admin/database/v1/spanner_database_admin_services_pb"
require "google/cloud/spanner/admin/database/v1/database_admin"
require "google/longrunning/operations_pb"

# Mock implementation of Spanner Database Admin
class DatabaseAdminMockServer < Google::Cloud::Spanner::Admin::Database::V1::DatabaseAdmin::Service
  attr_reader :requests

  def initialize
    super
    @requests = []
  end

  def get_database request, _unused_call
    @requests << request
    Google::Cloud::Spanner::Admin::Database::V1::Database.new name: request.name
  end

  def update_database_ddl request, _unused_call
    @requests << request
    Google::Longrunning::Operation.new(
      done: true,
      name: "#{request.database}/operations/#{SecureRandom.uuid}",
    )
  end

end
