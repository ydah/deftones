# frozen_string_literal: true

module Deftones
  module Component
    class Filter < Core::AudioNode
      TYPES = DSP::Biquad::TYPES

      attr_reader :detune, :frequency, :q, :gain
      attr_accessor :type

      def initialize(type: :lowpass, frequency: 350.0, q: 1.0, gain: 0.0, detune: 0.0, context: Deftones.context)
        super(context: context)
        @type = normalize_type(type)
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @q = Core::Signal.new(value: q, units: :number, context: context)
        @gain = Core::Signal.new(value: gain, units: :number, context: context)
        @detune = Core::Signal.new(value: detune, units: :number, context: context)
        @biquads = []
      end

      def detune=(value)
        @detune.value = value
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        update_filters(input_block.channels, start_frame)
        Core::AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            biquad = @biquads[channel_index]
            Array.new(num_frames) { |index| biquad.process_sample(channel[index]) }
          end
        )
      end

      def reset!
        @biquads.each(&:reset!)
        self
      end

      private

      def update_filters(channels, start_frame)
        ensure_biquads(channels)
        frequency = @frequency.process(1, start_frame).first
        detune = @detune.process(1, start_frame).first
        @biquads.each do |biquad|
          biquad.update(
            type: normalize_type(@type),
            frequency: frequency * (2.0**(detune / 1200.0)),
            q: @q.process(1, start_frame).first,
            gain_db: @gain.process(1, start_frame).first * 24.0,
            sample_rate: context.sample_rate
          )
        end
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
