# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class TimeTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "TIMESTAMP", connection.type_to_sql(:time)
      end

      def test_assign_time
        expected_time = ::Time.now
        record = TestTypeModel.new start_time: expected_time

        assert_equal expected_time, record.start_time
      end

      def test_assign_empty_time
        record = TestTypeModel.new start_time: ""
        assert_nil record.start_time
      end

      def test_assign_nil_time
        record = TestTypeModel.new start_time: nil
        assert_nil record.start_time
      end

      def test_set_and_save_time
        expected_time = ::Time.now.utc
        record = TestTypeModel.create! start_time: expected_time

        assert_equal expected_time, record.start_time

        record.reload
        assert_equal expected_time, record.start_time
      end

      def test_date_time_string_value_with_subsecond_precision
        expected_time = ::Time.utc 2017, 7, 4, 14, 19, 10, 897761

        string_value = "2017-07-04 14:19:10.897761"

        record = TestTypeModel.new start_time: string_value
        assert_equal expected_time, record.start_time.utc

        record.save!
        record.reload
        assert_equal expected_time, record.start_time.utc

        assert_equal record, TestTypeModel.find_by(start_time: string_value)
      end

      def test_date_time_with_string_value_with_non_iso_format
        string_value = "04/07/2017 2:19pm"
        expected_time = ::Time.utc 2017, 7, 4, 14, 19

        record = TestTypeModel.new start_time: string_value
        assert_equal expected_time, record.start_time

        record.save!
        record.reload
        assert_equal expected_time, record.start_time.utc

        assert_equal record, TestTypeModel.find_by(start_time: string_value)
      end

      def test_default_year_is_correct
        expected_time = ::Time.utc(2000, 1, 1, 10, 30, 0)
        record = TestTypeModel.new start_time: { 4 => 10, 5 => 30 }

        assert_equal expected_time, record.start_time

        record.save!
        record.reload

        assert_equal expected_time, record.start_time
      end

      def test_multiparameter_datetime
        expected_time = ::Time.utc 2020, 12, 25, 10, 30, 0
        record = TestTypeModel.new start_time: { 1 => 2020, 2 => 12, 3 => 25, 4 => 10, 5 => 30 }

        assert_equal expected_time, record.start_time

        record.save!
        record.reload

        assert_equal expected_time, record.start_time
      end

      def test_date_time_string_value_with_timezone_aware_attributes
        old_zone = ::Time.zone
        ::Time.zone = "UTC"
        TestTypeModel.time_zone_aware_attributes = true
        TestTypeModel.reset_column_information

        string_value = "2017-07-04 14:19:10.897761"
        expected_time = ::Time.zone.local 2017, 7, 4, 14, 19, 10, 897761

        record = TestTypeModel.new start_time: string_value
        assert_equal expected_time, record.start_time

        record.save!
        record.reload
        assert_equal expected_time, record.start_time

        assert_equal record, TestTypeModel.find_by(start_time: string_value)
      ensure
        TestTypeModel.time_zone_aware_attributes = false
        TestTypeModel.reset_column_information
        ::Time.zone = old_zone
      end

      def test_string_value_with_paris_timezone
        old_zone = ::Time.zone
        ::Time.zone = "Paris" # Paris is UTC+2 in July (DST)
        TestTypeModel.time_zone_aware_attributes = true
        TestTypeModel.reset_column_information

        begin
          string_value = "2017-07-04 14:19:10.897761123"
          # 14:19:10 in Paris (DST) is 12:19:10 UTC
          # Subseconds: 897761123 nanoseconds = 897761.123 microseconds
          expected_time = ::Time.zone.local(2017, 7, 4, 14, 19, 10, Rational(897761123, 1000))

          record = TestTypeModel.new start_time: string_value
          assert_equal expected_time, record.start_time
          assert_equal 897761123, record.start_time.nsec
          assert_instance_of ActiveSupport::TimeWithZone, record.start_time
          assert_equal "Paris", record.start_time.time_zone.name

          record.save!
          
          # Verify directly in the database using the raw Spanner client (bypasses ActiveRecord)
          raw_client = Google::Cloud::Spanner.new(
            project: connector_config["project"],
            emulator_host: connector_config["emulator_host"]
          )
          db_client = raw_client.client(
            connector_config["instance"],
            connector_config["database"]
          )
          
          results = db_client.execute "SELECT start_time FROM test_types WHERE id = #{record.id}"
          raw_value = results.rows.first[:start_time]
          
          # Spanner client returns TIMESTAMP as a UTC Time object
          expected_raw_time = ::Time.utc(2017, 7, 4, 12, 19, 10, Rational(897761123, 1000))
          assert_equal expected_raw_time, raw_value
          assert_equal 897761123, raw_value.nsec
          assert_equal "UTC", raw_value.zone

          record.reload

          assert_equal expected_time, record.start_time
          assert_equal 897761123, record.start_time.nsec
          assert_instance_of ActiveSupport::TimeWithZone, record.start_time
          assert_equal "Paris", record.start_time.time_zone.name
        ensure
          TestTypeModel.time_zone_aware_attributes = false
          TestTypeModel.reset_column_information
          ::Time.zone = old_zone
        end
      end

      def test_string_value_with_utc_and_local_timezones
        # 1. With 'Z' (UTC)
        string_value_utc = "2017-07-04 14:19:10.897761123Z"
        expected_time_utc = ::Time.utc 2017, 7, 4, 14, 19, 10, Rational(897761123, 1000)
        record = TestTypeModel.new start_time: string_value_utc
        assert_equal expected_time_utc, record.start_time
        assert_equal 897761123, record.start_time.nsec

        # 2. With Offset (+02:00)
        string_value_offset = "2017-07-04 14:19:10.897761123+02:00"
        # 14:19:10+02:00 is 12:19:10 UTC
        expected_time_offset = ::Time.utc 2017, 7, 4, 12, 19, 10, Rational(897761123, 1000)
        record = TestTypeModel.new start_time: string_value_offset
        assert_equal expected_time_offset, record.start_time
        assert_equal 897761123, record.start_time.nsec

        # 3. Without offset, but with ActiveRecord.default_timezone = :local
        old_default_timezone = ActiveRecord.default_timezone
        ActiveRecord.default_timezone = :local
        begin
          string_value_no_offset = "2017-07-04 14:19:10.897761123"
          # Should be interpreted as local time
          expected_time_local = ::Time.local 2017, 7, 4, 14, 19, 10, Rational(897761123, 1000)
          record = TestTypeModel.new start_time: string_value_no_offset
          assert_equal expected_time_local, record.start_time
          assert_equal 897761123, record.start_time.nsec
        ensure
          ActiveRecord.default_timezone = old_default_timezone
        end
      end
    end
  end
end
