# frozen_string_literal: true

#
# Ported from nlohmann/json 3.11.3:
# https://github.com/nlohmann/json/blob/v3.11.3/include/nlohmann/detail/conversions/to_chars.hpp
# Copyright (c) 2009 Florian Loitsch
# Copyright (c) 2013-2023 Niels Lohmann
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module ActiveRecordSpannerAdapter
  # Reproduces nlohmann/json's binary64 Grisu2 conversion, including its choice
  # of decimal digits when multiple representations round to the same Float.
  module FloatFormatter
    HIDDEN_BIT = 1 << 52
    SIGN_BIT = 1 << 63
    CACHED_POWERS = [
      [0xAB70FE17C79AC6CA, -1060, -300].freeze,
      [0xFF77B1FCBEBCDC4F, -1034, -292].freeze,
      [0xBE5691EF416BD60C, -1007, -284].freeze,
      [0x8DD01FAD907FFC3C, -980, -276].freeze,
      [0xD3515C2831559A83, -954, -268].freeze,
      [0x9D71AC8FADA6C9B5, -927, -260].freeze,
      [0xEA9C227723EE8BCB, -901, -252].freeze,
      [0xAECC49914078536D, -874, -244].freeze,
      [0x823C12795DB6CE57, -847, -236].freeze,
      [0xC21094364DFB5637, -821, -228].freeze,
      [0x9096EA6F3848984F, -794, -220].freeze,
      [0xD77485CB25823AC7, -768, -212].freeze,
      [0xA086CFCD97BF97F4, -741, -204].freeze,
      [0xEF340A98172AACE5, -715, -196].freeze,
      [0xB23867FB2A35B28E, -688, -188].freeze,
      [0x84C8D4DFD2C63F3B, -661, -180].freeze,
      [0xC5DD44271AD3CDBA, -635, -172].freeze,
      [0x936B9FCEBB25C996, -608, -164].freeze,
      [0xDBAC6C247D62A584, -582, -156].freeze,
      [0xA3AB66580D5FDAF6, -555, -148].freeze,
      [0xF3E2F893DEC3F126, -529, -140].freeze,
      [0xB5B5ADA8AAFF80B8, -502, -132].freeze,
      [0x87625F056C7C4A8B, -475, -124].freeze,
      [0xC9BCFF6034C13053, -449, -116].freeze,
      [0x964E858C91BA2655, -422, -108].freeze,
      [0xDFF9772470297EBD, -396, -100].freeze,
      [0xA6DFBD9FB8E5B88F, -369, -92].freeze,
      [0xF8A95FCF88747D94, -343, -84].freeze,
      [0xB94470938FA89BCF, -316, -76].freeze,
      [0x8A08F0F8BF0F156B, -289, -68].freeze,
      [0xCDB02555653131B6, -263, -60].freeze,
      [0x993FE2C6D07B7FAC, -236, -52].freeze,
      [0xE45C10C42A2B3B06, -210, -44].freeze,
      [0xAA242499697392D3, -183, -36].freeze,
      [0xFD87B5F28300CA0E, -157, -28].freeze,
      [0xBCE5086492111AEB, -130, -20].freeze,
      [0x8CBCCC096F5088CC, -103, -12].freeze,
      [0xD1B71758E219652C, -77, -4].freeze,
      [0x9C40000000000000, -50, 4].freeze,
      [0xE8D4A51000000000, -24, 12].freeze,
      [0xAD78EBC5AC620000, 3, 20].freeze,
      [0x813F3978F8940984, 30, 28].freeze,
      [0xC097CE7BC90715B3, 56, 36].freeze,
      [0x8F7E32CE7BEA5C70, 83, 44].freeze,
      [0xD5D238A4ABE98068, 109, 52].freeze,
      [0x9F4F2726179A2245, 136, 60].freeze,
      [0xED63A231D4C4FB27, 162, 68].freeze,
      [0xB0DE65388CC8ADA8, 189, 76].freeze,
      [0x83C7088E1AAB65DB, 216, 84].freeze,
      [0xC45D1DF942711D9A, 242, 92].freeze,
      [0x924D692CA61BE758, 269, 100].freeze,
      [0xDA01EE641A708DEA, 295, 108].freeze,
      [0xA26DA3999AEF774A, 322, 116].freeze,
      [0xF209787BB47D6B85, 348, 124].freeze,
      [0xB454E4A179DD1877, 375, 132].freeze,
      [0x865B86925B9BC5C2, 402, 140].freeze,
      [0xC83553C5C8965D3D, 428, 148].freeze,
      [0x952AB45CFA97A0B3, 455, 156].freeze,
      [0xDE469FBD99A05FE3, 481, 164].freeze,
      [0xA59BC234DB398C25, 508, 172].freeze,
      [0xF6C69A72A3989F5C, 534, 180].freeze,
      [0xB7DCBF5354E9BECE, 561, 188].freeze,
      [0x88FCF317F22241E2, 588, 196].freeze,
      [0xCC20CE9BD35C78A5, 614, 204].freeze,
      [0x98165AF37B2153DF, 641, 212].freeze,
      [0xE2A0B5DC971F303A, 667, 220].freeze,
      [0xA8D9D1535CE3B396, 694, 228].freeze,
      [0xFB9B7CD9A4A7443C, 720, 236].freeze,
      [0xBB764C4CA7A44410, 747, 244].freeze,
      [0x8BAB8EEFB6409C1A, 774, 252].freeze,
      [0xD01FEF10A657842C, 800, 260].freeze,
      [0x9B10A4E5E9913129, 827, 268].freeze,
      [0xE7109BFBA19C0C9D, 853, 276].freeze,
      [0xAC2820D9623BF429, 880, 284].freeze,
      [0x80444B5E7AA7CF85, 907, 292].freeze,
      [0xBF21E44003ACDD2D, 933, 300].freeze,
      [0x8E679C2F5E44FF8F, 960, 308].freeze,
      [0xD433179D9C8CB841, 986, 316].freeze,
      [0x9E19DB92B4E31BA9, 1013, 324].freeze
    ].freeze

    class << self
      def serialize_float value
        raise TypeError, "expected a Float" unless value.is_a? Float
        raise ArgumentError, "expected a finite Float" unless value.finite?

        bits = [value].pack("G").unpack1("Q>")
        sign = bits & SIGN_BIT == 0 ? "" : "-"
        bits &= SIGN_BIT - 1
        return "#{sign}0.0" if bits.zero?

        digits, exponent = grisu2 bits
        sign + format_digits(digits, exponent)
      end

      private

      def grisu2 bits # rubocop:disable Metrics/AbcSize
        ieee_exponent = bits >> 52
        fraction = bits & (HIDDEN_BIT - 1)
        significand = ieee_exponent.zero? ? fraction : fraction + HIDDEN_BIT
        exponent = ieee_exponent.zero? ? -1074 : ieee_exponent - 1075

        plus = (2 * significand) + 1
        plus_exponent = exponent - 1
        shift = 64 - plus.bit_length
        plus <<= shift
        plus_exponent -= shift

        # Powers of two have a closer lower neighbor, except at the normal/subnormal boundary.
        if fraction.zero? && ieee_exponent > 1
          minus = (4 * significand) - 1
          minus_exponent = exponent - 2
        else
          minus = (2 * significand) - 1
          minus_exponent = exponent - 1
        end
        minus <<= minus_exponent - plus_exponent
        significand <<= 64 - significand.bit_length

        cached_significand, cached_exponent, cached_decimal_exponent = cached_power plus_exponent
        scaled_exponent = plus_exponent + cached_exponent + 64
        scaled_value = multiply significand, cached_significand
        # Tighten both bounds to account for multiplication rounding error.
        scaled_minus = multiply(minus, cached_significand) + 1
        scaled_plus = multiply(plus, cached_significand) - 1

        generate_digits(scaled_minus, scaled_value, scaled_plus, scaled_exponent, -cached_decimal_exponent)
      end

      # The native multiplication retains the high 64 bits and rounds ties up.
      def multiply left, right
        ((left * right) + SIGN_BIT) >> 64
      end

      def cached_power exponent
        f = -61 - exponent
        # C++ integer division truncates toward zero; Ruby's division floors.
        k = f.positive? ? ((f * 78_913) >> 18) + 1 : -((-f * 78_913) >> 18)
        CACHED_POWERS[(300 + k + 7) / 8]
      end

      def generate_digits minus, value, plus, exponent, decimal_exponent # rubocop:disable Metrics/AbcSize
        delta = plus - minus
        distance = plus - value
        shift = -exponent
        one = 1 << shift
        integral = plus >> shift
        fraction = plus & (one - 1)
        length = integral.to_s.length
        power_of_ten = 10**(length - 1)
        digits = +""

        while length.positive?
          digit, integral = integral.divmod power_of_ten
          digits << (48 + digit)
          length -= 1
          rest = (integral << shift) + fraction
          if rest <= delta
            round_digits digits, distance, delta, rest, power_of_ten << shift
            return [digits, decimal_exponent + length]
          end
          power_of_ten /= 10
        end

        loop do
          fraction *= 10
          digit = fraction >> shift
          fraction &= one - 1
          digits << (48 + digit)
          decimal_exponent -= 1
          delta *= 10
          distance *= 10
          next if fraction > delta

          round_digits digits, distance, delta, fraction, one
          return [digits, decimal_exponent]
        end
      end

      def round_digits digits, distance, delta, rest, unit
        while rest < distance && delta - rest >= unit &&
              (rest + unit < distance || distance - rest > rest + unit - distance)
          last = digits.length - 1
          digits.setbyte last, digits.getbyte(last) - 1
          rest += unit
        end
      end

      def format_digits digits, exponent
        length = digits.length
        point = length + exponent
        if length <= point && point <= 15
          "#{digits}#{'0' * (point - length)}.0"
        elsif point.positive? && point <= 15
          "#{digits[0, point]}.#{digits[point..]}"
        elsif point > -4 && point <= 0
          "0.#{'0' * -point}#{digits}"
        else
          mantissa = length == 1 ? digits : "#{digits[0]}.#{digits[1..]}"
          scientific_exponent = point - 1
          sign = scientific_exponent.negative? ? "-" : "+"
          "#{mantissa}e#{sign}#{scientific_exponent.abs.to_s.rjust 2, '0'}"
        end
      end
    end
  end
end
