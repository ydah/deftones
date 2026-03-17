# frozen_string_literal: true

module Deftones
  module Component
    class MultibandSplit < Core::AudioNode
      attr_reader :input, :high, :high_frequency, :low, :low_frequency, :mid, :output, :q

      def initialize(low_frequency: 400.0, high_frequency: 2_500.0, q: 1.0, context: Deftones.context)
        super(context: context)
        @input = Core::Gain.new(context: context)
        @output = self
        @low_frequency = Core::Signal.new(value: low_frequency, units: :frequency, context: context)
        @high_frequency = Core::Signal.new(value: high_frequency, units: :frequency, context: context)
        @q = Core::Signal.new(value: q, units: :number, context: context)
        @low = OutputTap.new(parent: self, band: :low, context: context)
        @mid = OutputTap.new(parent: self, band: :mid, context: context)
        @high = OutputTap.new(parent: self, band: :high, context: context)
        @low_filters = []
        @mid_highpasses = []
        @mid_lowpasses = []
        @high_filters = []
      end

      def render(num_frames, start_frame = 0, cache = {})
        render_block(num_frames, start_frame, cache).mono
      end

      def render_band(band, num_frames, start_frame = 0, cache = {})
        render_band_block(band, num_frames, start_frame, cache).mono
      end

      def render_block(num_frames, start_frame = 0, cache = {})
        cache_key = [object_id, :block, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        bands = render_bands_block(num_frames, start_frame, cache)
        channels = bands[:low].channels
        output = Core::AudioBlock.silent(num_frames, channels)
        output.mix!(bands[:low]).mix!(bands[:mid]).mix!(bands[:high])

        cache[cache_key] = output
        output.dup
      end

      def render_band_block(band, num_frames, start_frame = 0, cache = {})
        render_bands_block(num_frames, start_frame, cache).fetch(band).dup
      end

      def reset!
        [@low_filters, @mid_highpasses, @mid_lowpasses, @high_filters].each do |filters|
          filters.each(&:reset!)
        end
        self
      end

      private

      def render_bands_block(num_frames, start_frame, cache)
        cache_key = [object_id, :bands_block, start_frame, num_frames]
        return cache.fetch(cache_key) if cache.key?(cache_key)

        input_block = @input.send(:render_block, num_frames, start_frame, cache)
        update_filters(input_block.channels, start_frame)

        low = Array.new(input_block.channels) { Array.new(num_frames, 0.0) }
        mid = Array.new(input_block.channels) { Array.new(num_frames, 0.0) }
        high = Array.new(input_block.channels) { Array.new(num_frames, 0.0) }

        input_block.channel_data.each_with_index do |channel, channel_index|
          num_frames.times do |index|
            sample = channel[index]
            low[channel_index][index] = @low_filters[channel_index].process_sample(sample)
            mid[channel_index][index] =
              @mid_lowpasses[channel_index].process_sample(@mid_highpasses[channel_index].process_sample(sample))
            high[channel_index][index] = @high_filters[channel_index].process_sample(sample)
          end
        end

        cache[cache_key] = {
          low: Core::AudioBlock.from_channel_data(low),
          mid: Core::AudioBlock.from_channel_data(mid),
          high: Core::AudioBlock.from_channel_data(high)
        }
      end

      def update_filters(channels, start_frame)
        ensure_filter_banks(channels)
        current_low_frequency = @low_frequency.process(1, start_frame).first
        current_high_frequency = @high_frequency.process(1, start_frame).first
        current_q = @q.process(1, start_frame).first

        @low_filters.each do |filter|
          filter.update(type: :lowpass, frequency: current_low_frequency, q: current_q, gain_db: 0.0, sample_rate: context.sample_rate)
        end
        @mid_highpasses.each do |filter|
          filter.update(type: :highpass, frequency: current_low_frequency, q: current_q, gain_db: 0.0, sample_rate: context.sample_rate)
        end
        @mid_lowpasses.each do |filter|
          filter.update(type: :lowpass, frequency: current_high_frequency, q: current_q, gain_db: 0.0, sample_rate: context.sample_rate)
        end
        @high_filters.each do |filter|
          filter.update(type: :highpass, frequency: current_high_frequency, q: current_q, gain_db: 0.0, sample_rate: context.sample_rate)
        end
      end

      def ensure_filter_banks(channels)
        required = [channels.to_i, 1].max
        while @low_filters.length < required
          @low_filters << DSP::Biquad.new
          @mid_highpasses << DSP::Biquad.new
          @mid_lowpasses << DSP::Biquad.new
          @high_filters << DSP::Biquad.new
        end
      end

      class OutputTap < Core::AudioNode
        def initialize(parent:, band:, context: Deftones.context)
          super(context: context)
          @parent = parent
          @band = band
        end

        def render(num_frames, start_frame = 0, cache = {})
          @parent.render_band(@band, num_frames, start_frame, cache)
        end

        def render_block(num_frames, start_frame = 0, cache = {})
          @parent.render_band_block(@band, num_frames, start_frame, cache)
        end
      end
    end
  end
end
