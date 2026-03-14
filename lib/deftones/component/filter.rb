# frozen_string_literal: true

module Deftones
  module Component
    class Filter < Core::AudioNode
      TYPES = DSP::Biquad::TYPES

      attr_reader :frequency, :q, :gain
      attr_accessor :type

      def initialize(type: :lowpass, frequency: 350.0, q: 1.0, gain: 0.0, context: Deftones.context)
        super(context: context)
        @type = normalize_type(type)
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @q = Core::Signal.new(value: q, units: :number, context: context)
        @gain = Core::Signal.new(value: gain, units: :number, context: context)
        @biquad = DSP::Biquad.new
      end

      def process(input_buffer, num_frames, start_frame, _cache)
        update_filter(start_frame)
        Array.new(num_frames) do |index|
          @biquad.process_sample(input_buffer[index])
        end
      end

      def reset!
        @biquad.reset!
        self
      end

      private

      def update_filter(start_frame)
        @biquad.update(
          type: normalize_type(@type),
          frequency: @frequency.process(1, start_frame).first,
          q: @q.process(1, start_frame).first,
          gain_db: @gain.process(1, start_frame).first * 24.0,
          sample_rate: context.sample_rate
        )
      end

      def normalize_type(type)
        normalized = type.to_sym
        return normalized if TYPES.include?(normalized)

        raise ArgumentError, "Unsupported filter type: #{type}"
      end
    end
  end
end
