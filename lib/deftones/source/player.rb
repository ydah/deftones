# frozen_string_literal: true

module Deftones
  module Source
    class Player < Core::Source
      attr_reader :buffer, :playback_rate
      attr_accessor :loop, :loop_start, :loop_end, :reverse, :fade_in, :fade_out, :curve

      def initialize(buffer:, playback_rate: 1.0, loop: false, loop_start: 0.0, loop_end: nil,
                     reverse: false, fade_in: 0.0, fade_out: 0.0, curve: :linear,
                     autostart: false, onstop: nil, context: Deftones.context)
        super(context: context)
        @buffer = buffer.is_a?(IO::Buffer) ? buffer : IO::Buffer.load(buffer)
        @playback_rate = Core::Signal.new(value: playback_rate, units: :number, context: context)
        @loop = loop
        @loop_start = loop_start.to_f
        @loop_end = loop_end
        @reverse = reverse
        @fade_in = fade_in.to_f
        @fade_out = fade_out.to_f
        @curve = curve.to_sym
        @onstop = onstop
        @seek_position = 0.0
        @start_time = Float::INFINITY
        @stop_notified = false
        start(0.0) if autostart
      end

      def playback_rate=(value)
        @playback_rate.value = value
      end

      def onstop
        @onstop
      end

      def onstop=(callback)
        @onstop = callback
      end

      def loaded?
        !@buffer.nil?
      end

      def loaded
        loaded?
      end

      def start(time = nil, offset = nil, duration = nil)
        seek(offset) if offset
        @stop_notified = false
        super(time)
        self.stop(@start_time + Deftones::Music::Time.parse(duration)) if duration
        self
      end

      def restart(time = nil, offset = nil, duration = nil)
        stop(time)
        start(time, offset, duration)
      end

      def state(time = context.current_time)
        active_at?(resolve_time(time)) ? :started : :stopped
      end

      def seek(time)
        @seek_position = Deftones::Music::Time.parse(time) * @buffer.sample_rate
        self
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        rates = @playback_rate.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          notify_stop(current_time) if @stop_time && current_time >= @stop_time
          next 0.0 unless active_at?(current_time)

          sample_position = sample_position_for(current_time, rates[index])
          if sample_position.negative?
            @stop_time ||= current_time
            notify_stop(current_time)
            next 0.0
          end

          @buffer.sample_at(sample_position) * envelope_gain(current_time)
        end
      end

      alias playbackRate playback_rate
      alias loopStart loop_start
      alias loopEnd loop_end
      alias fadeIn fade_in
      alias fadeOut fade_out

      def playbackRate=(value)
        self.playback_rate = value
      end

      def loopStart=(value)
        self.loop_start = value
      end

      def loopEnd=(value)
        self.loop_end = value
      end

      def fadeIn=(value)
        self.fade_in = value
      end

      def fadeOut=(value)
        self.fade_out = value
      end

      private

      def envelope_gain(current_time)
        fade_in_gain(current_time) * fade_out_gain(current_time)
      end

      def fade_in_gain(current_time)
        return 1.0 if @fade_in <= 0.0

        shaped_gain((current_time - @start_time) / @fade_in)
      end

      def fade_out_gain(current_time)
        return 1.0 unless @stop_time && @fade_out > 0.0

        shaped_gain((@stop_time - current_time) / @fade_out)
      end

      def shaped_gain(progress)
        bounded = progress.clamp(0.0, 1.0)
        return bounded if @curve == :linear

        Math.sin(bounded * Math::PI * 0.5)
      end

      def notify_stop(current_time)
        return if @stop_notified

        @stop_notified = true
        @onstop&.call(current_time)
      end

      def sample_position_for(current_time, rate)
        elapsed_frames = (current_time - @start_time) * @buffer.sample_rate * rate
        base_position = @seek_position + elapsed_frames
        return reverse_position(base_position) if @reverse
        return looped_position(base_position) if @loop

        base_position < @buffer.frames ? base_position : -1
      end

      def reverse_position(base_position)
        max_position = loop_end_frame || (@buffer.frames - 1)
        min_position = @loop_start * @buffer.sample_rate
        position = max_position - base_position
        return looped_reverse_position(position, min_position, max_position) if @loop

        position
      end

      def looped_position(position)
        min_position = @loop_start * @buffer.sample_rate
        max_position = loop_end_frame || @buffer.frames
        span = [max_position - min_position, 1.0].max
        min_position + ((position - min_position) % span)
      end

      def looped_reverse_position(position, min_position, max_position)
        span = [max_position - min_position, 1.0].max
        min_position + ((position - min_position) % span)
      end

      def loop_end_frame
        return unless @loop_end

        Deftones::Music::Time.parse(@loop_end) * @buffer.sample_rate
      end
    end
  end
end
