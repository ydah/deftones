# frozen_string_literal: true

module Deftones
  module Source
    class Noise < Core::Source
      TYPES = %i[white pink brown].freeze

      attr_accessor :type

      def initialize(type: :white, context: Deftones.context)
        super(context: context)
        @type = normalize_type(type)
        @pink_state = 0.0
        @brown_state = 0.0
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          next_sample
        end
      end

      private

      def next_sample
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
    end
  end
end
