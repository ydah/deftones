# frozen_string_literal: true

module Deftones
  module Event
    class Transport
      attr_accessor :loop, :loop_start, :loop_end, :swing
      attr_reader :state, :time_signature

      def initialize(bpm: 120.0, time_signature: [4, 4])
        @bpm = Core::Signal.new(value: bpm, units: :number, context: Deftones.context)
        @state = :stopped
        self.time_signature = time_signature
        @loop = false
        @loop_start = 0.0
        @loop_end = 0.0
        @swing = 0.0
        @swing_subdivision = "8n"
        @timeline = {}
        @next_id = 0
        @started_at = 0.0
        @position_seconds = 0.0
      end

      def bpm
        @bpm.value
      end

      def bpm=(value)
        @bpm.value = value
      end

      def swing_subdivision
        @swing_subdivision
      end

      def swing_subdivision=(value)
        @swing_subdivision = value
      end

      def start(time = nil)
        @state = :started
        @started_at = resolve_time(time)
        self
      end

      def stop(time = nil)
        @state = :stopped
        @position_seconds = time.nil? ? seconds : resolve_time(time)
        self
      end

      def pause(time = nil)
        @state = :paused
        @position_seconds = time.nil? ? seconds : resolve_time(time)
        self
      end

      def position
        seconds_to_position(@position_seconds)
      end

      def position=(value)
        @position_seconds = resolve_time(value)
      end

      def seconds
        return @position_seconds unless @state == :started

        [Deftones.now - @started_at, 0.0].max
      end

      def schedule(time, &block)
        add_event(kind: :once, time: resolve_time(time), callback: block)
      end

      def schedule_repeat(interval, start_time: 0, duration: nil, &block)
        add_event(
          kind: :repeat,
          interval: resolve_time(interval),
          start_time: resolve_time(start_time),
          duration: duration.nil? ? nil : resolve_time(duration),
          callback: block
        )
      end

      def cancel(after_time = 0, event_id: nil)
        return @timeline.delete(event_id) if event_id

        threshold = resolve_time(after_time)
        @timeline.delete_if do |_id, event|
          event_time = event[:kind] == :repeat ? event[:start_time] : event[:time]
          event_time >= threshold
        end
        self
      end

      def time_signature=(signature)
        @time_signature =
          case signature
          when Array then signature.map(&:to_i)
          else [signature.to_i, 4]
          end
      end

      def prepare_render(duration)
        render_duration = resolve_time(duration)
        due_events(render_duration).each do |event|
          event[:callback].call(event[:time])
        end
        self
      end

      private

      def add_event(payload)
        event_id = @next_id
        @timeline[event_id] = payload
        @next_id += 1
        event_id
      end

      def due_events(duration)
        events = @timeline.flat_map do |_id, event|
          event[:kind] == :repeat ? materialize_repeat_event(event, duration) : materialize_one_shot(event, duration)
        end
        events.sort_by { |event| event[:time] }
      end

      def materialize_one_shot(event, duration)
        return [] if event[:time] > duration

        [{ time: apply_swing(event[:time], event[:time]), callback: event[:callback] }]
      end

      def materialize_repeat_event(event, duration)
        interval = [event[:interval], 1.0e-6].max
        limit = event[:duration] ? [event[:start_time] + event[:duration], duration].min : duration
        events = []
        occurrence = 0
        current_time = event[:start_time]

        while current_time <= limit
          actual_time = apply_swing(current_time, interval, occurrence)
          events << { time: actual_time, callback: event[:callback] }
          current_time += interval
          occurrence += 1
        end

        events
      end

      def apply_swing(time, interval, occurrence = 0)
        return time if @swing.zero?
        return time if resolve_time(@swing_subdivision) != interval
        return time if occurrence.even?

        time + (interval * 0.5 * @swing)
      end

      def resolve_time(value)
        return @position_seconds if value.nil?

        Deftones::Music::Time.parse(value, bpm: bpm, time_signature: time_signature)
      end

      def seconds_to_position(seconds)
        beats_per_measure = Array(@time_signature).first || 4
        beat_duration = 60.0 / bpm
        total_beats = seconds.to_f / beat_duration
        bars = (total_beats / beats_per_measure).floor
        beats = (total_beats % beats_per_measure).floor
        sixteenths = (((total_beats - total_beats.floor) / 0.25).round) % 4
        "#{bars}:#{beats}:#{sixteenths}"
      end
    end
  end
end
