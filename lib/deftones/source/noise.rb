# frozen_string_literal: true

module Deftones
  module Source
    class Noise < Core::Source
      TYPES = %i[white pink brown].freeze

      attr_accessor :type, :fade_in, :fade_out
      attr_reader :playback_rate

      def initialize(type: :white, playback_rate: 1.0, fade_in: 0.0, fade_out: 0.0, context: Deftones.context)
        super(context: context)
        @type = normalize_type(type)
        @playback_rate = playback_rate.to_f
        @fade_in = fade_in.to_f
        @fade_out = fade_out.to_f
        @pink_state = 0.0
        @brown_state = 0.0
        @held_sample = next_noise_sample
        @playback_phase = 0.0
      end

      def playback_rate=(value)
        @playback_rate = value.to_f
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          next_sample * envelope_gain(current_time)
        end
      end

      alias fadeIn fade_in
      alias fadeIn= fade_in=
      alias fadeOut fade_out
      alias fadeOut= fade_out=

      private

      def next_sample
        sample = @held_sample
        advance_playback
        sample
      end

      def advance_playback
        @playback_phase += [@playback_rate, 1.0e-6].max
        steps = @playback_phase.floor
        return if steps <= 0

        steps.times { @held_sample = next_noise_sample }
        @playback_phase -= steps
      end

      def envelope_gain(current_time)
        fade_in_gain(current_time) * fade_out_gain(current_time)
      end

      def fade_in_gain(current_time)
        return 1.0 if @fade_in <= 0.0

        ((current_time - @start_time) / @fade_in).clamp(0.0, 1.0)
      end

      def fade_out_gain(current_time)
        return 1.0 unless @stop_time && @fade_out > 0.0

        ((@stop_time - current_time) / @fade_out).clamp(0.0, 1.0)
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
