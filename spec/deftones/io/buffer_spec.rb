# frozen_string_literal: true

require "tmpdir"

RSpec.describe Deftones::IO::Buffer do
  it "supports slicing, normalization, and sample interpolation" do
    buffer = described_class.new([0.0, 0.5, -0.5, 1.0], channels: 1, sample_rate: 4)

    expect(buffer.slice(1, 2).samples).to eq([0.5, -0.5])
    expect(buffer.normalize(0.5).peak).to be_within(0.001).of(0.5)
    expect(buffer.sample_at(1.5)).to be_within(0.001).of(0.0)
  end

  it "saves and loads wav files" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "tone.wav")
      original = described_class.new([0.0, 0.25, -0.25, 0.5], channels: 1, sample_rate: 44_100)

      original.save(path)
      loaded = described_class.load(path)

      expect(loaded.channels).to eq(1)
      expect(loaded.sample_rate).to eq(44_100)
      loaded.samples.first(4).zip(original.samples.first(4)).each do |actual, expected|
        expect(actual).to be_within(0.001).of(expected)
      end
    end
  end
end
