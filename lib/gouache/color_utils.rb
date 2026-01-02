# frozen_string_literal: true

require "matrix"
require_relative "utils"

class Gouache
  module ColorUtils
    module_function

    using RegexpWrap
    REL_CHROMA       = / (        1(?:\.0+)? | 0 | 0? \. \d+ )? max /x.w
    REL_CHROMA_DELTA = / ( -? (?: 1(?:\.0+)? | 0 | 0? \. \d+ )) max /x.w

    # constants

    SRGB_MAX = 255.0

    SRGB_GAMMA_THRESHOLD  = 0.04045
    SRGB_GAMMA_FACTOR     = 12.92
    SRGB_GAMMA_A          = 0.055
    SRGB_GAMMA_DIV        = 1.055
    SRGB_GAMMA_GAMMA      = 2.4

    LINEAR_SRGB_THRESHOLD = 0.0031308
    LINEAR_SRGB_FACTOR    = 12.92
    LINEAR_SRGB_A         = 0.055
    LINEAR_SRGB_SCALE     = 1.055
    LINEAR_SRGB_GAMMA_INV = 1.0 / 2.4

    DEG_PER_RAD = 180.0 / Math::PI

    # matrices

    LMS_FROM_LINEAR_SRGB = Matrix[
      [0.4122214708, 0.5363325363, 0.0514459929],
      [0.2119034982, 0.6806995451, 0.1073969566],
      [0.0883024619, 0.2817188376, 0.6299787005]]

    OKLAB_FROM_LMS = Matrix[
      [0.2104542553,  0.7936177850, -0.0040720468],
      [1.9779984951, -2.4285922050,  0.4505937099],
      [0.0259040371,  0.7827717662, -0.8086757660]]

    LMS_FROM_OKLAB = Matrix[
      [1.0,  0.3963377774,  0.2158037573],
      [1.0, -0.1055613458, -0.0638541728],
      [1.0, -0.0894841775, -1.2914855480]]

    LINEAR_SRGB_FROM_LMS = Matrix[
      [ 4.0767416621, -3.3077115913,  0.2309699292],
      [-1.2684380046,  2.6097574011, -0.3413193965],
      [-0.0041960863, -0.7034186147,  1.7076147010]]

    # helpers

    def cbrt_vec(v)
      Vector[*v.map{|x| x < 0 ? -(-x)**(1.0 / 3.0) : x**(1.0 / 3.0) }]
    end

    def linear_rgb_from_srgb8(srgb8)
      Vector[*srgb8.map do |c|
        c /= SRGB_MAX
        next c / SRGB_GAMMA_FACTOR if c <= SRGB_GAMMA_THRESHOLD
        ((c + SRGB_GAMMA_A) / SRGB_GAMMA_DIV) ** SRGB_GAMMA_GAMMA
      end]
    end

    def srgb8_from_linear_rgb(lin)
      lin.map do |c|
        c = c.clamp(0.0, 1.0)
        next (c * LINEAR_SRGB_FACTOR * SRGB_MAX).round if c <= LINEAR_SRGB_THRESHOLD
        ((LINEAR_SRGB_SCALE * c**LINEAR_SRGB_GAMMA_INV - LINEAR_SRGB_A) * SRGB_MAX).round
      end
    end

    def oklch_in_srgb_gamut?(oklch)
      oklab = oklab_from_oklch oklch
      lms   = LMS_FROM_OKLAB * Vector[*oklab]
      lin   = LINEAR_SRGB_FROM_LMS * Vector[*lms.map { it**3 }]
      lin.all?(0.0..1.0)
    end

    # max oklch C for l,h in srgb space
    def cmax(l, h)
      lo = 0.0
      hi = 0.4 # OKLCH sRGB upper bound
      30.times do
        mid = (lo + hi) / 2
        oklch_in_srgb_gamut?([l, mid, h]) ? lo = mid : hi = mid
      end
      lo
    end

    # conversions

    def oklab_from_srgb8(srgb8)
      lin = linear_rgb_from_srgb8(srgb8)
      lms = LMS_FROM_LINEAR_SRGB * lin
      (OKLAB_FROM_LMS * cbrt_vec(lms)).to_a
    end

    def srgb8_from_oklab(oklab)
      lms = LMS_FROM_OKLAB * Vector[*oklab]
      lin = LINEAR_SRGB_FROM_LMS * Vector[*lms.map{ it**3 }]
      srgb8_from_linear_rgb(lin.to_a)
    end

    def oklch_from_oklab((l,a,b))
      c = Math.sqrt(a*a + b*b)
      h = Math.atan2(b, a) * DEG_PER_RAD
      h += 360 if h < 0
      [l, c, h]
    end

    def oklab_from_oklch((l,c,h))
      r = h / DEG_PER_RAD
      [l, c * Math.cos(r), c * Math.sin(r)]
    end

    def oklch_from_srgb8(srgb8) = oklch_from_oklab oklab_from_srgb8 srgb8

    def srgb8_from_oklch(oklch) = srgb8_from_oklab oklab_from_oklch oklch

    # Convert OKLCH with possible relative chroma to absolute OKLCH.
    #
    # Arguments:
    #   l      = lightness ∈ 0.0..1.0
    #   cr_or_c = chroma value, either:
    #             - Numeric: absolute chroma ∈ 0.0..
    #             - "CRmax": relative chroma (CR * cmax at L,H)
    #                        CR = float in 0.0..1.0, or empty for 1.0
    #             - "max": equivalent to "1.0max" (maximum chroma)
    #   h      = hue in degrees
    #
    # Returns:
    #   [L, C, H] with absolute chroma
    #
    # Validates that the result is within valid OKLCH bounds.
    def oklch_from_maybe_relative_chroma((l, cr_or_c, h))
      cm = cmax(l, h)
      c = (cr_or_c in REL_CHROMA) ? ($1||1).to_f * cm : cr_or_c
      [l, c, h] in [0.0..1.0, ^(0.0..cm), Numeric] or raise ArgumentError
      [l, c, h]
    end

    # shifts


    # Shift an OKLCH color with mixed absolute, delta, and relative-chroma semantics.
    #
    # Arguments:
    #   lch  = [L, C, H]
    #     L ∈ 0.0..1.0
    #     C = absolute OKLCH chroma ∈ 0.0..
    #     H = hue in degrees
    #
    #   dlch = [dL, dC, dH]
    #
    # Semantics per dlch component:
    #
    #   L, H:
    #     Numeric   → delta (x + d)
    #     [Numeric] → absolute replace
    #
    #   C:
    #     Numeric   → delta C
    #     [Numeric] → absolute C
    #     ["CRmax"] → absolute using relative chroma
    #                 (CR * Cmax at new L,H)
    #                 CR = float in 0.0..1.0
    #     "±CRmax"  → relative chroma delta
    #                 ( (C / cmax(old L,H)) ± CR ) * cmax(new L,H)
    #                 CR = float in -1.0..1.0
    #     nil       → keep relative chroma (same as "0max")
    #
    # Relative chroma expresses chroma as a fraction of the maximum in-gamut
    # chroma at a given lightness and hue, providing a stable 0–1 control that
    # preserves perceived intensity across lightness and hue changes.
    #
    # Behavior:
    #   - L is clamped to 0.0..1.0
    #   - H wraps modulo 360
    #   - C is clamped to 0.0..cmax(L,H)
    #   - Relative chroma is defined as C / cmax(L,H)
    #   - Relative chroma operations are gamut-aware (sRGB via OKLab).
    def oklch_shift(lch, dlch)
      raise ArgumentError unless lch in [
        0..1,
        0.. | REL_CHROMA,
        Numeric]

      raise ArgumentError unless dlch in [
        Numeric | [Numeric],
        Numeric | [Numeric] | REL_CHROMA_DELTA | [REL_CHROMA] | nil,
        Numeric | [Numeric]]

      l_, c_, h_ = lch.zip(dlch).map do |x, d|
        case d
        in Numeric        then x + d
        in [Numeric => n] then n
        else nil
        end
      end

      l, c, h = lch
      l_  = l_.clamp(0.0, 1.0)
      h_  = h_ % 360
      cm  = cmax(l, h)
      cm_ = cmax(l_, h_)

      c_ ||= case dlch
             in [_, [REL_CHROMA] ,_]    then ($1||1).to_f * cm_
             in [_, REL_CHROMA_DELTA,_] then (c / cm + $1.to_f) * cm_
             in [_, nil, _]             then (c / cm) * cm_
             end

      c_ = c_.clamp(0.0, cmax(l_, h_))

      [l_, c_, h_]
    end

    ABS = 0.0..255.0
    DELTA_OR_ABS = ->{ it in Numeric | [ABS] }
    def srgb8_shift(rgb8, drgb)
      raise ArgumentError unless rgb8 in [ABS, ABS, ABS]
      raise ArgumentError unless drgb in [DELTA_OR_ABS, DELTA_OR_ABS, DELTA_OR_ABS]
      rgb8.zip(drgb).map do |x, d|
        case d
        in Numeric        then x + d
        in [Numeric => n] then n
        end.clamp(0, 255).round
      end
    end


    # distance

    DIST_WEIGHTS = [1.5, 1.0, 1.0]
    def oklab_distance_from_srgb8(srgb8_a, srgb8_b, weights: DIST_WEIGHTS)
      a = oklab_from_srgb8(srgb8_a)
      b = oklab_from_srgb8(srgb8_b)
      Math.sqrt a.zip(b, weights).sum{|a,b,w| ((b-a)*w)**2 }
    end

  end
end
