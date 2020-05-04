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

# frozen_string_literal: true

require "test_helper"
require "models/firm"
require "models/account"
require "models/department"


module ActiveRecord
  module Associations
    class HasOneTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :firm, :account

      def setup
        super

        @account = Account.create name: "Account - #{rand 1000}", credit_limit: 100
        @firm = Firm.create name: "Firm-#{rand 1000}", account: account

        @account.reload
        @firm.reload
      end

      def teardown
        Firm.destroy_all
        Account.destroy_all
        Department.destroy_all
      end

      def test_has_one
        assert_equal account, firm.account
        assert_equal account.credit_limit, firm.account.credit_limit
      end

      def test_has_one_does_not_use_order_by
        sql_log = capture_sql { firm.account }
        assert sql_log.all? { |sql| !/order by/i.match?(sql) }, "ORDER BY was used in the query: #{sql_log}"
      end

      def test_finding_using_primary_key
        assert_equal Account.find_by(firm_id: firm.id), firm.account
      end

      def test_successful_build_association
        account = firm.build_account(credit_limit: 1000)
        assert account.save

        firm.reload
        assert_equal account, firm.account
      end

      def test_delete_associated_records
        assert_equal account, firm.account

        firm.account.destroy
        firm.reload
        assert_nil firm.account
      end

      def test_polymorphic_association
        assert_equal 0, firm.departments.count

        firm.departments.create(name: "Department - 1")
        firm.reload

        assert_equal 1, firm.departments.count
        assert_equal "Department - 1", firm.departments.first.name
      end
    end
  end
end