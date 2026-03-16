# frozen_string_literal: true

module Deftones
  module Core
    class Signal
      EXPONENTIAL_UNITS = %i[frequency decibels].freeze

      include SignalOperatorMethods

      attr_reader :context, :units, :input, :output, :default_value
      attr_accessor :min_value, :max_value, :convert_values

      def initialize(value: 0.0, units: :number, context: Deftones.context)
        @context = context
        @units = units
        @input = self
        @output = self
        @convert_values = true
        @base_value = coerce_value(value)
        @default_value = @base_value
        @min_value = -Float::INFINITY
        @max_value = Float::INFINITY
        @events = []
        @disposed = false
      end

      def value
        @base_value
      end

      def value=(new_value)
        @base_value = coerce_value(new_value)
        @events.clear
      end

      def apply(value)
        self.value = value.respond_to?(:value_of) ? value.value_of : value
        self
      end

      def ramp_to(target_value, duration)
        if EXPONENTIAL_UNITS.include?(@units)
          exponential_ramp_to(target_value, duration)
        else
          linear_ramp_to(target_value, duration)
        end
      end

      def linear_ramp_to(target_value, duration)
        schedule_automation(
          :linear,
          coerce_value(target_value),
          Deftones::Music::Time.parse(duration),
          start_time: context.current_time
        )
      end

      def linear_ramp_to_value_at_time(target_value, end_time)
        schedule_automation(
          :linear,
          coerce_value(target_value),
          resolve_time(end_time) - context.current_time,
          start_time: context.current_time,
          end_time: resolve_time(end_time)
        )
      end

      def exponential_ramp_to(target_value, duration)
        schedule_automation(
          :exponential,
          coerce_value(target_value),
          Deftones::Music::Time.parse(duration),
          start_time: context.current_time
        )
      end

      def exponential_ramp_to_value_at_time(target_value, end_time)
        schedule_automation(
          :exponential,
          coerce_value(target_value),
          resolve_time(end_time) - context.current_time,
          start_time: context.current_time,
          end_time: resolve_time(end_time)
        )
      end

      def set_value_at_time(target_value, time)
        @events << { type: :set, time: resolve_time(time), value: coerce_value(target_value) }
        sort_events!
        self
      end

      def set_value_curve_at_time(values, start_time, duration)
        curve = Array(values).map { |value| coerce_value(value) }
        resolved_start = resolve_time(start_time)
        resolved_duration = Deftones::Music::Time.parse(duration)
        @events << {
          type: :curve,
          time: resolved_start,
          start_time: resolved_start,
          end_time: resolved_start + resolved_duration,
          duration: resolved_duration,
          values: curve
        }
        sort_events!
        self
      end

      def set_target_at_time(target_value, start_time, time_constant)
        resolved_start = resolve_time(start_time)
        @events << {
          type: :target,
          time: resolved_start,
          start_time: resolved_start,
          time_constant: [Deftones::Music::Time.parse(time_constant), 1.0e-6].max,
          from: value_at(resolved_start),
          to: coerce_value(target_value)
        }
        sort_events!
        self
      end

      def target_ramp_to(target_value, duration, start_time = context.current_time)
        resolved_start = resolve_time(start_time)
        resolved_duration = Deftones::Music::Time.parse(duration)
        set_target_at_time(target_value, resolved_start, [resolved_duration / 5.0, 1.0e-6].max)
        set_value_at_time(target_value, resolved_start + resolved_duration)
      end

      def cancel_scheduled_values(after_time = 0)
        threshold = resolve_time(after_time)
        @events.reject! do |event|
          event.fetch(:time, event[:start_time]) >= threshold
        end
        self
      end

      def cancel_and_hold_at_time(time)
        held_time = resolve_time(time)
        held_value = value_at(held_time)
        cancel_scheduled_values(held_time)
        set_value_at_time(held_value, held_time)
      end

      def set_ramp_point(time = context.current_time)
        cancel_and_hold_at_time(time)
      end

      def get_value_at_time(time)
        value_at(resolve_time(time))
      end

      def dispose
        @events.clear
        @disposed = true
        self
      end

      def disposed?
        @disposed
      end

      alias linearRampToValueAtTime linear_ramp_to_value_at_time
      alias exponentialRampToValueAtTime exponential_ramp_to_value_at_time
      alias setValueAtTime set_value_at_time
      alias setValueCurveAtTime set_value_curve_at_time
      alias setTargetAtTime set_target_at_time
      alias targetRampTo target_ramp_to
      alias cancelScheduledValues cancel_scheduled_values
      alias cancelAndHoldAtTime cancel_and_hold_at_time
      alias setRampPoint set_ramp_point
      alias getValueAtTime get_value_at_time

      def connect(destination, output_index: 0, input_index: 0)
        _ = output_index
        _ = input_index
        return self if destination.nil?

        if destination.respond_to?(:value=)
          destination.value = value
        elsif destination.respond_to?(:apply)
          destination.apply(self)
        end
        self
      end

      def disconnect(_destination = nil)
        self
      end

      def set(**params)
        params.each do |key, entry|
          writer = :"#{key}="
          public_send(writer, entry) if respond_to?(writer)
        end
        self
      end

      def get(*keys)
        keys.flatten.each_with_object({}) do |key, values|
          reader = key.to_sym
          values[reader] = public_send(reader) if respond_to?(reader)
        end
      end

      def get_defaults
        {
          value: default_value,
          units: units
        }
      end

      def now
        context.current_time
      end

      def immediate
        now
      end

      def to_seconds(time = value)
        Deftones::Music::Time.parse(time)
      end

      def to_ticks(time = value)
        Deftones.transport.seconds_to_ticks(to_seconds(time))
      end

      def to_frequency(entry = value)
        Deftones::Music::Frequency.parse(entry)
      end

      def overridden?
        false
      end

      def name
        self.class.name.split("::").last
      end

      def to_s
        name
      end

      def exponential_approach_value_at_time(target_value, start_time, ramp_time)
        target_ramp_to(target_value, ramp_time, start_time)
      end

      alias minValue min_value
      alias minValue= min_value=
      alias maxValue max_value
      alias maxValue= max_value=
      alias defaultValue default_value
      alias getDefaults get_defaults
      alias toSeconds to_seconds
      alias toTicks to_ticks
      alias toFrequency to_frequency
      alias toString to_s
      alias exponentialApproachValueAtTime exponential_approach_value_at_time

      def process(num_frames, start_frame = 0)
        Array.new(num_frames) do |offset|
          value_at(sample_time(start_frame + offset))
        end
      end

      def value_at(time)
        current_value = @base_value

        @events.each do |event|
          case event[:type]
          when :set
            break if time < event[:time]

            current_value = event[:value]
          when :linear, :exponential
            break if time < event[:start_time]

            if time >= event[:end_time]
              current_value = event[:to]
              next
            end

            return interpolate(event, (time - event[:start_time]) / event[:duration])
          when :curve
            break if time < event[:start_time]

            if time >= event[:end_time]
              current_value = event[:values].last || current_value
              next
            end

            return curve_value(event, time)
          when :target
            break if time < event[:start_time]

            current_value = target_value(event, time)
          end
        end

        current_value
      end

      private

      def schedule_automation(type, target_value, duration, start_time:, end_time: nil)
        duration_in_seconds = [duration.to_f, 0.0].max
        @events << {
          type: type,
          start_time: start_time,
          end_time: end_time || (start_time + duration_in_seconds),
          time: start_time,
          duration: duration_in_seconds,
          from: value_at(start_time),
          to: target_value
        }
        sort_events!
        self
      end

      def sort_events!
        @events.sort_by! { |event| event.fetch(:time, event[:start_time]) }
      end

      def interpolate(event, progress)
        return event[:to] if event[:duration].zero?

        bounded_progress = progress.clamp(0.0, 1.0)
        case event[:type]
        when :linear
          event[:from] + ((event[:to] - event[:from]) * bounded_progress)
        when :exponential
          from = safe_exponential_value(event[:from])
          to = safe_exponential_value(event[:to])
          from * ((to / from)**bounded_progress)
        else
          event[:to]
        end
      end

      def curve_value(event, time)
        values = event[:values]
        return values.first if values.length <= 1

        progress = ((time - event[:start_time]) / event[:duration]).clamp(0.0, 1.0)
        scaled_index = progress * (values.length - 1)
        lower_index = scaled_index.floor
        upper_index = [lower_index + 1, values.length - 1].min
        fraction = scaled_index - lower_index
        lower = values[lower_index]
        upper = values[upper_index]
        lower + ((upper - lower) * fraction)
      end

      def target_value(event, time)
        elapsed = [time - event[:start_time], 0.0].max
        event[:to] + ((event[:from] - event[:to]) * Math.exp(-(elapsed / event[:time_constant])))
      end

      def safe_exponential_value(value)
        magnitude = value.abs < 1.0e-6 ? 1.0e-6 : value.abs
        value.negative? ? -magnitude : magnitude
      end

      def sample_time(frame_index)
        frame_index.to_f / context.sample_rate
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end

      public

      def convert
        @convert_values
      end

      def convert=(value)
        @convert_values = !!value
      end

      private

      def coerce_value(value)
        return convert_without_units(value) unless @convert_values

        case @units
        when :frequency
          convert_frequency(value)
        when :time
          Deftones::Music::Time.parse(value)
        when :decibels
          db_to_gain(value.to_f)
        else
          convert_generic(value)
        end
      end

      def convert_without_units(value)
        return value.value_of if value.respond_to?(:value_of)
        return value.to_f if value.is_a?(Numeric) || value.respond_to?(:to_f)

        value
      end

      def convert_frequency(value)
        return value.to_f if value.is_a?(Numeric)

        string_value = value.to_s
        return Regexp.last_match(1).to_f if string_value.match(/\A(\d+(?:\.\d+)?)hz\z/i)

        Deftones::Music::Note.to_frequency(string_value)
      end

      def convert_generic(value)
        string_value = value.to_s
        if string_value.match?(/\A[A-Ga-g][#b]?-?\d+\z/)
          Deftones::Music::Note.to_frequency(string_value)
        else
          value.to_f
        end
      end

      def db_to_gain(value)
        10.0**(value / 20.0)
      end
    end
  end
end
