# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe Deftones::IO::Buffer do
  def command_available?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      executable = File.join(directory, name)
      File.file?(executable) && File.executable?(executable)
    end
  end

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

  it "loads mp3 and ogg files through ffmpeg when available" do
    skip "ffmpeg is not installed" unless command_available?("ffmpeg")

    Dir.mktmpdir do |directory|
      wav_path = File.join(directory, "tone.wav")
      mp3_path = File.join(directory, "tone.mp3")
      ogg_path = File.join(directory, "tone.ogg")
      original = described_class.new(Array.new(4_410) { |index| Math.sin(index / 10.0) * 0.5 }, channels: 1, sample_rate: 44_100)

      original.save(wav_path)
      expect(Open3.capture3("ffmpeg", "-v", "error", "-y", "-i", wav_path, mp3_path).last.success?).to eq(true)
      expect(Open3.capture3("ffmpeg", "-v", "error", "-y", "-i", wav_path, ogg_path).last.success?).to eq(true)

      [mp3_path, ogg_path].each do |path|
        loaded = described_class.load(path)

        expect(loaded.channels).to eq(1)
        expect(loaded.sample_rate).to eq(44_100)
        expect(loaded.duration).to be_within(0.02).of(original.duration)
        expect(loaded.peak).to be > 0.05
      end
    end
  end
end

RSpec.describe Deftones::IO::Buffers do
  it "loads and stores named buffers" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "tone.wav")
      source = Deftones::Buffer.new([0.0, 0.25, -0.25, 0.5], channels: 1, sample_rate: 44_100)
      source.save(path)

      buffers = described_class.new(kick: path)
      buffers.add(:snare, source)

      expect(buffers[:kick]).to be_a(Deftones::Buffer)
      expect(buffers.fetch(:snare)).to eq(source)
      expect(buffers.keys).to contain_exactly(:kick, :snare)
    end
  end
end
