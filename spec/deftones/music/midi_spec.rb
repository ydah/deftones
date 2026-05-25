# frozen_string_literal: true

RSpec.describe Deftones::Midi do
  class FakeMidiOutput
    attr_reader :messages, :name

    def initialize(name)
      @name = name
      @messages = []
    end

    def open(*)
      return self unless block_given?

      yield self
      self
    end

    def close
      true
    end

    def puts(message)
      @messages << Array(message)
    end
  end

  class FakeMidiInput
    attr_reader :name

    def initialize(name, events)
      @name = name
      @events = events
    end

    def open(*)
      return self unless block_given?

      yield self
      self
    end

    def close
      true
    end

    def gets(*)
      @events
    end
  end

  it "opens devices, sends messages, and receives events through UniMIDI-style wrappers" do
    output = FakeMidiOutput.new("loopback-out")
    input = FakeMidiInput.new("loopback-in", [{ data: [0x90, 60, 100], timestamp: 10 }])

    allow(described_class).to receive(:available?).and_return(true)
    allow(described_class).to receive(:output_devices).and_return([output])
    allow(described_class).to receive(:input_devices).and_return([input])

    described_class.note_on("C4", velocity: 99, channel: 2, device: "loopback-out")
    described_class.control_change(74, 64, device: "loopback-out")
    events = described_class.receive("loopback-in")

    expect(output.messages).to eq([[0x91, 60, 99], [0xB0, 74, 64]])
    expect(events).to eq([{ data: [0x90, 60, 100], timestamp: 10 }])
  end

  it "raises when a requested device does not exist" do
    allow(described_class).to receive(:available?).and_return(true)
    allow(described_class).to receive(:output_devices).and_return([])

    expect { described_class.open_output("missing") }.to raise_error(ArgumentError, /No matching MIDI device/)
  end

  it "distinguishes missing MIDI support from missing devices" do
    allow(described_class).to receive(:available?).and_return(false)

    expect { described_class.open_output }.to raise_error(Deftones::MissingMidiBackendError, /unimidi/)
  end

  it "validates MIDI channel numbers" do
    output = FakeMidiOutput.new("loopback-out")

    allow(described_class).to receive(:available?).and_return(true)
    allow(described_class).to receive(:output_devices).and_return([output])

    expect { described_class.note_on("C4", channel: 0) }.to raise_error(ArgumentError, /between 1 and 16/)
    expect { described_class.note_off("C4", channel: 17) }.to raise_error(ArgumentError, /between 1 and 16/)
  end

  it "bridges MIDI clock messages to transport state" do
    transport = Deftones::Event::Transport.new(ppq: 192)

    expect(described_class.sync_transport([0xFA], transport: transport)).to eq(:start)
    expect(transport.state).to eq(:started)
    expect(described_class.sync_transport([0xF8], transport: transport)).to eq(:clock)
    expect(transport.ticks).to eq(8)
    expect(described_class.sync_transport({ data: [0xFC] }, transport: transport)).to eq(:stop)
    expect(transport.state).to eq(:stopped)
  end

  it "bridges note messages to synth-style targets" do
    target = Class.new do
      attr_reader :events

      def initialize
        @events = []
      end

      def trigger_attack(note, time, velocity)
        @events << [:attack, note, time, velocity]
      end

      def trigger_release(note, time)
        @events << [:release, note, time]
      end
    end.new

    expect(described_class.trigger_from_message([0x90, 60, 64], target: target, time: 0.25)).to eq(:note_on)
    expect(described_class.trigger_from_message([0x90, 60, 0], target: target, time: 0.5)).to eq(:note_off)
    expect(described_class.trigger_from_message([0xB0, 74, 64], target: target)).to eq(:ignored)
    expect(target.events).to eq([[:attack, "C4", 0.25, 64.0 / 127.0], [:release, "C4", 0.5]])
  end

  it "wraps midi note values with compatibility conversions" do
    midi = described_class.new("A4")

    expect(midi.to_i).to eq(69)
    expect(midi.to_note).to eq("A4")
    expect(midi.to_frequency).to eq(440.0)
    expect(midi.to_seconds).to be_within(0.000001).of(1.0 / 440.0)
    expect(midi.to_ticks).to eq(1)
    expect(midi.to_notation).to eq("128n")
    expect(midi.transpose(12).to_note).to eq("A5")
    expect(midi.harmonize([0, 7]).map(&:to_note)).to eq(%w[A4 E5])
    expect(midi.quantize(0.001)).to eq(71)
    expect(midi.toString).to eq("A4")
    expect(midi.dispose.disposed?).to eq(true)
    expect(midi.value_of).to eq(69)
  end
end
