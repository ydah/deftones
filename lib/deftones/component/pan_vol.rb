# frozen_string_literal: true

module Deftones
  module Component
    class PanVol < Core::AudioNode
      attr_reader :input, :output, :panner, :volume

      def initialize(pan: 0.0, volume: 0.0, context: Deftones.context)
        super(context: context)
        @panner = Panner.new(pan: pan, context: context)
        @volume = Volume.new(volume: volume, context: context)
        @input = @panner
        @output = @volume
        @panner >> @volume
      end

      def render(num_frames, start_frame = 0, cache = {})
        @output.render(num_frames, start_frame, cache)
      end

      def render_block(num_frames, start_frame = 0, cache = {})
        @output.send(:render_block, num_frames, start_frame, cache)
      end
    end
  end
end
