# frozen_string_literal: true

RSpec.describe "Additional routing components" do
  class FakeCaptureBackend
    attr_reader :started, :stopped, :channels

    def initialize(samples, channels: nil)
      @initial_samples = samples.map { |sample| sample.is_a?(Array) ? sample.dup : sample }
      @samples = @initial_samples.map { |sample| sample.is_a?(Array) ? sample.dup : sample }
      @channels = infer_channels(samples, channels)
      @started = false
      @stopped = false
    end

    def start
      @started = true
      self
    end

    def stop
      @stopped = true
      self
    end

    def rewind
      @samples = @initial_samples.map { |sample| sample.is_a?(Array) ? sample.dup : sample }
      self
    end

    def next_sample
      frame = next_frame
      frame.sum / [frame.length, 1].max.to_f
    end

    def next_frame
      sample = @samples.shift
      return Array.new(@channels, 0.0) if sample.nil?
      return normalize_frame(sample) if sample.is_a?(Array)

      Array.new(@channels, sample.to_f)
    end

    private

    def infer_channels(samples, channels)
      return [channels.to_i, 1].max if channels

      first = samples.find { |sample| !sample.nil? }
      return [first.length, 1].max if first.is_a?(Array)

      1
    end

    def normalize_frame(frame)
      normalized = frame.map(&:to_f)
      normalized.fill(0.0, normalized.length...@channels)
    end
  end

  def constant_buffer(value, frames: 512, sample_rate: 44_100)
    Deftones::Buffer.from_mono(Array.new(frames, value), sample_rate: sample_rate)
  end

  it "keeps Param compatible with Signal semantics" do
    context = Deftones::OfflineContext.new(duration: 0.01)
    param = Deftones::Param.new(value: "A4", units: :frequency, context: context)

    expect(param.value).to eq(440.0)
    expect(param.process(2, 0)).to eq([440.0, 440.0])
  end

  it "renders UserMedia through CrossFade" do
    context = Deftones::OfflineContext.new(duration: 0.01)
    low = Deftones::UserMedia.new(buffer: constant_buffer(0.1), context: context).start(0.0)
    high = Deftones::UserMedia.new(provider: Array.new(512, 0.5).each, context: context).start(0.0)
    cross_fade = Deftones::CrossFade.new(fade: 0.75, context: context)

    low >> cross_fade.a
    high >> cross_fade.b
    cross_fade >> context.output

    rendered = context.render

    expect(rendered.peak).to be_within(0.05).of(0.4)
    expect(rendered.rms).to be > 0.3
  end

  it "duplicates and recombines a signal through Split and Merge" do
    context = Deftones::OfflineContext.new(duration: 0.01)
    source = Deftones::UserMedia.new(buffer: constant_buffer(0.25), context: context).start(0.0)
    split = Deftones::Split.new(context: context)
    merge = Deftones::Merge.new(context: context)

    source >> split
    split.left >> merge.left
    split.right >> merge.right
    merge >> context.output

    rendered = context.render

    expect(rendered.peak).to be_within(0.05).of(0.25)
    expect(rendered.rms).to be > 0.2
  end

  it "renders explicit split taps per channel" do
    context = Deftones::OfflineContext.new(duration: 0.01, sample_rate: 100, buffer_size: 10, channels: 2)
    merge = Deftones::Merge.new(context: context)
    left_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(10, 0.2), sample_rate: 100),
      context: context
    ).start(0.0)
    right_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(10, 0.6), sample_rate: 100),
      context: context
    ).start(0.0)
    split = Deftones::Split.new(context: context)

    left_source >> merge.left
    right_source >> merge.right
    merge >> split

    expect(split.left.render(10, 0)).to all(be_within(0.001).of(0.2))
    expect(split.right.render(10, 0)).to all(be_within(0.001).of(0.6))
  end

  it "renders distinct stereo channels through Merge" do
    context = Deftones::OfflineContext.new(duration: 0.01, sample_rate: 100, buffer_size: 10, channels: 2)
    left_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(10, 0.2), sample_rate: 100),
      context: context
    ).start(0.0)
    right_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(10, 0.6), sample_rate: 100),
      context: context
    ).start(0.0)
    merge = Deftones::Merge.new(context: context)

    left_source >> merge.left
    right_source >> merge.right
    merge >> context.output

    rendered = context.render

    expect(rendered.get_channel_data(0)).to all(be_within(0.001).of(0.2))
    expect(rendered.get_channel_data(1)).to all(be_within(0.001).of(0.6))
  end

  it "renders pan as stereo output through Channel" do
    context = Deftones::OfflineContext.new(duration: 0.01, sample_rate: 100, buffer_size: 10, channels: 2)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(10, 1.0), sample_rate: 100),
      context: context
    ).start(0.0)
    channel = Deftones::Channel.new(pan: -1.0, context: context)

    source >> channel >> context.output
    rendered = context.render

    expect(rendered.get_channel_data(0)).to all(be_within(0.001).of(1.0))
    expect(rendered.get_channel_data(1)).to all(be_within(0.001).of(0.0))
  end

  it "balances stereo input without collapsing channels in Panner" do
    context = Deftones::OfflineContext.new(duration: 0.01, sample_rate: 100, buffer_size: 10, channels: 2)
    merge = Deftones::Merge.new(context: context)
    left_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(10, 0.4), sample_rate: 100),
      context: context
    ).start(0.0)
    right_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(10, 0.8), sample_rate: 100),
      context: context
    ).start(0.0)
    panner = Deftones::Panner.new(pan: -1.0, context: context)

    left_source >> merge.left
    right_source >> merge.right
    merge >> panner >> context.output
    rendered = context.render

    expect(rendered.get_channel_data(0)).to all(be_within(0.001).of(0.4))
    expect(rendered.get_channel_data(1)).to all(be_within(0.001).of(0.0))
  end

  it "renders UserMedia from a live capture backend" do
    context = Deftones::OfflineContext.new(duration: 0.01, sample_rate: 100)
    backend = FakeCaptureBackend.new(Array.new(8, 0.3))
    user_media = Deftones::UserMedia.new(capture_backend: backend, context: context).start(0.0)

    user_media >> context.output
    rendered = context.render

    expect(backend.started).to eq(true)
    expect(rendered.peak).to be > 0.2

    user_media.stop
    expect(backend.stopped).to eq(true)
  end

  it "preserves stereo channels for live capture backends" do
    context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 4, channels: 2)
    backend = FakeCaptureBackend.new(Array.new(8) { [0.2, 0.7] }, channels: 2)
    user_media = Deftones::UserMedia.new(capture_backend: backend, context: context).start(0.0)

    user_media >> context.output
    rendered = context.render

    expect(rendered.get_channel_data(0)).to all(be_within(0.001).of(0.2))
    expect(rendered.get_channel_data(1)).to all(be_within(0.001).of(0.7))
  end

  it "exposes compatibility UserMedia helpers" do
    context = Deftones::OfflineContext.new(duration: 0.03, sample_rate: 100)
    backend = FakeCaptureBackend.new([0.25, 0.25, 0.25])
    user_media = Deftones::UserMedia.new(capture_backend: backend, context: context)

    expect(Deftones::UserMedia.supported).to eq(true)
    expect(user_media.state).to eq(:stopped)
    expect(user_media.opened?).to eq(false)

    user_media.open(0.0, device_id: "default", group_id: "input", label: "Mic")
    user_media >> context.output
    rendered = context.render

    expect(user_media.device_id).to eq("default")
    expect(user_media.group_id).to eq("input")
    expect(user_media.label).to eq("Mic")
    expect(user_media.opened?).to eq(true)
    expect(user_media.state(0.0)).to eq(:started)
    expect(rendered.peak).to be > 0.2

    user_media.close
    expect(user_media.opened?).to eq(false)
    expect(user_media.state).to eq(:stopped)
  end

  it "enumerates UserMedia input devices through compatibility helpers" do
    device = instance_double("PortAudioDevice", name: "Built-in Mic", device_index: 2, max_input_channels: 2, max_output_channels: 0)
    allow(Deftones).to receive(:portaudio_available?).and_return(true)
    allow(Deftones::UserMedia).to receive(:portaudio_devices).and_return([device])

    devices = Deftones::UserMedia.enumerateDevices

    expect(Deftones::UserMedia.input_devices).to eq(devices)
    expect(devices.length).to eq(1)
    expect(devices.first.device_id).to eq(2)
    expect(devices.first.label).to eq("Built-in Mic")
    expect(devices.first.input_channels).to eq(2)
  end
end
