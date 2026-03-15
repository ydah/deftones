# frozen_string_literal: true

module Deftones
  module Core
    class ComputedSignal < Signal
      attr_reader :input

      def initialize(input:, units: nil, context: nil)
        resolved_context = resolve_context(input, fallback: context)
        resolved_units = units || default_units(input)

        super(value: 0.0, units: resolved_units, context: resolved_context)
        @input = coerce_signal(input || 0.0, units: resolved_units)
      end

      def value
        value_at(context.current_time)
      end

      def value=(_new_value)
        raise Deftones::Error, "#{self.class.name} is derived and cannot be assigned"
      end

      def ramp_to(*)
        raise Deftones::Error, "#{self.class.name} is derived and cannot be automated directly"
      end

      alias linear_ramp_to ramp_to
      alias exponential_ramp_to ramp_to
      alias set_value_at_time ramp_to
      alias cancel_scheduled_values ramp_to

      def process(num_frames, start_frame = 0)
        Array.new(num_frames) do |offset|
          value_at(sample_time(start_frame + offset))
        end
      end

      private

      def default_units(candidate)
        candidate.respond_to?(:units) ? candidate.units : :number
      end

      def resolve_context(candidate, fallback:)
        return candidate.context if candidate.respond_to?(:context)
        return fallback if fallback

        Deftones.context
      end

      def coerce_signal(value, units:)
        return value if value.respond_to?(:value_at)

        Signal.new(value: value, units: units, context: context)
      end

      def exponentiate(value, exponent)
        return value**exponent if value >= 0.0 || integer_like?(exponent)

        -((-value)**exponent)
      end

      def integer_like?(value)
        value.finite? && value.round == value
      end
    end
  end
end
