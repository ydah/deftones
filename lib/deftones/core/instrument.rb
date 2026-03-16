# frozen_string_literal: true

module Deftones
  module Core
    class Instrument < AudioNode
      class VolumeProxy
        attr_reader :instrument
        attr_accessor :value

        def initialize(instrument, value: 0.0)
          @instrument = instrument
          @value = value.to_f
        end

        def value=(new_value)
          @value = new_value.to_f
          instrument.apply_volume!
        end

        def ramp_to(target_value, _duration = nil)
          self.value = target_value
          self
        end

        alias linear_ramp_to ramp_to
        alias exponential_ramp_to ramp_to
      end

      attr_reader :output, :volume
      attr_accessor :mute

      def initialize(context: Deftones.context)
        super(context: context)
        @output = Gain.new(context: context, gain: 1.0)
        @volume = VolumeProxy.new(self)
        @mute = false
        apply_volume!
      end

      def input
        @output
      end

      def render(num_frames, start_frame = 0, cache = {})
        @output.render(num_frames, start_frame, cache)
      end

      def mute=(value)
        @mute = !!value
        apply_volume!
      end

      def mute?
        @mute
      end

      def set(**params)
        params.each do |key, value|
          writer = :"#{key}="
          public_send(writer, value) if respond_to?(writer)
        end
        self
      end

      def get(*keys)
        requested = keys.flatten
        requested.each_with_object({}) do |key, values|
          reader = key.to_sym
          values[reader] = public_send(reader) if respond_to?(reader)
        end
      end

      def release_all(time = nil)
        trigger_release(time) if respond_to?(:trigger_release)
        self
      end

      def dispose
        @output.dispose
        super
      end

      def triggerAttack(*arguments)
        trigger_attack(*arguments)
      end

      def triggerRelease(*arguments)
        trigger_release(*arguments)
      end

      def triggerAttackRelease(*arguments)
        trigger_attack_release(*arguments)
      end

      def releaseAll(time = nil)
        release_all(time)
      end

      def apply_volume!
        @output.gain.value = mute ? 0.0 : Deftones.db_to_gain(@volume.value)
        self
      end
    end
  end
end
