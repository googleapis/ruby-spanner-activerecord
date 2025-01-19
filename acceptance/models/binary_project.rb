# Copyright 2025 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require_relative 'string_io'

class BinaryProject < ActiveRecord::Base
  belongs_to :owner, class_name: 'User'

  before_create :set_uuid
  private

  def set_uuid
    self.id ||= StringIO.new(SecureRandom.random_bytes(16))
  end
end
