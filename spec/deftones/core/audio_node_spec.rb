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
  end
end
