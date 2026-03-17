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
        @lowpass_state = []
      end

      def frequency=(value)
        @frequency.value = value
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        frequencies = @frequency.process(num_frames, start_frame)
        ensure_state(input_block.channels)
        output_channels = input_block.channel_data.each_with_index.map do |channel, channel_index|
          Array.new(num_frames) do |index|
            input_sample = channel[index]
            coefficient = coefficient_for(frequencies[index])
            @lowpass_state[channel_index] += (1.0 - coefficient) * (input_sample - @lowpass_state[channel_index])

            if normalize_type(@type) == :lowpass
              @lowpass_state[channel_index]
            else
              input_sample - @lowpass_state[channel_index]
            end
          end
        end

        Core::AudioBlock.from_channel_data(output_channels)
      end

      def reset!
        @lowpass_state = []
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

      def ensure_state(channels)
        required = [channels.to_i, 1].max
        @lowpass_state.fill(0.0, @lowpass_state.length...required)
      end
    end
  end
end
