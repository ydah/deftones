# frozen_string_literal: true

module Deftones
  module Source
    class ToneBufferSource < Player
      attr_accessor :curve, :fade_in, :fade_out, :onended
      attr_reader :detune, :start_gain

      def initialize(buffer:, playback_rate: 1.0, detune: 0.0, fade_in: 0.0, fade_out: 0.0, curve: :linear,
                     context: Deftones.context, **options)
        super(buffer: buffer, playback_rate: playback_rate, context: context, **options)
        @detune = Core::Signal.new(value: detune, units: :number, context: context)
        @fade_in = fade_in.to_f
        @fade_out = fade_out.to_f
        @curve = curve.to_sym
        @start_gain = 1.0
        @onended = nil
        @ended_notified = false
      end

      def playback_rate=(value)
        @playback_rate.value = value
      end

      def detune=(value)
        @detune.value = value
      end

      def start(time = nil, offset = nil, duration = nil, gain: 1.0)
        seek(offset) if offset
        @start_gain = gain.to_f
        @ended_notified = false
        super(time)
        self.stop(@start_time + Deftones::Music::Time.parse(duration)) if duration
        self
      end

      def cancel_stop
        @stop_time = nil
        self
      end

      def state(time = context.current_time)
        active_at?(resolve_time(time)) ? :started : :stopped
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        rates = @playback_rate.process(num_frames, start_frame)
        detunes = @detune.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          notify_ended(current_time) if @stop_time && current_time >= @stop_time
          next 0.0 unless active_at?(current_time)

          rate = rates[index] * detune_ratio(detunes[index])
          sample_position = sample_position_for(current_time, rate)
          if sample_position.negative?
            @stop_time ||= current_time
            notify_ended(current_time)
            next 0.0
          end

          @buffer.sample_at(sample_position) * envelope_gain(current_time)
        end
      end

      private

      def detune_ratio(cents)
        2.0**(cents.to_f / 1200.0)
      end

      def envelope_gain(current_time)
        gain = @start_gain
        gain *= fade_in_gain(current_time)
        gain *= fade_out_gain(current_time)
        gain
      end

      def fade_in_gain(current_time)
        return 1.0 if @fade_in <= 0.0

        elapsed = current_time - @start_time
        shaped_gain(elapsed / @fade_in)
      end

      def fade_out_gain(current_time)
        return 1.0 unless @stop_time && @fade_out > 0.0

        remaining = @stop_time - current_time
        shaped_gain(remaining / @fade_out)
      end

      def shaped_gain(progress)
        bounded = progress.clamp(0.0, 1.0)
        return bounded if @curve == :linear

        Math.sin(bounded * Math::PI * 0.5)
      end

      def notify_ended(current_time)
        return if @ended_notified

        @ended_notified = true
        @onended&.call(current_time)
      end
    end
  end
end
