# frozen_string_literal: true

module Deftones
  module Effects
    class AutoWah < Core::Effect
      FollowerSettings = Struct.new(:attack, :release, keyword_init: true)

      attr_accessor :base_frequency, :octaves, :q, :sensitivity, :gain
      attr_reader :follower

      def initialize(
        base_frequency: 200.0,
        octaves: 4.0,
        sensitivity: 0.0,
        q: 2.0,
        gain: 2.0,
        follower: {},
        context: Deftones.context,
        **options
      )
        super(context: context, wet: 1.0, **options)
        @base_frequency = base_frequency.to_f
        @octaves = octaves.to_f
        @sensitivity = sensitivity.to_f
        @q = q.to_f
        @gain = gain.to_f
        @envelopes = []
        @filters = []
        @follower = resolve_follower(follower)
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache, channel_index: 0)
        ensure_tracking_state(channel_index)
        envelope = @envelopes[channel_index]
        filter = @filters[channel_index]

        Array.new(num_frames) do |index|
          sample = input_buffer[index]
          envelope = track_envelope(sample.abs, envelope)
          openness = openness_for(envelope)
          cutoff = @base_frequency * (2.0**(@octaves * openness))
          filter.update(type: :bandpass, frequency: cutoff, q: @q, gain_db: 0.0, sample_rate: context.sample_rate)
          filter.process_sample(sample) * output_gain(openness)
        end
      ensure
        @envelopes[channel_index] = envelope
      end

      def track_envelope(level, current_envelope)
        smoothing =
          if level >= current_envelope
            follower_coefficient(@follower.attack)
          else
            follower_coefficient(@follower.release)
          end
        (smoothing * current_envelope) + ((1.0 - smoothing) * level)
      end

      def follower_coefficient(duration)
        return 0.0 if duration.to_f <= 0.0

        Math.exp(-1.0 / (duration.to_f * context.sample_rate))
      end

      def openness_for(level)
        level_db = level.positive? ? Deftones.gain_to_db(level) : -100.0
        threshold = [@sensitivity.to_f, -99.0].max
        return level.clamp(0.0, 1.0) if threshold >= 0.0

        ((level_db - threshold) / -threshold).clamp(0.0, 1.0)
      end

      def output_gain(openness)
        1.0 + ((@gain - 1.0) * openness)
      end

      def resolve_follower(follower)
        return follower if follower.is_a?(FollowerSettings)

        settings = follower.respond_to?(:to_h) ? follower.to_h : {}
        FollowerSettings.new(
          attack: settings.fetch(:attack, 0.3).to_f,
          release: settings.fetch(:release, 0.5).to_f
        )
      end

      def ensure_tracking_state(channel_index)
        required = [channel_index.to_i, 0].max
        @envelopes.fill(0.0, @envelopes.length..required)
        while @filters.length <= required
          @filters << DSP::Biquad.new
        end
      end
    end
  end
end
