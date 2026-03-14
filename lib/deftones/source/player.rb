# frozen_string_literal: true

module Deftones
  module Source
    class Player < Core::Source
      attr_reader :buffer, :playback_rate
      attr_accessor :loop, :loop_start, :loop_end, :reverse

      def initialize(buffer:, playback_rate: 1.0, loop: false, loop_start: 0.0, loop_end: nil,
                     reverse: false, context: Deftones.context)
        super(context: context)
        @buffer = buffer.is_a?(IO::Buffer) ? buffer : IO::Buffer.load(buffer)
        @playback_rate = Core::Signal.new(value: playback_rate, units: :number, context: context)
        @loop = loop
        @loop_start = loop_start.to_f
        @loop_end = loop_end
        @reverse = reverse
        @seek_position = 0.0
        @start_time = Float::INFINITY
      end

      def seek(time)
        @seek_position = Deftones::Music::Time.parse(time) * @buffer.sample_rate
        self
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        rates = @playback_rate.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          sample_position = sample_position_for(current_time, rates[index])
          next 0.0 if sample_position.negative?

          @buffer.sample_at(sample_position)
        end
      end

      private

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
