# frozen_string_literal: true

module Deftones
  module Core
    class SyncedSignal < Signal
      attr_reader :transport

      def initialize(transport: Deftones.transport, **options)
        @transport = transport
        @synced = true
        super(**options)
      end

      def value
        value_at(current_base_time)
      end

      def sync
        @synced = true
        self
      end

      def unsync
        @synced = false
        self
      end

      def synced?
        @synced
      end

      def linear_ramp_to(target_value, duration)
        schedule_automation(
          :linear,
          convert(target_value),
          Deftones::Music::Time.parse(duration),
          start_time: current_base_time
        )
      end

      def exponential_ramp_to(target_value, duration)
        schedule_automation(
          :exponential,
          convert(target_value),
          Deftones::Music::Time.parse(duration),
          start_time: current_base_time
        )
      end

      def process(num_frames, start_frame = 0)
        timeline_offset = synced? ? transport.seconds : 0.0

        Array.new(num_frames) do |offset|
          value_at(timeline_offset + sample_time(start_frame + offset))
        end
      end

      private

      def current_base_time
        synced? ? transport.seconds : context.current_time
      end

      def resolve_time(time)
        return current_base_time if time.nil?
        return super unless synced?

        Deftones::Music::Time.parse(
          time,
          bpm: transport.bpm,
          time_signature: transport.time_signature,
          ppq: transport.ppq
        )
      end
    end
  end
end
