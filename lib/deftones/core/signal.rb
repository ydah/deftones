# frozen_string_literal: true

module Deftones
  module Core
    class Signal
      EXPONENTIAL_UNITS = %i[frequency decibels].freeze

      attr_reader :context, :units

      def initialize(value: 0.0, units: :number, context: Deftones.context)
        @context = context
        @units = units
        @base_value = convert(value)
        @events = []
      end

      def value
        @base_value
      end

      def value=(new_value)
        @base_value = convert(new_value)
        @events.clear
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
          convert(target_value),
          Deftones::Music::Time.parse(duration),
          start_time: context.current_time
        )
      end

      def exponential_ramp_to(target_value, duration)
        schedule_automation(
          :exponential,
          convert(target_value),
          Deftones::Music::Time.parse(duration),
          start_time: context.current_time
        )
      end

      def set_value_at_time(target_value, time)
        @events << { type: :set, time: resolve_time(time), value: convert(target_value) }
        sort_events!
        self
      end

      def cancel_scheduled_values(after_time = 0)
        threshold = resolve_time(after_time)
        @events.reject! do |event|
          event.fetch(:time, event[:start_time]) >= threshold
        end
        self
      end

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
          end
        end

        current_value
      end

      private

      def schedule_automation(type, target_value, duration, start_time:)
        duration_in_seconds = duration.to_f
        @events << {
          type: type,
          start_time: start_time,
          end_time: start_time + duration_in_seconds,
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

      def convert(value)
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
