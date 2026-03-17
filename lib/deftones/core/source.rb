# frozen_string_literal: true

module Deftones
  module Core
    class Source < AudioNode
      class VolumeProxy
        attr_reader :source
        attr_accessor :value

        def initialize(source, value: 0.0)
          @source = source
          @value = value.to_f
        end

        def value=(new_value)
          @value = new_value.to_f
          source.send(:apply_volume!)
        end

        def ramp_to(target_value, _duration = nil)
          self.value = target_value
          self
        end

        alias linear_ramp_to ramp_to
        alias exponential_ramp_to ramp_to
      end

      attr_reader :volume
      attr_accessor :onstop
      attr_accessor :mute

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
        output_buffer = super.map { |sample| sample * @output_gain }
        notify_stop_in_window(start_frame, num_frames)
        output_buffer
      end

      def dispose
        unsync
        super
      end

      alias cancelStop cancel_stop
      alias numberOfInputs number_of_inputs
      alias sourceType source_type

      private

      def apply_volume!
        @output_gain = mute ? 0.0 : Deftones.db_to_gain(@volume.value)
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
