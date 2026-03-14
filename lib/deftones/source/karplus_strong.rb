# frozen_string_literal: true

module Deftones
  module Source
    class KarplusStrong < Core::Source
      def initialize(decay: 0.995, damping: 0.5, context: Deftones.context)
        super(context: context)
        @decay = decay.to_f
        @damping = damping.to_f
        @events = []
        @buffer = []
        @buffer_index = 0
      end

      def trigger(note, time = nil, velocity = 1.0)
        @events << {
          time: resolve_time(time),
          frequency: Deftones::Music::Note.to_frequency(note),
          velocity: velocity.to_f
        }
        @events.sort_by! { |event| event[:time] }
        self
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          time = (start_frame + index).to_f / context.sample_rate
          consume_events(time)
          next 0.0 if @buffer.empty?

          current = @buffer[@buffer_index]
          following = @buffer[(@buffer_index + 1) % @buffer.length]
          @buffer[@buffer_index] = ((current + following) * 0.5 * @decay) + ((following - current) * @damping * 0.01)
          @buffer_index = (@buffer_index + 1) % @buffer.length
          current
        end
      end

      private

      def consume_events(time)
        while @events.any? && @events.first[:time] <= time
          event = @events.shift
          delay_length = [1, (context.sample_rate / event[:frequency]).round].max
          @buffer = Array.new(delay_length) { ((rand * 2.0) - 1.0) * event[:velocity] }
          @buffer_index = 0
        end
      end
    end
  end
end
