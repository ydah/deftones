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
        @low_shelves = []
        @mid_peaks = []
        @high_shelves = []
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        update_filters(input_block.channels, start_frame)

        Core::AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            low_shelf = @low_shelves[channel_index]
            mid_peak = @mid_peaks[channel_index]
            high_shelf = @high_shelves[channel_index]

            Array.new(num_frames) do |index|
              sample = channel[index]
              sample = low_shelf.process_sample(sample)
              sample = mid_peak.process_sample(sample)
              high_shelf.process_sample(sample)
            end
          end
        )
      end

      private

      def update_filters(channels, start_frame)
        ensure_filter_banks(channels)
        low_frequency = @low_frequency.process(1, start_frame).first
        high_frequency = @high_frequency.process(1, start_frame).first

        @low_shelves.each do |filter|
          filter.update(type: :lowshelf, frequency: low_frequency, q: 0.707, gain_db: @low, sample_rate: context.sample_rate)
        end
        @mid_peaks.each do |filter|
          filter.update(type: :peaking, frequency: Math.sqrt(low_frequency * high_frequency), q: 0.8, gain_db: @mid, sample_rate: context.sample_rate)
        end
        @high_shelves.each do |filter|
          filter.update(type: :highshelf, frequency: high_frequency, q: 0.707, gain_db: @high, sample_rate: context.sample_rate)
        end
      end

      def ensure_filter_banks(channels)
        required = [channels.to_i, 1].max
        while @low_shelves.length < required
          @low_shelves << DSP::Biquad.new
          @mid_peaks << DSP::Biquad.new
          @high_shelves << DSP::Biquad.new
        end
      end
    end
  end
end
