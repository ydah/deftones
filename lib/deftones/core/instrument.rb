# frozen_string_literal: true

module Deftones
  module Core
    class Instrument < AudioNode
      attr_reader :output

      def initialize(context: Deftones.context)
        super(context: context)
        @output = Gain.new(context: context, gain: 1.0)
      end

      def input
        @output
      end

      def render(num_frames, start_frame = 0, cache = {})
        @output.render(num_frames, start_frame, cache)
      end
    end
  end
end
