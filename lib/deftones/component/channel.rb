# frozen_string_literal: true

module Deftones
  module Component
    class Channel < Core::AudioNode
      attr_reader :input, :output, :pan_vol, :solo

      def initialize(pan: 0.0, volume: 0.0, solo: false, muted: false, context: Deftones.context)
        super(context: context)
        @pan_vol = PanVol.new(pan: pan, volume: volume, context: context)
        @solo = Solo.new(solo: solo, muted: muted, context: context)
        @input = @pan_vol.input
        @output = @solo
        @pan_vol.output >> @solo
      end

      def render(num_frames, start_frame = 0, cache = {})
        @output.render(num_frames, start_frame, cache)
      end
    end
  end
end
