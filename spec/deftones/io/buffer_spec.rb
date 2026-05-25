# frozen_string_literal: true

require "open3"
require "stringio"
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
    expect(buffer.sliceSeconds(0.25, 0.5).samples).to eq([0.5, -0.5])
    expect(buffer.normalize(0.5).peak).to be_within(0.001).of(0.5)
    expect(buffer.normalizeRms(0.25).rms).to be_within(0.001).of(0.25)
    expect(buffer.sample_at(1.5)).to be_within(0.001).of(0.0)
    expect(buffer.clip_count(1.0)).to eq(1)
    stats = buffer.statistics(clip_threshold: 0.5)
    expect(stats.peak).to eq(1.0)
    expect(stats.rms).to be_within(0.001).of(0.612)
    expect(stats.clip_count).to eq(3)
    expect(buffer.stats(clip_threshold: 0.5)).to equal(stats)

    interpolated = described_class.new([0.0, 1.0, 0.0, 0.0], channels: 1, sample_rate: 4)
    expect(interpolated.sampleAtNearest(1.4)).to eq(1.0)
    expect(interpolated.sampleAtCubic(1.5)).to be_within(0.001).of(0.5625)
    expect(interpolated.sampleAtSincLite(1.0)).to be_within(0.000001).of(1.0)
    expect(interpolated.sample_at(1.5, interpolation: :sinc_lite)).to be_between(0.0, 1.0)
    interpolated.interpolation = :nearest
    expect(interpolated.sampleAt(1.6)).to eq(0.0)
    expect { interpolated.interpolation = :unknown }.to raise_error(ArgumentError, /interpolation/)
  end

  it "resamples buffers through the configured interpolation mode" do
    buffer = described_class.from_array(
      [[0.0, 1.0, 0.0, -1.0], [1.0, 0.0, -1.0, 0.0]],
      sample_rate: 4,
      interpolation: :nearest
    )

    upsampled = buffer.resample(8, interpolation: :linear)
    downsampled = buffer.resampleTo(2, interpolation: :nearest)
    sinc_upsampled = buffer.resample(8, interpolation: :sinc_lite)
    unchanged = buffer.resample(4)

    expect(upsampled.sample_rate).to eq(8)
    expect(upsampled.number_of_channels).to eq(2)
    expect(upsampled.interpolation).to eq(:linear)
    expect(upsampled.frames).to eq(8)
    expect(upsampled.get_channel_data(0).first(4)).to eq([0.0, 0.5, 1.0, 0.5])
    expect(downsampled.sample_rate).to eq(2)
    expect(downsampled.interpolation).to eq(:nearest)
    expect(downsampled.get_channel_data(0)).to eq([0.0, 0.0])
    expect(sinc_upsampled.interpolation).to eq(:sinc_lite)
    expect(sinc_upsampled.get_channel_data(0)[2]).to be_within(0.000001).of(1.0)
    expect(unchanged.interpolation).to eq(:nearest)
    expect { buffer.resample(0) }.to raise_error(ArgumentError, /sample rate/)
  end

  it "preserves channel frames through reverse and array conversion" do
    buffer = described_class.from_array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], sample_rate: 3)

    expect(buffer.reverse.toArray).to eq([[3.0, 2.0, 1.0], [6.0, 5.0, 4.0]])
    expect(described_class.from_array(buffer.to_array, sample_rate: buffer.sample_rate).samples).to eq(buffer.samples)
  end

  it "keeps frame operations coherent across channel counts" do
    [1, 2, 4].each do |channels|
      channel_data = Array.new(channels) do |channel_index|
        Array.new(4) { |frame_index| channel_index + (frame_index * 0.25) }
      end
      buffer = described_class.from_array(channel_data, sample_rate: 4)

      expect(described_class.from_array(buffer.to_array, sample_rate: 4, channels: channels).samples).to eq(buffer.samples)
      expect(buffer.reverse.reverse.samples).to eq(buffer.samples)
      expect(buffer.slice(1, 2).to_array).to eq(channel_data.map { |channel| channel[1, 2] })
    end

    expect(described_class.interleave([0.1, 0.2], 3)).to eq([0.1, 0.1, 0.1, 0.2, 0.2, 0.2])
  end

  it "clamps slice boundaries and preserves buffer processing settings" do
    buffer = described_class.new([0.0, 1.0, 2.0, 3.0], channels: 1, sample_rate: 4, interpolation: :cubic)

    expect(buffer.slice(-2, 2).samples).to eq([0.0, 1.0])
    expect(buffer.slice(10, 2).samples).to eq([])
    expect(buffer.slice(1, -2).samples).to eq([])
    expect(buffer.slice(1, 2).interpolation).to eq(:cubic)
    expect(buffer.reverse.interpolation).to eq(:cubic)
    expect(buffer.normalize(0.5).interpolation).to eq(:cubic)
    expect(buffer.normalizeRms(0.5).interpolation).to eq(:cubic)
    expect(buffer.mixdown.interpolation).to eq(:cubic)
    expect { buffer.normalize(-0.1) }.to raise_error(ArgumentError, /target peak/)
    expect { buffer.normalizeRms(Float::INFINITY) }.to raise_error(ArgumentError, /target RMS/)
  end

  it "exposes ToneAudioBuffer compatibility helpers" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "tone.wav")
      source = described_class.new([0.0, 0.25, -0.25, 0.5], channels: 1, sample_rate: 8_000)
      source.save(path)

      buffer = described_class.from_array([[0.0, 0.5], [1.0, -1.0]], sample_rate: 8_000)

      expect(buffer.length).to eq(2)
      expect(buffer.numberOfChannels).to eq(2)
      expect(buffer.getChannelData(0)).to eq([0.0, 0.5])
      expect(buffer.toArray).to eq([[0.0, 0.5], [1.0, -1.0]])
      expect(described_class.fromArray([0.25, -0.25], sample_rate: 8_000).samples).to eq([0.25, -0.25])
      expect(described_class.fromUrl(path)).to be_a_kind_of(described_class)
      expect(described_class.loaded).to eq(true)
    end
  end

  it "disposes a ToneAudioBuffer-compatible instance" do
    buffer = described_class.new([0.0, 0.5], channels: 1, sample_rate: 4)

    expect(buffer.loaded?).to eq(true)
    buffer.dispose
    expect(buffer.loaded?).to eq(false)
    expect(buffer.samples).to eq([])
  end

  it "saves and loads wav files" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "tone.wav")
      original = described_class.new([0.0, 0.25, -0.25, 0.5], channels: 1, sample_rate: 44_100)

      original.save(path, bit_depth: 24, dither: true, dither_rng: Random.new(1))
      loaded = described_class.load(path)
      wav = Wavify::Codecs::Wav.read(path)

      expect(loaded.channels).to eq(1)
      expect(loaded.sample_rate).to eq(44_100)
      expect(wav.format.bit_depth).to eq(24)
      loaded.samples.first(4).zip(original.samples.first(4)).each do |actual, expected|
        expect(actual).to be_within(0.001).of(expected)
      end
      expect { original.save(path, bit_depth: 8) }.to raise_error(ArgumentError, /bit depth/)
    end
  end

  it "loads from and saves to IO objects" do
    source = described_class.new([0.0, 0.25, -0.25, 0.5], channels: 1, sample_rate: 8_000)
    io = StringIO.new
    source.save(io, format: :wav)
    io.rewind

    loaded = described_class.load(io)

    expect(loaded.sample_rate).to eq(8_000)
    expect(loaded.samples.first(4).zip(source.samples).all? { |actual, expected| (actual - expected).abs < 0.001 }).to eq(true)
  end

  it "raises when an explicit format conflicts with the file extension" do
    expect do
      described_class.new([0.0], channels: 1, sample_rate: 44_100).save("tone.wav", format: :mp3)
    end.to raise_error(Deftones::UnsupportedAudioFormatError, /does not match/)
  end

  it "validates path strings before codec backends receive them" do
    buffer = described_class.new([0.0], channels: 1, sample_rate: 44_100)

    expect { described_class.load("bad\0name.wav") }.to raise_error(ArgumentError, /null byte/)
    expect { buffer.save("") }.to raise_error(ArgumentError, /empty/)
    expect { buffer.save("bad\0name.wav") }.to raise_error(ArgumentError, /null byte/)
  end

  it "raises a codec backend error when wavify is unavailable" do
    buffer = described_class.new([0.0], channels: 1, sample_rate: 44_100)

    allow(Deftones).to receive(:wavify_available?).and_return(false)

    expect { buffer.save("tone.wav") }.to raise_error(Deftones::MissingCodecBackendError, /wavify/)
    expect { described_class.load("tone.wav") }.to raise_error(Deftones::MissingCodecBackendError, /wavify/)
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

  it "saves mp3 and ogg files when an encoder is available" do
    skip "ffmpeg is not installed" unless command_available?("ffmpeg")

    Dir.mktmpdir do |directory|
      mp3_path = File.join(directory, "tone.mp3")
      ogg_path = File.join(directory, "tone.ogg")
      source = described_class.new(Array.new(4_410) { |index| Math.sin(index / 10.0) * 0.4 }, channels: 1, sample_rate: 44_100)

      source.save(mp3_path)
      source.save(ogg_path)

      expect(File).to exist(mp3_path)
      expect(File).to exist(ogg_path)
      expect(described_class.load(mp3_path).peak).to be > 0.05
      expect(described_class.load(ogg_path).peak).to be > 0.05
    end
  end

  it "allows codec backend injection for compressed audio" do
    backend = Class.new do
      attr_reader :decoded

      def initialize(source)
        @source = source
        @decoded = false
      end

      def decode(_input_path, output_path, extension:)
        @decoded = extension == ".mp3"
        File.binwrite(output_path, File.binread(@source))
      end
    end

    Dir.mktmpdir do |directory|
      wav_path = File.join(directory, "tone.wav")
      mp3_path = File.join(directory, "tone.mp3")
      original = described_class.new([0.0, 0.25], channels: 1, sample_rate: 44_100)
      original.save(wav_path)
      File.binwrite(mp3_path, "placeholder")
      injected = backend.new(wav_path)

      described_class.codec_backend = injected
      loaded = described_class.load(mp3_path)

      expect(injected.decoded).to eq(true)
      expect(loaded.peak).to be_within(0.001).of(0.25)
    ensure
      described_class.codec_backend = nil
    end
  end

  it "raises structured codec command errors" do
    status = instance_double(Process::Status, success?: false, exitstatus: 7)

    expect do
      described_class.send(:raise_codec_command_error, "Failed to encode mp3", ["encoder"], "", "bad codec", status)
    end.to raise_error(Deftones::CodecCommandError) do |error|
      expect(error.command).to eq(["encoder"])
      expect(error.stderr).to eq("bad codec")
      expect(error.status.exitstatus).to eq(7)
      expect(error.message).to include("bad codec")
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

  it "aggregates bulk load errors when requested" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "tone.wav")
      source = Deftones::Buffer.new([0.0, 0.25], channels: 1, sample_rate: 44_100)
      source.save(path)

      expect do
        described_class.new({ kick: path, broken: File.join(directory, "missing.nope") }, aggregate_errors: true)
      end.to raise_error(Deftones::IO::Buffers::BulkLoadError) do |error|
        expect(error.errors.keys).to eq([:broken])
      end

      buffers = described_class.new
      expect { buffers.add(:kick, path) }.not_to raise_error
      buffers.dispose
      expect { buffers.add(:snare, source) }.to raise_error(Deftones::Error, /disposed/)
    end
  end

  it "exposes ToneAudioBuffers compatibility helpers" do
    source = Deftones::Buffer.new([0.0, 0.25], channels: 1, sample_rate: 44_100)
    buffers = described_class.new(kick: source)

    buffers.add(:snare, source)

    expect(buffers.get(:kick)).to eq(source)
    expect(buffers.has?(:snare)).to eq(true)
    expect(buffers.loaded).to eq(true)

    buffers.dispose
    expect(buffers.loaded?).to eq(false)
    expect(buffers.keys).to eq([])
  end
end
