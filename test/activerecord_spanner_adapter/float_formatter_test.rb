# SPDX-License-Identifier: MIT

require "minitest/autorun"
require "digest"
require_relative "../../lib/activerecord_spanner_adapter/float_formatter"

class SpannerFloatFormatterTest < Minitest::Test
  FIXTURES = File.expand_path("../fixtures/float_formatter", __dir__)

  def test_matches_nlohmann_tokens_for_boundary_and_representative_values
    fixture_lines("tokens.txt").each do |line|
      hex, expected, label = line.split("\t")
      value = [hex.to_i(16)].pack("Q>").unpack1("G")
      actual = ActiveRecordSpannerAdapter::FloatFormatter.serialize_float(value)

      assert_equal expected, actual, "#{label} (#{hex})"
      assert_equal [value].pack("G"), [Float(actual)].pack("G"), "#{label} round trip"
    end
  end

  def test_matches_nlohmann_across_all_binary_exponents
    assert_oracle_digest("exponent_boundaries", method(:each_boundary_bits))
  end

  def test_matches_nlohmann_for_deterministic_random_bits
    assert_oracle_digest("random_bits", method(:each_random_bits))
  end

  def test_rejects_nonfinite_floats
    [Float::NAN, Float::INFINITY, -Float::INFINITY].each do |value|
      assert_raises(ArgumentError) do
        ActiveRecordSpannerAdapter::FloatFormatter.serialize_float(value)
      end
    end
  end

  def test_rejects_values_that_are_not_floats
    [nil, true, 1, "1.0", Rational(1, 2), Object.new].each do |value|
      assert_raises(TypeError) do
        ActiveRecordSpannerAdapter::FloatFormatter.serialize_float(value)
      end
    end
  end

  private

  def fixture_lines(name)
    File.readlines(File.join(FIXTURES, name), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
  end

  def assert_oracle_digest(name, corpus)
    fixture = fixture_lines("corpora.sha256").find { |line| line.start_with?("#{name} ") }
    _, expected_count, expected_digest = fixture.split
    digest = Digest::SHA256.new
    count = 0
    corpus.call do |bits|
      value = [bits].pack("Q>").unpack1("G")
      token = ActiveRecordSpannerAdapter::FloatFormatter.serialize_float(value)
      digest << "#{bits.to_s(16).rjust(16, '0')} #{token}\n"
      count += 1
    end

    assert_equal expected_count.to_i, count
    assert_equal expected_digest, digest.hexdigest, "#{name}: Nlohmann 3.11.3 token mismatch"
  end

  def each_boundary_bits
    fractions = [0, 1, 2, (1 << 51) - 1, 1 << 51, (1 << 52) - 2, (1 << 52) - 1]
    (0..2046).each do |exponent|
      fractions.each do |fraction|
        bits = (exponent << 52) | fraction
        yield bits
        yield bits | (1 << 63)
      end
    end
  end

  # This explicit generator keeps the fixture corpus stable across Ruby engines.
  def each_random_bits
    bits = 0x0123456789abcdef
    20_000.times do
      bits = (bits * 6_364_136_223_846_793_005 + 1_442_695_040_888_963_407) & ((1 << 64) - 1)
      next if ((bits >> 52) & 0x7ff) == 0x7ff

      yield bits
    end
  end
end
