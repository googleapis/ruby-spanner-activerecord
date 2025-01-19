# Copyright 2025 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

# Add equality and hash functions to StringIO to use it for sets.
class StringIO
  def ==(o)
    o.class == self.class && self.to_base64 == o.to_base64
  end

  def eql?(o)
    self == o
  end

  def hash
    to_base64.hash
  end

  def to_base64
    self.rewind
    value = self.read
    Base64.strict_encode64 value.force_encoding("ASCII-8BIT")
  end
end
