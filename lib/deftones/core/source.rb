# frozen_string_literal: true

module Deftones
  module Core
    class Source < AudioNode
      class VolumeProxy
        attr_reader :source

        def initialize(source, value: 0.0)
          @source = source
          @value = value.to_f
          @automation = Signal.new(value: @value, units: :number, context: source.context)
        end

        def value
          @value
        end

        def value=(new_value)
          @value = new_value.to_f
          @automation.value = @value
          source.send(:apply_volume!)
        end

        def ramp_to(target_value, duration = nil)
          return assign_immediately(target_value) if duration.nil?

          resolved_duration = Deftones::Music::Time.parse(duration)
          return assign_immediately(target_value) if resolved_duration <= 0.0

          @value = target_value.to_f
          @automation.linear_ramp_to_value_at_time(@value, source.context.current_time + resolved_duration)
          source.send(:apply_volume!)
          self
        end

        def set_value_at_time(target_value, time)
          @value = target_value.to_f
          @automation.set_value_at_time(@value, time)
          source.send(:apply_volume!)
          self
        end

        def gains(num_frames, start_frame)
          return Array.new(num_frames, 0.0) if source.mute?

          @automation.process(num_frames, start_frame).map { |db| Deftones.db_to_gain(db) }
        end

        def current_gain
          return 0.0 if source.mute?

          Deftones.db_to_gain(@automation.get_value_at_time(source.context.current_time))
        end

        def cancel_scheduled_values(after_time = 0)
          @automation.cancel_scheduled_values(after_time)
          self
        end

        def cancel_and_hold_at_time(time)
          @automation.cancel_and_hold_at_time(time)
          @value = @automation.get_value_at_time(time)
          source.send(:apply_volume!)
          self
        end

        def linear_ramp_to(target_value, duration = nil)
          ramp_to(target_value, duration)
        end

        def exponential_ramp_to(target_value, duration = nil)
          ramp_to(target_value, duration)
        end

        alias setValueAtTime set_value_at_time
        alias cancelScheduledValues cancel_scheduled_values
        alias cancelAndHoldAtTime cancel_and_hold_at_time
        alias linearRampTo linear_ramp_to
        alias exponentialRampTo exponential_ramp_to

        private

        def assign_immediately(target_value)
          self.value = target_value
          self
        end
      end

      attr_reader :volume
      attr_accessor :onstop
      attr_reader :mute

      def initialize(context: Deftones.context)
        super(context: context)
        @input = nil
        @volume = VolumeProxy.new(self)
        @mute = false
        @start_time = Float::INFINITY
        @stop_time = nil
        @onstop = nil
        @stop_notified = false
        @synced = false
        @transport_event_ids = {}
        apply_volume!
      end

      def number_of_inputs
        0
      end

      def volume=(value)
        @volume.value = value
      end

      def mute=(value)
        @mute = !!value
        apply_volume!
      end

      def mute?
        @mute
      end

      def source_type
        class_name = self.class.name.split("::").last
        words = class_name
          .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
          .split("_")

        [words.first, *words.drop(1).map(&:capitalize)].join
      end

      def start(time = nil)
        return schedule_transport_event(:start, time) if synced?

        @start_time = resolve_time(time)
        @stop_time = nil if @stop_time && @stop_time <= @start_time
        @stop_notified = false
        self
      end

      def stop(time = nil)
        return schedule_transport_event(:stop, time) if synced?

        @stop_time = resolve_time(time)
        self
      end

      def restart(time = nil)
        stop(time)
        start(time)
      end

      def cancel_stop
        clear_transport_event(:stop)
        @stop_time = nil
        self
      end

      def state(time = context.current_time)
        active_at?(resolve_time(time)) ? :started : :stopped
      end

      def sync
        @synced = true
        self
      end

      def unsync
        @synced = false
        clear_transport_event(:start)
        clear_transport_event(:stop)
        self
      end

      def synced?
        @synced
      end

      def active_at?(time)
        return false if time < @start_time
        return true if @stop_time.nil?

        time < @stop_time
      end

      def render(num_frames, start_frame = 0, cache = {})
        super
      end

      def render_block(num_frames, start_frame = 0, cache = {})
        output_block = super
        volume_gains = @volume.gains(num_frames, start_frame)
        scaled = AudioBlock.from_channel_data(
          output_block.channel_data.map do |channel|
            channel.each_with_index.map { |sample, index| sample * volume_gains[index] }
          end
        )
        notify_stop_in_window(start_frame, num_frames)
        scaled
      end

      def dispose
        unsync
        super
      end

      alias cancelStop cancel_stop
      alias numberOfInputs number_of_inputs
      alias sourceType source_type

      private

      def uses_legacy_render_for_block?
        false
      end

      def apply_volume!
        @output_gain = @volume.current_gain
        self
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end

      def resolve_transport_time(time)
        return Deftones.transport.seconds if time.nil?

        time
      end

      def schedule_transport_event(kind, time)
        clear_transport_event(kind)
        @transport_event_ids[kind] = Deftones.transport.schedule(resolve_transport_time(time)) do |scheduled_time|
          if kind == :start
            @start_time = scheduled_time
            @stop_time = nil if @stop_time && @stop_time <= @start_time
            @stop_notified = false
          else
            @stop_time = scheduled_time
          end
        end
        self
      end

      def clear_transport_event(kind)
        event_id = @transport_event_ids.delete(kind)
        return self unless event_id

        Deftones.transport.clear(event_id)
        self
      end

      def notify_stop_in_window(start_frame, num_frames)
        return unless @stop_time
        return if @stop_notified

        start_time = start_frame.to_f / context.sample_rate
        end_time = (start_frame + num_frames).to_f / context.sample_rate
        return unless @stop_time >= start_time && @stop_time <= end_time

        @stop_notified = true
        @onstop&.call(@stop_time)
      end
    end
  end
end
