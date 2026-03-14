# frozen_string_literal: true

module Deftones
  module Component
    class EQ3 < Core::AudioNode
      attr_accessor :low, :mid, :high
      attr_reader :low_frequency, :high_frequency

      def initialize(low: 0.0, mid: 0.0, high: 0.0, low_frequency: 400.0,
                     high_frequency: 2_500.0, context: Deftones.context)
        super(context: context)
        @low = low.to_f
        @mid = mid.to_f
        @high = high.to_f
        @low_frequency = Core::Signal.new(value: low_frequency, units: :frequency, context: context)
        @high_frequency = Core::Signal.new(value: high_frequency, units: :frequency, context: context)
        @low_shelf = DSP::Biquad.new
        @mid_peak = DSP::Biquad.new
        @high_shelf = DSP::Biquad.new
      end

      def process(input_buffer, num_frames, start_frame, _cache)
        update_filters(start_frame)

        Array.new(num_frames) do |index|
          sample = input_buffer[index]
          sample = @low_shelf.process_sample(sample)
          sample = @mid_peak.process_sample(sample)
          @high_shelf.process_sample(sample)
        end
      end

      private

      def update_filters(start_frame)
        low_frequency = @low_frequency.process(1, start_frame).first
        high_frequency = @high_frequency.process(1, start_frame).first

        @low_shelf.update(type: :lowshelf, frequency: low_frequency, q: 0.707, gain_db: @low, sample_rate: context.sample_rate)
        @mid_peak.update(type: :peaking, frequency: Math.sqrt(low_frequency * high_frequency), q: 0.8, gain_db: @mid, sample_rate: context.sample_rate)
        @high_shelf.update(type: :highshelf, frequency: high_frequency, q: 0.707, gain_db: @high, sample_rate: context.sample_rate)
      end
    end
  end
end
