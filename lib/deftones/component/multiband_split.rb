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
        @low_filter = DSP::Biquad.new
        @mid_highpass = DSP::Biquad.new
        @mid_lowpass = DSP::Biquad.new
        @high_filter = DSP::Biquad.new
      end

      def render(num_frames, start_frame = 0, cache = {})
        bands = render_bands(num_frames, start_frame, cache)

        Array.new(num_frames) do |index|
          bands[:low][index] + bands[:mid][index] + bands[:high][index]
        end
      end

      def render_band(band, num_frames, start_frame = 0, cache = {})
        render_bands(num_frames, start_frame, cache).fetch(band).dup
      end

      def reset!
        [@low_filter, @mid_highpass, @mid_lowpass, @high_filter].each(&:reset!)
        self
      end

      private

      def render_bands(num_frames, start_frame, cache)
        cache_key = [object_id, :bands, start_frame, num_frames]
        return cache.fetch(cache_key) if cache.key?(cache_key)

        input_buffer = @input.render(num_frames, start_frame, cache)
        update_filters(start_frame)

        low = Array.new(num_frames)
        mid = Array.new(num_frames)
        high = Array.new(num_frames)

        num_frames.times do |index|
          sample = input_buffer[index]
          low[index] = @low_filter.process_sample(sample)
          mid[index] = @mid_lowpass.process_sample(@mid_highpass.process_sample(sample))
          high[index] = @high_filter.process_sample(sample)
        end

        cache[cache_key] = { low: low, mid: mid, high: high }
      end

      def update_filters(start_frame)
        current_low_frequency = @low_frequency.process(1, start_frame).first
        current_high_frequency = @high_frequency.process(1, start_frame).first
        current_q = @q.process(1, start_frame).first

        @low_filter.update(
          type: :lowpass,
          frequency: current_low_frequency,
          q: current_q,
          gain_db: 0.0,
          sample_rate: context.sample_rate
        )
        @mid_highpass.update(
          type: :highpass,
          frequency: current_low_frequency,
          q: current_q,
          gain_db: 0.0,
          sample_rate: context.sample_rate
        )
        @mid_lowpass.update(
          type: :lowpass,
          frequency: current_high_frequency,
          q: current_q,
          gain_db: 0.0,
          sample_rate: context.sample_rate
        )
        @high_filter.update(
          type: :highpass,
          frequency: current_high_frequency,
          q: current_q,
          gain_db: 0.0,
          sample_rate: context.sample_rate
        )
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
      end
    end
  end
end
