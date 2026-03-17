# frozen_string_literal: true

module Deftones
  module Component
    class Channel < Core::AudioNode
      @buses = Hash.new { |hash, key| hash[key] = {} }

      class << self
        attr_reader :buses
      end

      attr_reader :input, :output, :pan_vol, :solo

      def initialize(pan: 0.0, volume: 0.0, solo: false, muted: false, mute: nil, context: Deftones.context)
        super(context: context)
        muted = mute unless mute.nil?
        @pan_vol = PanVol.new(pan: pan, volume: volume, context: context)
        @solo = Solo.new(solo: solo, muted: muted, context: context)
        @input = @pan_vol.input
        @output = @solo
        @sends = []
        @pan_vol.output >> @solo
      end

      def render(num_frames, start_frame = 0, cache = {})
        @output.render(num_frames, start_frame, cache)
      end

      def render_block(num_frames, start_frame = 0, cache = {})
        @output.send(:render_block, num_frames, start_frame, cache)
      end

      def pan
        @pan_vol.panner.pan
      end

      def pan=(value)
        @pan_vol.panner.pan = value
      end

      def volume
        @pan_vol.volume.volume
      end

      def volume=(value)
        @pan_vol.volume.volume = value
      end

      def mute
        @solo.mute
      end

      def mute=(value)
        @solo.mute = value
      end

      def mute?
        @solo.mute?
      end

      def muted
        mute
      end

      def muted=(value)
        self.mute = value
      end

      def solo?
        @solo.solo?
      end

      def solo=(value)
        @solo.solo = value
      end

      def send(name, volume = 0.0)
        send_gain = Core::Gain.new(gain: Deftones.db_to_gain(volume), context: context)
        @output >> send_gain >> bus(name)
        @sends << send_gain
        send_gain
      end

      def receive(name)
        bus(name) >> @input
        self
      end

      def dispose
        @sends.each(&:dispose)
        @sends.clear
        @pan_vol.dispose
        @solo.dispose
        super
      end

      alias panVol pan_vol
      alias solo solo?
      alias muted? muted

      private

      def bus(name)
        registry = self.class.buses[context.object_id]
        registry[name.to_sym] ||= Core::Gain.new(gain: 1.0, context: context)
      end
    end
  end
end
