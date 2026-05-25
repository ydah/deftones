# frozen_string_literal: true

module Deftones
  module Component
    class Filter < Core::AudioNode
      TYPES = DSP::Biquad::TYPES

      attr_reader :detune, :frequency, :gain, :q, :type

      def initialize(type: :lowpass, frequency: 350.0, q: 1.0, gain: 0.0, detune: 0.0, context: Deftones.context)
        super(context: context)
        @biquads = []
        self.type = type
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @q = Core::Signal.new(value: q, units: :number, context: context)
        @gain = Core::Signal.new(value: gain, units: :number, context: context)
        @detune = Core::Signal.new(value: detune, units: :number, context: context)
      end

      def detune=(value)
        @detune.value = value
      end

      def type=(value)
        normalized = normalize_type(value)
        return @type = normalized if @type == normalized

        @type = normalized
        reset!
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        ensure_biquads(input_block.channels)
        frequencies = @frequency.process(num_frames, start_frame)
        detunes = @detune.process(num_frames, start_frame)
        q_values = @q.process(num_frames, start_frame)
        gain_values = @gain.process(num_frames, start_frame)

        Core::AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            biquad = @biquads[channel_index]
            Array.new(num_frames) do |index|
              update_filter(biquad, frequencies[index], detunes[index], q_values[index], gain_values[index])
              biquad.process_sample(channel[index])
            end
          end
        )
      end

      def reset!
        @biquads.each(&:reset!)
        self
      end

      private

      def update_filter(biquad, frequency, detune, q, gain)
        biquad.update(
          type: normalize_type(@type),
          frequency: frequency * (2.0**(detune / 1200.0)),
          q: q,
          gain_db: gain * 24.0,
          sample_rate: context.sample_rate
        )
      end

      def ensure_biquads(channels)
        required = [channels.to_i, 1].max
        missing = required - @biquads.length
        missing.times { @biquads << DSP::Biquad.new } if missing.positive?
      end

      def normalize_type(type)
        normalized = type.to_sym
        return normalized if TYPES.include?(normalized)

        raise ArgumentError, "Unsupported filter type: #{type}"
      end
    end
  end
end
