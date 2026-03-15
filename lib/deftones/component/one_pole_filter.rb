# frozen_string_literal: true

module Deftones
  module Component
    class OnePoleFilter < Core::AudioNode
      TYPES = %i[lowpass highpass].freeze

      attr_reader :frequency
      attr_accessor :type

      def initialize(frequency: 880.0, type: :lowpass, context: Deftones.context)
        super(context: context)
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @type = normalize_type(type)
        @lowpass_state = 0.0
      end

      def frequency=(value)
        @frequency.value = value
      end

      def process(input_buffer, num_frames, start_frame, _cache)
        frequencies = @frequency.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          input_sample = input_buffer[index]
          coefficient = coefficient_for(frequencies[index])
          @lowpass_state += (1.0 - coefficient) * (input_sample - @lowpass_state)

          if normalize_type(@type) == :lowpass
            @lowpass_state
          else
            input_sample - @lowpass_state
          end
        end
      end

      def reset!
        @lowpass_state = 0.0
        self
      end

      private

      def coefficient_for(frequency)
        normalized = [[frequency.to_f, 1.0].max, (context.sample_rate * 0.49)].min
        Math.exp((-2.0 * Math::PI * normalized) / context.sample_rate)
      end

      def normalize_type(type)
        normalized = type.to_sym
        return normalized if TYPES.include?(normalized)

        raise ArgumentError, "Unsupported one pole filter type: #{type}"
      end
    end
  end
end
