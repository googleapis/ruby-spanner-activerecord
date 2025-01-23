# frozen_string_literal: true

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
