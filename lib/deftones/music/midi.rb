# frozen_string_literal: true

begin
  require "unimidi"
rescue LoadError
  nil
end

module Deftones
  module Music
    class Midi
      attr_reader :value, :transport

      def initialize(value, transport: Deftones.transport)
        @value = value
        @transport = transport
        @disposed = false
      end

      def to_i
        self.class.parse(value)
      end

      def to_frequency
        Note.to_frequency(to_note)
      end

      def to_seconds
        1.0 / to_frequency
      end

      def to_ticks
        transport.seconds_to_ticks(to_seconds)
      end

      def to_bars_beats_sixteenths
        transport.seconds_to_position(to_seconds)
      end

      def to_milliseconds
        to_seconds * 1000.0
      end

      def to_samples(sample_rate = Deftones.context.sample_rate)
        UnitHelpers.samples_for_seconds(to_seconds, sample_rate)
      end

      def to_notation
        UnitHelpers.closest_notation(to_seconds, transport: transport)
      end

      def transpose(interval)
        self.class.new(to_i + interval.to_i, transport: transport)
      end

      def harmonize(intervals)
        Array(intervals).map { |interval| transpose(interval) }
      end

      def quantize(subdiv, percent = 1.0)
        quantized_seconds = UnitHelpers.quantize_seconds(to_seconds, subdiv, transport: transport, percent: percent)
        Note.to_midi(Note.from_frequency(1.0 / [quantized_seconds, 1.0e-6].max))
      end

      def from_type(type)
        @value =
          if type.respond_to?(:to_midi)
            type.to_midi
          elsif type.respond_to?(:value_of)
            type.value_of
          else
            type
          end
        self
      end

      def dispose
        @disposed = true
        self
      end

      def disposed?
        @disposed
      end

      def to_s
        value.to_s
      end

      alias toString to_s

      def to_note
        Note.from_midi(to_i)
      end

      def value_of
        to_i
      end

      class << self
        def parse(value)
          return value.to_i if value.is_a?(Numeric)

          Note.to_midi(value)
        end

        def available?
          !!defined?(UniMIDI)
        end

        def input_devices
          return [] unless available?

          UniMIDI::Input.all
        end

        def output_devices
          return [] unless available?

          UniMIDI::Output.all
        end

        def find_input(name = nil)
          find_device(input_devices, name)
        end

        def find_output(name = nil)
          find_device(output_devices, name)
        end

        def open_input(name = nil, *args, &block)
          open_device(find_input(name), *args, &block)
        end

        def open_output(name = nil, *args, &block)
          open_device(find_output(name), *args, &block)
        end

        def receive(name = nil, *args)
          open_input(name) do |input|
            input.gets(*args)
          end
        end

        def send_message(message, device: nil)
          open_output(device) do |output|
            output.puts(message)
          end
        end

        def note_on(note, velocity: 100, channel: 1, device: nil)
          send_message([status_byte(0x90, channel), normalize_note(note), normalize_data_byte(velocity)], device: device)
        end

        def note_off(note, velocity: 0, channel: 1, device: nil)
          send_message([status_byte(0x80, channel), normalize_note(note), normalize_data_byte(velocity)], device: device)
        end

        def control_change(controller, value, channel: 1, device: nil)
          send_message(
            [status_byte(0xB0, channel), normalize_data_byte(controller), normalize_data_byte(value)],
            device: device
          )
        end

        private

        def find_device(devices, name)
          return devices.first if name.nil?

          devices.find { |device| device.name == name.to_s }
        end

        def open_device(device, *args, &block)
          raise ArgumentError, "MIDI support is unavailable" unless available?
          raise ArgumentError, "No matching MIDI device found" unless device

          return device.open(*args) unless block

          device.open(*args)
          begin
            block.call(device)
          ensure
            device.close if device.respond_to?(:close)
          end
        end

        def normalize_note(note)
          normalize_data_byte(parse(note))
        end

        def normalize_data_byte(value)
          value.to_i.clamp(0, 127)
        end

        def status_byte(base, channel)
          base + normalize_channel(channel)
        end

        def normalize_channel(channel)
          [[channel.to_i - 1, 0].max, 15].min
        end
      end
    end
  end
end
