# frozen_string_literal: true

require "tmpdir"

RSpec.describe Deftones do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  it "exposes the top-level MVP aliases" do
    expect(described_class::Synth).to eq(Deftones::Instrument::Synth)
    expect(described_class::PolySynth).to eq(Deftones::Instrument::PolySynth)
    expect(described_class::Oscillator).to eq(Deftones::Source::Oscillator)
    expect(described_class::Filter).to eq(Deftones::Component::Filter)
    expect(described_class::Buffers).to eq(Deftones::IO::Buffers)
    expect(described_class::Note).to eq(Deftones::Music::Note)
    expect(described_class::Time).to eq(Deftones::Music::Time)
  end

  it "renders audio through the convenience API" do
    buffer = described_class.render(duration: 0.1) do |context|
      synth = described_class::Synth.new(context: context).to_output
      synth.play("A4", duration: 0.02)
    end

    expect(buffer).to be_a(Deftones::IO::Buffer)
    expect(buffer.frames).to eq(4_410)
    expect(buffer.peak).to be > 0.1
    expect(buffer.rms).to be > 0.01
  end

  it "writes a wav file through render_to_file" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "example.wav")

      described_class.render_to_file(path, duration: 0.1) do |context|
        synth = described_class::Synth.new(context: context, type: :sawtooth).to_output
        synth.play("C4", duration: 0.03)
      end

      expect(File).to exist(path)
      expect(File.binread(path, 12)).to eq("RIFF" + File.binread(path, 8)[4, 4] + "WAVE")
    end
  end
end
