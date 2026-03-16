# frozen_string_literal: true

module Deftones
  module Component
    class LFO < Source::Oscillator
      attr_reader :amplitude, :units
      attr_accessor :convert

      def initialize(
        frequency: 1.0,
        min: 0.0,
        max: 1.0,
        amplitude: 1.0,
        units: :number,
        convert: true,
        type: :sine,
        context: Deftones.context
      )
        super(type: type, frequency: frequency, context: context)
        @units = units.to_sym
        @convert = !!convert
        @amplitude = Core::Param.new(value: amplitude, units: :number, context: context)
        self.min = min
        self.max = max
      end

      def min
        @min
      end

      def min=(value)
        @min = coerce_range_value(value)
      end

      def max
        @max
      end

      def max=(value)
        @max = coerce_range_value(value)
      end

      def units=(value)
        @units = value.to_sym
      end

      def get_defaults
        {
          frequency: 1.0,
          min: 0.0,
          max: 1.0,
          amplitude: 1.0,
          units: :number,
          convert: true,
          type: :sine
        }
      end

      def process(_input_buffer, num_frames, start_frame, cache)
        waveform = super
        amplitudes = @amplitude.process(num_frames, start_frame)
        midpoint = (@min + @max) * 0.5
        half_range = (@max - @min) * 0.5

        Array.new(num_frames) do |index|
          depth = amplitudes[index].clamp(0.0, 1.0)
          midpoint + (waveform[index] * half_range * depth)
        end
      end

      def values(num_frames, start_frame = 0, cache = {})
        render(num_frames, start_frame, cache)
      end

      alias getDefaults get_defaults

      private

      def coerce_range_value(value)
        return value.value_of if value.respond_to?(:value_of) && !convert

        signal = Core::Signal.new(value: 0.0, units: units, context: context)
        signal.convert = convert
        signal.send(:coerce_value, value)
      end
    end
  end
end
