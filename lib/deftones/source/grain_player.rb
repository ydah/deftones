# frozen_string_literal: true

module Deftones
  module Source
    class GrainPlayer < Player
      attr_accessor :grain_size, :overlap, :jitter

      def initialize(grain_size: 0.05, overlap: 0.5, jitter: 0.002, **options)
        super(**options)
        @grain_size = grain_size.to_f
        @overlap = overlap.to_f
        @jitter = jitter.to_f
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        rates = @playback_rate.process(num_frames, start_frame)
        grain_offset = 0.0

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          primary = sample_position_for(current_time, rates[index])
          secondary = primary + ((@grain_size * context.sample_rate) * @overlap) + (rand * @jitter * context.sample_rate)
          grain_offset += @grain_size * context.sample_rate * 0.01
          (@buffer.sample_at(primary + grain_offset) + @buffer.sample_at(secondary)) * 0.5
        end
      end
    end
  end
end
