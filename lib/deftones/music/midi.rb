# frozen_string_literal: true

begin
  require "unimidi"
rescue LoadError
  nil
end

module Deftones
  module Music
    class Midi
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def to_i
        self.class.parse(value)
      end

      def to_frequency
        Note.to_frequency(to_note)
      end

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
