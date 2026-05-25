# frozen_string_literal: true

module Deftones
  module DSP
    module Helpers
      DENORMAL_THRESHOLD = 1.0e-300

      module_function

      def clamp(value, min_value, max_value)
        [[value, min_value].max, max_value].min
      end

      def lerp(from, to, progress)
        from + ((to - from) * progress)
      end

      def mix(dry, wet, wet_amount)
        (dry * (1.0 - wet_amount)) + (wet * wet_amount)
      end

      def soft_clip(value, drive = 1.0)
        Math.tanh(value * drive)
      end

      def flush_denormal(value)
        sample = value.to_f
        sample.abs < DENORMAL_THRESHOLD ? 0.0 : sample
      end
    end
  end
end
