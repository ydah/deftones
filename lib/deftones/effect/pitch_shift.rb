# frozen_string_literal: true

module Deftones
  module Effects
    class PitchShift < Core::Effect
      attr_reader :delay_time, :feedback
      attr_accessor :pitch
      attr_reader :window_size

      def initialize(
        pitch: nil,
        semitones: 0.0,
        window: 0.1,
        window_size: nil,
        delay_time: nil,
        feedback: 0.0,
        context: Deftones.context,
        **options
      )
        super(context: context, **options)
        @pitch = pitch.nil? ? semitones.to_f : pitch.to_f
        @window_size = resolve_window_size(window_size || window)
        @delay_time = Core::Signal.new(
          value: delay_time.nil? ? default_delay_time : delay_time,
          units: :time,
          context: context
        )
        @feedback = Core::Signal.new(value: feedback, units: :number, context: context)
        @phase = 0.0
        @delay_line = nil
        @max_delay_samples = 0
        ensure_delay_line_capacity!(@delay_time.value.to_f, pitch_ratio)
      end

      def semitones
        @pitch
      end

      def semitones=(value)
        self.pitch = value
      end

      def pitch=(value)
        @pitch = value.to_f
        ensure_delay_line_capacity!(@delay_time.value.to_f, pitch_ratio)
      end

      def window_size=(value)
        @window_size = resolve_window_size(value)
        ensure_delay_line_capacity!(@delay_time.value.to_f, pitch_ratio)
      end

      alias delayTime delay_time
      alias windowSize window_size

      def windowSize=(value)
        self.window_size = value
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        delays = @delay_time.process(num_frames, start_frame)
        feedbacks = @feedback.process(num_frames, start_frame)
        ratio = pitch_ratio
        ensure_delay_line_capacity!(delays.max.to_f, ratio)

        Array.new(num_frames) do |index|
          delay_seconds = delays[index].to_f
          sample = shifted_sample(delay_seconds, ratio)
          @delay_line.write(input_buffer[index] + (sample * feedbacks[index].to_f.clamp(-0.999, 0.999)))
          advance_phase
          sample
        end
      end

      def shifted_sample(delay_seconds, ratio)
        primary_phase = @phase
        secondary_phase = (@phase + 0.5) % 1.0
        primary = shifted_head_sample(primary_phase, delay_seconds, ratio)
        secondary = shifted_head_sample(secondary_phase, delay_seconds, ratio)
        (primary * head_gain(primary_phase)) + (secondary * head_gain(secondary_phase))
      end

      def shifted_head_sample(phase, delay_seconds, ratio)
        delay_samples = head_delay_samples(phase, delay_seconds, ratio)
        @delay_line.read(delay_samples)
      end

      def head_delay_samples(phase, delay_seconds, ratio)
        base_delay = [delay_seconds, context.sample_time].max * context.sample_rate
        sweep = sweep_span_samples(ratio)
        offset = if ratio >= 1.0
                   (1.0 - phase) * sweep
                 else
                   phase * sweep
                 end

        [base_delay + offset, 1.0].max
      end

      def head_gain(phase)
        Math.sin(Math::PI * phase)**2
      end

      def advance_phase
        @phase = (@phase + phase_step) % 1.0
      end

      def phase_step
        1.0 / (@window_size * context.sample_rate)
      end

      def pitch_ratio
        2.0**(@pitch.to_f / 12.0)
      end

      def sweep_span_samples(ratio)
        @window_size * context.sample_rate * (1.0 - ratio).abs
      end

      def required_delay_samples(delay_seconds, ratio)
        (
          ([delay_seconds, context.sample_time].max * context.sample_rate) +
          sweep_span_samples(ratio) +
          (@window_size * context.sample_rate)
        ).ceil + 2
      end

      def ensure_delay_line_capacity!(delay_seconds, ratio)
        required = [required_delay_samples(delay_seconds, ratio), 2].max
        return if required <= @max_delay_samples

        @max_delay_samples = required
        @delay_line = DSP::DelayLine.new(@max_delay_samples)
      end

      def resolve_window_size(value)
        [value.to_f, context.sample_time * 2.0].max
      end

      def default_delay_time
        @window_size * 0.5
      end
    end
  end
end
