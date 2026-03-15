# frozen_string_literal: true

module Deftones
  module Source
    class ToneOscillatorNode < Oscillator
      attr_accessor :onended
      attr_reader :detune

      def initialize(detune: 0.0, context: Deftones.context, **options)
        super(context: context, **options)
        @detune = Core::Signal.new(value: detune, units: :number, context: context)
        @onended = nil
        @ended_notified = false
      end

      def detune=(value)
        @detune.value = value
      end

      def state(time = context.current_time)
        active_at?(resolve_time(time)) ? :started : :stopped
      end

      def cancel_stop
        @stop_time = nil
        self
      end

      def start(time = nil)
        @ended_notified = false
        super
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        generator = GENERATORS.fetch(send(:normalize_type, @type))
        frequencies = @frequency.process(num_frames, start_frame)
        detunes = @detune.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          notify_ended(current_time) if @stop_time && current_time >= @stop_time
          next 0.0 unless active_at?(current_time)

          sample = generator.call(@phase)
          frequency = frequencies[index] * detune_ratio(detunes[index])
          @phase = (@phase + (frequency / context.sample_rate)) % 1.0
          sample
        end
      end

      private

      def detune_ratio(cents)
        2.0**(cents.to_f / 1200.0)
      end

      def notify_ended(current_time)
        return if @ended_notified

        @ended_notified = true
        @onended&.call(current_time)
      end
    end
  end
end
