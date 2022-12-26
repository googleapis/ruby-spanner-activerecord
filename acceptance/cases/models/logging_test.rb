# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "active_support/log_subscriber/test_helper"
require "test_helper"
require "models/post"

module ActiveRecord
  module Model
    class LoggingTest < SpannerAdapter::TestCase
      include ActiveSupport::LogSubscriber::TestHelper

      setup do
        ActiveRecord::LogSubscriber.attach_to(:active_record)
      end

      def test_logs_without_binds
        published_time = Time.new(2016, 05, 11, 19, 0, 0)
        Post.where(published_time: published_time, title: 'Title - 1').first

        wait
        assert @logger.logged(:debug).length >= 1
        assert_no_match "[[\"published_time\", \"#{published_time.utc.iso8601(9)}\"], [\"title\", \"Title - 1\"]",
                        @logger.logged(:debug).last
      end

      def test_logs_with_binds
        ActiveRecord::ConnectionAdapters::SpannerAdapter.log_statement_binds = true

        published_time = Time.new(2016, 05, 11, 19, 0, 0)
        Post.where(published_time: published_time, title: 'Title - 1').first

        wait
        assert @logger.logged(:debug).length >= 1
        assert_match "[[\"published_time\", \"#{published_time.utc.iso8601(9)}\"], [\"title\", \"Title - 1\"]",
                     @logger.logged(:debug).last
      ensure
        ActiveRecord::ConnectionAdapters::SpannerAdapter.log_statement_binds = false
      end

      private

      def set_logger(logger)
        ActiveRecord::Base.logger = logger
      end
    end
  end
end
