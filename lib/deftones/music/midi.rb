# frozen_string_literal: true

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
          load_backend!
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

        def open_output_session(name = nil, *args)
          session = OutputSession.new(open_output(name, *args))
          return session unless block_given?

          begin
            yield session
          ensure
            session.close
          end
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

        def sync_transport(message, transport: Deftones.transport)
          status = message_data(message).first.to_i
          case status
          when 0xF8
            transport.ticks = transport.ticks + (transport.ppq / 24.0)
            :clock
          when 0xFA
            transport.ticks = 0
            transport.start(0)
            :start
          when 0xFB
            transport.start(transport.seconds)
            :continue
          when 0xFC
            transport.stop
            :stop
          else
            :ignored
          end
        end

        def trigger_from_message(message, target:, time: nil, velocity_scale: 127.0)
          data = message_data(message)
          status = data.first.to_i
          command = status & 0xF0
          return :ignored unless [0x80, 0x90].include?(command)

          note = Note.from_midi(normalize_data_byte(data[1]))
          velocity = normalize_data_byte(data[2]) / [velocity_scale.to_f, 1.0].max
          if command == 0x90 && velocity.positive?
            target.trigger_attack(note, time, velocity)
            :note_on
          else
            trigger_release(target, note, time)
            :note_off
          end
        end

        private

        def load_backend!
          return true if defined?(UniMIDI)

          require "unimidi"
          true
        rescue LoadError
          false
        end

        def message_data(message)
          data = message.is_a?(Hash) ? message.fetch(:data, message) : message
          Array(data).map(&:to_i)
        end

        def find_device(devices, name)
          return devices.first if name.nil?

          matched_by_id = devices.find { |device| matches_device_id?(device, name) }
          return matched_by_id if matched_by_id
          return devices[name] if name.is_a?(Integer) && name >= 0 && name < devices.length

          matcher = name.is_a?(Regexp) ? name : Regexp.new(Regexp.escape(name.to_s), Regexp::IGNORECASE)
          devices.find { |device| device.respond_to?(:name) && device.name.to_s.match?(matcher) }
        end

        def matches_device_id?(device, selector)
          return false if selector.is_a?(Regexp)

          candidates = []
          candidates << device.id if device.respond_to?(:id)
          candidates << device.device_id if device.respond_to?(:device_id)
          candidates << device.index if device.respond_to?(:index)
          candidates << device.device_index if device.respond_to?(:device_index)
          candidates.compact.any? { |candidate| candidate.to_s == selector.to_s }
        end

        def open_device(device, *args, &block)
          raise Deftones::MissingMidiBackendError, "MIDI support is unavailable. Install the unimidi gem to enable MIDI I/O." unless available?
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

        def trigger_release(target, note, time)
          target.trigger_release(note, time)
        rescue ArgumentError
          target.trigger_release(time)
        end

        def normalize_channel(channel)
          integer = channel.to_i
          raise ArgumentError, "MIDI channel must be between 1 and 16" unless (1..16).cover?(integer)

          integer - 1
        end
      end

      class OutputSession
        def initialize(output)
          @output = output
          @closed = false
        end

        def send(message)
          raise IOError, "MIDI output session is closed" if @closed

          @output.puts(message)
          self
        end

        def note_on(note, velocity: 100, channel: 1)
          send([self.class.parent_status_byte(0x90, channel), Midi.send(:normalize_note, note),
                Midi.send(:normalize_data_byte, velocity)])
        end

        def note_off(note, velocity: 0, channel: 1)
          send([self.class.parent_status_byte(0x80, channel), Midi.send(:normalize_note, note),
                Midi.send(:normalize_data_byte, velocity)])
        end

        def close
          return self if @closed

          @output.close if @output.respond_to?(:close)
          @closed = true
          self
        end

        def closed?
          @closed
        end

        def self.parent_status_byte(base, channel)
          Midi.send(:status_byte, base, channel)
        end
      end
    end
  end
end
