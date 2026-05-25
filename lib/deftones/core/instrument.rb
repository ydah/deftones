# frozen_string_literal: true

module Deftones
  module Core
    class Instrument < AudioNode
      class VolumeProxy
        attr_reader :instrument
        attr_reader :value

        def initialize(instrument, value: 0.0)
          @instrument = instrument
          @value = value.to_f
        end

        def value=(new_value)
          @value = new_value.to_f
          instrument.apply_volume!
        end

        def ramp_to(target_value, duration = nil)
          return assign_immediately(target_value) if duration.nil?

          resolved_duration = Deftones::Music::Time.parse(duration)
          return assign_immediately(target_value) if resolved_duration <= 0.0

          @value = target_value.to_f
          instrument.output.gain.linear_ramp_to_value_at_time(
            instrument.mute? ? 0.0 : Deftones.db_to_gain(@value),
            instrument.context.current_time + resolved_duration
          )
          self
        end

        def set_value_at_time(target_value, time)
          @value = target_value.to_f
          instrument.output.gain.set_value_at_time(instrument.mute? ? 0.0 : Deftones.db_to_gain(@value), time)
          self
        end

        def linear_ramp_to(target_value, duration = nil)
          ramp_to(target_value, duration)
        end

        def exponential_ramp_to(target_value, duration = nil)
          ramp_to(target_value, duration)
        end

        alias setValueAtTime set_value_at_time
        alias linearRampTo linear_ramp_to
        alias exponentialRampTo exponential_ramp_to

        private

        def assign_immediately(target_value)
          self.value = target_value
          self
        end
      end

      attr_reader :output, :volume
      attr_reader :mute

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

      def render_block(num_frames, start_frame = 0, cache = {})
        @output.send(:render_block, num_frames, start_frame, cache)
      end

      def mute=(value)
        @mute = !!value
        apply_volume!
      end

      def mute?
        @mute
      end

      def set(strict: false, **params)
        unknown = params.keys.reject { |key| respond_to?(:"#{key}=") }
        raise ArgumentError, "Unknown parameter(s): #{unknown.join(', ')}" if strict && unknown.any?

        params.each do |key, value|
          writer = :"#{key}="
          public_send(writer, value) if respond_to?(writer)
        end
        self
      end

      def get(*keys, strict: false)
        requested = keys.flatten
        unknown = []
        values = requested.each_with_object({}) do |key, collected|
          reader = key.to_sym
          if respond_to?(reader)
            collected[reader] = public_send(reader)
          else
            unknown << reader
          end
        end
        raise ArgumentError, "Unknown parameter(s): #{unknown.join(', ')}" if strict && unknown.any?

        values
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
