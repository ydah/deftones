# frozen_string_literal: true

module Deftones
  module Component
    class Panner < Core::AudioNode
      PAN_LAWS = %i[equal_power linear].freeze

      attr_reader :pan, :pan_law

      def initialize(pan: 0.0, pan_law: :equal_power, context: Deftones.context)
        super(context: context)
        @pan = Core::Signal.new(value: pan, units: :number, context: context)
        @pan_law = normalize_pan_law(pan_law)
      end

      def pan=(value)
        @pan.value = value
      end

      def pan_law=(value)
        @pan_law = normalize_pan_law(value)
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        pans = @pan.process(num_frames, start_frame)
        return process_mono_input(input_block, num_frames, pans) if input_block.channels == 1

        stereo_input = input_block.fit_channels(2)
        left = Array.new(num_frames)
        right = Array.new(num_frames)

        num_frames.times do |index|
          left[index] = stereo_input.channel_data[0][index] * stereo_left_gain(pans[index])
          right[index] = stereo_input.channel_data[1][index] * stereo_right_gain(pans[index])
        end

        Core::AudioBlock.from_channel_data([left, right])
      end

      private

      def process_mono_input(input_block, num_frames, pans)
        mono_input = input_block.mono

        Core::AudioBlock.from_channel_data([
          Array.new(num_frames) { |index| mono_input[index] * left_gain(pans[index]) },
          Array.new(num_frames) { |index| mono_input[index] * right_gain(pans[index]) }
        ])
      end

      def stereo_left_gain(pan)
        normalized = pan.to_f.clamp(-1.0, 1.0)
        return [1.0 - normalized, 0.0].max if @pan_law == :linear && normalized.positive?
        return 1.0 if normalized <= 0.0

        Math.cos(normalized * Math::PI * 0.5)
      end

      def stereo_right_gain(pan)
        normalized = pan.to_f.clamp(-1.0, 1.0)
        return [1.0 + normalized, 0.0].max if @pan_law == :linear && normalized.negative?
        return 1.0 if normalized >= 0.0

        Math.cos(normalized.abs * Math::PI * 0.5)
      end

      def left_gain(pan)
        return (1.0 - pan.to_f.clamp(-1.0, 1.0)) * 0.5 if @pan_law == :linear

        Math.cos(angle_for(pan))
      end

      def right_gain(pan)
        return (1.0 + pan.to_f.clamp(-1.0, 1.0)) * 0.5 if @pan_law == :linear

        Math.sin(angle_for(pan))
      end

      def angle_for(pan)
        ((pan.to_f.clamp(-1.0, 1.0) + 1.0) * Math::PI) * 0.25
      end

      def normalize_pan_law(value)
        normalized = value.to_sym
        return normalized if PAN_LAWS.include?(normalized)

        raise ArgumentError, "Unsupported pan law: #{value}"
      end

      alias panLaw pan_law
      alias panLaw= pan_law=
    end
  end
end
