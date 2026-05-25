# frozen_string_literal: true

module Deftones
  module Source
    class Noise < Core::Source
      TYPES = %i[white pink brown].freeze

      attr_accessor :type, :fade_in, :fade_out
      attr_reader :playback_rate

      def initialize(type: :white, playback_rate: 1.0, fade_in: 0.0, fade_out: 0.0, seed: nil, rng: nil,
                     context: Deftones.context)
        super(context: context)
        @type = normalize_type(type)
        @playback_rate = playback_rate.to_f
        @fade_in = fade_in.to_f
        @fade_out = fade_out.to_f
        @rng = rng || (seed.nil? ? Random : Random.new(seed))
        @pink_state = Array.new(7, 0.0)
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
        white = (@rng.rand * 2.0) - 1.0

        case normalize_type(@type)
        when :white
          white
        when :pink
          pink_noise_sample(white)
        when :brown
          brown_noise_sample(white)
        end
      end

      def pink_noise_sample(white)
        @pink_state[0] = (0.99886 * @pink_state[0]) + (white * 0.0555179)
        @pink_state[1] = (0.99332 * @pink_state[1]) + (white * 0.0750759)
        @pink_state[2] = (0.96900 * @pink_state[2]) + (white * 0.1538520)
        @pink_state[3] = (0.86650 * @pink_state[3]) + (white * 0.3104856)
        @pink_state[4] = (0.55000 * @pink_state[4]) + (white * 0.5329522)
        @pink_state[5] = (-0.7616 * @pink_state[5]) - (white * 0.0168980)

        sample = @pink_state[0..6].sum + (white * 0.5362)
        @pink_state[6] = white * 0.115926
        Deftones::DSP::Helpers.clamp(sample * 0.11, -1.0, 1.0)
      end

      def brown_noise_sample(white)
        @brown_state = (@brown_state + (0.02 * white)) / 1.02
        Deftones::DSP::Helpers.clamp(@brown_state * 3.5, -1.0, 1.0)
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
