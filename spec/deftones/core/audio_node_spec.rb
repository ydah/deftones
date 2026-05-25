# frozen_string_literal: true

RSpec.describe Deftones::Core::AudioNode do
  it "exposes shared Tone-style node helpers" do
    context = Deftones::OfflineContext.new(duration: 0.1, sample_rate: 100, buffer_size: 10, channels: 2)
    node = described_class.new(context: context)

    expect(node.toDestination).to eq(node)
    expect(node.toMaster).to eq(node)
    expect(node.now).to eq(0.0)
    expect(node.immediate).to eq(0.0)
    expect(node.toSeconds("4n")).to eq(0.5)
    expect(node.toTicks("4n")).to eq(192.0)
    expect(node.toFrequency("A4")).to eq(440.0)
    expect(node.toMidi("A4")).to eq(69)
    expect(node.sampleTime).to eq(0.01)
    expect(node.blockTime).to eq(0.1)
    expect(node.channelCount).to eq(2)
    expect(node.channelCountMode).to eq("max")
    expect(node.channelInterpretation).to eq("speakers")
    expect(node.numberOfInputs).to eq(1)
    expect(node.numberOfOutputs).to eq(1)
    expect(node.name).to eq("AudioNode")
    expect(node.toString).to eq("AudioNode")
  end

  it "supports generic get/set helpers" do
    context = Deftones::OfflineContext.new(duration: 0.1)
    gain = Deftones::Gain.new(context: context, gain: 1.0)

    gain.set(gain: 0.5)

    expect(gain.gain.value).to eq(0.5)
    expect(gain.get(:gain)).to eq({ gain: gain.gain })
    expect(gain.get(:missing)).to eq({})
    expect { gain.get(:missing, strict: true) }.to raise_error(ArgumentError, /missing/)
    expect { gain.set(missing: 1.0, strict: true) }.to raise_error(ArgumentError, /missing/)
  end

  it "exposes graph introspection and validates unsupported connection indexes" do
    context = Deftones::OfflineContext.new(duration: 0.1)
    source = Deftones::Gain.new(context: context)
    destination = Deftones::Gain.new(context: context)

    source.connect(destination)

    expect(source.outputs).to eq([destination])
    expect(destination.inputs).to eq([source])
    expect(source.connected?(destination)).to eq(true)

    source.disconnect(destination)

    expect(source.connected?(destination)).to eq(false)
    expect { source.connect(destination, output_index: 1) }.to raise_error(ArgumentError, /output_index/)
    expect { source.connect(destination, input_index: 1) }.to raise_error(ArgumentError, /input_index/)
  end

  it "prevents graph cycles and disposed-node connections" do
    context = Deftones::OfflineContext.new(duration: 0.1)
    first = Deftones::Gain.new(context: context)
    second = Deftones::Gain.new(context: context)

    first.connect(second)

    expect { second.connect(first) }.to raise_error(ArgumentError, /cycle/)

    first.disconnect(second)
    second.dispose

    expect { first.connect(second) }.to raise_error(Deftones::Error, /disposed destination/)
  end
end
