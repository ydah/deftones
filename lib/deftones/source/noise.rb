# frozen_string_literal: true

module Deftones
  module Source
    class Noise < Core::Source
      TYPES = %i[white pink brown].freeze

      attr_accessor :type
      attr_reader :playback_rate

      def initialize(type: :white, playback_rate: 1.0, context: Deftones.context)
        super(context: context)
        @type = normalize_type(type)
        @playback_rate = playback_rate.to_f
        @pink_state = 0.0
        @brown_state = 0.0
        @held_sample = 0.0
        @held_samples_remaining = 0
      end

      def playback_rate=(value)
        @playback_rate = value.to_f
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          next_sample
        end
      end

      private

      def next_sample
        return next_noise_sample if @playback_rate >= 1.0

        if @held_samples_remaining <= 0
          hold_length = [(1.0 / [@playback_rate, 1.0e-6].max).round, 1].max
          @held_sample = next_noise_sample
          @held_samples_remaining = hold_length
        end

        @held_samples_remaining -= 1
        @held_sample
      end

      def next_noise_sample
        white = (rand * 2.0) - 1.0

        case normalize_type(@type)
        when :white
          white
        when :pink
          @pink_state = (0.98 * @pink_state) + (0.02 * white)
          @pink_state * 3.5
        when :brown
          @brown_state = Deftones::DSP::Helpers.clamp(@brown_state + (white * 0.02), -1.0, 1.0)
        end
      end

      def normalize_type(type)
        normalized = type.to_sym
        return normalized if TYPES.include?(normalized)

        raise ArgumentError, "Unsupported noise type: #{type}"
      end

      alias playbackRate playback_rate
      alias playbackRate= playback_rate=
    end
  end
end
