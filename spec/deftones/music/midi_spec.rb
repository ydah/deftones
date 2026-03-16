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

  it "wraps midi note values with compatibility conversions" do
    midi = described_class.new("A4")

    expect(midi.to_i).to eq(69)
    expect(midi.to_note).to eq("A4")
    expect(midi.to_frequency).to eq(440.0)
    expect(midi.value_of).to eq(69)
  end
end
