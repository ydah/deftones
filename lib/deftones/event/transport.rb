# frozen_string_literal: true

module Deftones
  module Event
    class Transport
      attr_accessor :loop, :loop_start, :loop_end, :swing
      attr_reader :ppq, :state, :time_signature

      TimingContext = Struct.new(:sample_rate) do
        def current_time
          0.0
        end
      end

      def initialize(bpm: 120.0, time_signature: [4, 4], ppq: 192, clock: nil)
        @bpm = Core::Signal.new(
          value: bpm,
          units: :number,
          context: TimingContext.new(Deftones::Context::DEFAULT_SAMPLE_RATE)
        )
        @ppq = ppq.to_i
        @state = :stopped
        self.time_signature = time_signature
        @loop = false
        @loop_start = 0.0
        @loop_end = 0.0
        @swing = 0.0
        @swing_subdivision = "8n"
        @timeline = {}
        @state_timeline = []
        @clock = clock
        @next_id = 0
        @next_state_id = 0
        @started_at = 0.0
        @position_seconds = 0.0
        @last_state_update_time = 0.0
      end

      def bpm
        @bpm.value
      end

      def bpm=(value)
        @bpm.value = value
      end

      def bpm_signal
        @bpm
      end

      def set_bpm_at_time(value, time)
        @bpm.set_value_at_time(value, resolve_time(time))
        self
      end

      def swing_subdivision
        @swing_subdivision
      end

      def swing_subdivision=(value)
        @swing_subdivision = value
      end

      def ppq=(value)
        @ppq = [value.to_i, 1].max
      end

      def start(time = nil)
        resolved_time = resolve_time(time)
        if future_time?(resolved_time)
          add_state_event(:started, resolved_time)
        else
          apply_start(resolved_time)
        end
        self
      end

      def stop(time = nil)
        resolved_time = time.nil? ? clock_time : resolve_time(time)
        if future_time?(resolved_time)
          add_state_event(:stopped, resolved_time)
        else
          apply_stop(resolved_time)
        end
        self
      end

      def pause(time = nil)
        resolved_time = time.nil? ? clock_time : resolve_time(time)
        if future_time?(resolved_time)
          add_state_event(:paused, resolved_time)
        else
          apply_pause(resolved_time)
        end
        self
      end

      def state_at(time)
        resolved_time = resolve_time(time)
        effective_state = state_before_timeline

        @state_timeline.sort_by { |event| [event[:time], event[:id]] }.each do |event|
          break if event[:time] > resolved_time

          effective_state = event[:state]
        end

        effective_state
      end

      def position
        seconds_to_position(@position_seconds)
      end

      def position=(value)
        @position_seconds = resolve_time(value)
      end

      def seconds=(value)
        @position_seconds = resolve_time(value)
      end

      def ticks
        seconds_to_ticks(@position_seconds)
      end

      def ticks=(value)
        parsed_ticks = Deftones::Music::Ticks.parse(value, bpm: bpm, time_signature: time_signature, ppq: @ppq)
        @position_seconds = ticks_to_seconds(parsed_ticks)
      end

      def seconds
        apply_due_state_events(clock_time)
        return @position_seconds unless @state == :started

        [clock_time - @started_at, 0.0].max
      end

      def bpm_at(time)
        @bpm.get_value_at_time(resolve_time(time))
      end

      def schedule(time, &block)
        raise ArgumentError, "Transport callback is required" unless block

        add_event(kind: :once, time: resolve_time(time), callback: block)
      end

      def schedule_once(time, &block)
        schedule(time, &block)
      end

      def schedule_repeat(interval, start_time: 0, duration: nil, &block)
        raise ArgumentError, "Transport callback is required" unless block

        resolved_interval = resolve_time(interval)
        raise ArgumentError, "repeat interval must be positive" unless resolved_interval.positive?

        add_event(
          kind: :repeat,
          interval: resolved_interval,
          start_time: resolve_time(start_time),
          duration: duration.nil? ? nil : resolve_time(duration),
          callback: block
        )
      end

      def clear(event_id)
        cancel(event_id: event_id)
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

      def set_loop_points(start_time, end_time)
        @loop_start = resolve_time(start_time)
        @loop_end = resolve_time(end_time)
        self
      end

      def toggle(time = nil)
        @state == :started ? pause(time) : start(time)
      end

      def immediate
        seconds
      end

      def progress
        return nil unless @loop

        loop_start_seconds = resolve_time(@loop_start)
        loop_end_seconds = resolve_time(@loop_end)
        span = loop_end_seconds - loop_start_seconds
        return nil unless span.positive?

        ((seconds - loop_start_seconds) % span) / span
      end

      def next_subdivision(subdivision)
        interval = resolve_time(subdivision)
        return nil unless interval.positive?

        current = seconds
        (((current / interval).floor) + 1) * interval
      end

      def time_signature=(signature)
        @time_signature =
          case signature
          when Array then signature.map(&:to_i)
          else [signature.to_i, 4]
          end
      end

      def timeSignature
        time_signature
      end

      def timeSignature=(signature)
        self.time_signature = signature
      end

      def swingSubdivision
        swing_subdivision
      end

      def swingSubdivision=(value)
        self.swing_subdivision = value
      end

      def prepare_render(duration)
        render_duration = resolve_time(duration)
        cursor = 0.0

        while cursor < render_duration
          window_end = [cursor + 1.0, render_duration].min
          prepare_render_window(cursor, window_end)
          cursor = window_end
        end
        self
      end

      def prepare_render_window(start_time, end_time)
        window_start = resolve_time(start_time)
        window_end = resolve_time(end_time)
        return self if window_end < window_start

        apply_due_state_events(window_end)
        due_events(window_start, window_end).each do |event|
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

      def add_state_event(state, time)
        event_id = @next_state_id
        @state_timeline << { id: event_id, state: state, time: time }
        @next_state_id += 1
        event_id
      end

      def due_events(window_start, window_end)
        return looped_due_events(window_start, window_end) if loop_active?

        events = @timeline.flat_map do |_id, event|
          event[:kind] == :repeat ? materialize_repeat_event(event, window_start, window_end) : materialize_one_shot(event, window_start, window_end)
        end
        events.sort_by { |event| event[:time] }
      end

      def looped_due_events(window_start, window_end)
        loop_start_seconds = resolve_time(@loop_start)
        loop_end_seconds = resolve_time(@loop_end)
        span = loop_end_seconds - loop_start_seconds
        return [] unless span.positive?

        first_iteration = [(window_start - loop_end_seconds) / span, 0.0].max.floor
        last_iteration = [(window_end - loop_start_seconds) / span, 0.0].max.ceil
        (first_iteration..last_iteration).flat_map do |iteration|
          offset = iteration * span
          due_events_without_loop(loop_start_seconds, loop_end_seconds).filter_map do |event|
            global_time = event[:time] + offset
            next unless time_in_window?(global_time, window_start, window_end)

            event.merge(time: global_time)
          end
        end.sort_by { |event| event[:time] }
      end

      def due_events_without_loop(window_start, window_end)
        @timeline.flat_map do |_id, event|
          if event[:kind] == :repeat
            materialize_repeat_event(event, window_start, window_end)
          else
            materialize_one_shot(event, window_start, window_end)
          end
        end
      end

      def materialize_one_shot(event, window_start, window_end)
        return [] unless time_in_window?(event[:time], window_start, window_end)

        [{ time: apply_swing(event[:time], event[:time]), callback: event[:callback] }]
      end

      def materialize_repeat_event(event, window_start, window_end)
        interval = [event[:interval], 1.0e-6].max
        limit = event[:duration] ? [event[:start_time] + event[:duration], window_end].min : window_end
        events = []
        occurrence = first_repeat_occurrence(event[:start_time], interval, window_start)
        current_time = event[:start_time] + (occurrence * interval)

        while current_time <= limit
          actual_time = apply_swing(current_time, interval, occurrence)
          events << { time: actual_time, callback: event[:callback] } if time_in_window?(actual_time, window_start, window_end)
          current_time += interval
          occurrence += 1
        end

        events
      end

      def first_repeat_occurrence(start_time, interval, window_start)
        return 0 if window_start <= start_time

        ((window_start - start_time) / interval).floor + 1
      end

      def loop_active?
        @loop && (resolve_time(@loop_end) - resolve_time(@loop_start)).positive?
      end

      def future_time?(time)
        return false unless @clock

        time > clock_time
      end

      def apply_due_state_events(up_to_time)
        due, pending = @state_timeline.partition { |event| event[:time] <= up_to_time }
        @state_timeline = pending
        due.sort_by { |event| [event[:time], event[:id]] }.each do |event|
          case event[:state]
          when :started then apply_start(event[:time])
          when :stopped then apply_stop(event[:time])
          when :paused then apply_pause(event[:time])
          end
        end
      end

      def apply_start(time)
        @state = :started
        @started_at = time - @position_seconds
        @last_state_update_time = time
      end

      def apply_stop(time)
        @position_seconds = state_position_at(time)
        @state = :stopped
        @last_state_update_time = time
      end

      def apply_pause(time)
        @position_seconds = state_position_at(time)
        @state = :paused
        @last_state_update_time = time
      end

      def state_position_at(time)
        return @position_seconds unless @state == :started

        [time - @started_at, 0.0].max
      end

      def state_before_timeline
        @state
      end

      def time_in_window?(time, window_start, window_end)
        return false if time > window_end
        return time >= window_start if window_start.zero?

        time > window_start
      end

      def apply_swing(time, interval, occurrence = 0)
        return time if @swing.zero?
        return time if resolve_time(@swing_subdivision) != interval
        return time if occurrence.even?

        time + (interval * 0.5 * @swing)
      end

      def resolve_time(value)
        return @position_seconds if value.nil?

        Deftones::Music::Time.parse(value, bpm: bpm, time_signature: time_signature, ppq: @ppq)
      end

      def clock_time
        return @clock.current_time if @clock&.respond_to?(:current_time)

        Deftones.now
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

      def seconds_to_ticks(seconds)
        (beats_between(0.0, seconds.to_f) * @ppq).round
      end

      def ticks_to_seconds(ticks)
        target_beats = ticks.to_f / @ppq
        return target_beats * (60.0 / bpm) unless tempo_automated?

        upper = [target_beats * (60.0 / [bpm, 1.0].max), 1.0e-6].max
        upper *= 2.0 while beats_between(0.0, upper) < target_beats
        lower = 0.0
        40.times do
          midpoint = (lower + upper) * 0.5
          if beats_between(0.0, midpoint) < target_beats
            lower = midpoint
          else
            upper = midpoint
          end
        end
        upper
      end

      def beats_between(start_time, end_time)
        from = start_time.to_f
        to = end_time.to_f
        return 0.0 if to <= from

        integration_points(from, to).each_cons(2).sum do |left, right|
          midpoint = (left + right) * 0.5
          ((right - left) * bpm_at(midpoint)) / 60.0
        end
      end

      def tempo_automated?
        bpm_events.any?
      end

      def integration_points(start_time, end_time)
        points = [start_time, end_time]
        bpm_events.each do |event|
          points << event[:time] if event[:time] && event[:time].between?(start_time, end_time)
          points << event[:start_time] if event[:start_time] && event[:start_time].between?(start_time, end_time)
          points << event[:end_time] if event[:end_time] && event[:end_time].between?(start_time, end_time)
        end
        points.uniq.sort
      end

      def bpm_events
        @bpm.instance_variable_get(:@events) || []
      end

      public :seconds_to_position, :seconds_to_ticks, :ticks_to_seconds
      public :beats_between
      alias scheduleOnce schedule_once
      alias scheduleRepeat schedule_repeat
      alias prepareRenderWindow prepare_render_window
      alias setLoopPoints set_loop_points
      alias nextSubdivision next_subdivision
      alias bpmAt bpm_at
      alias bpmSignal bpm_signal
      alias setBpmAtTime set_bpm_at_time
      alias stateAt state_at
    end
  end
end
