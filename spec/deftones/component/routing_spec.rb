# frozen_string_literal: true

RSpec.describe "Additional routing components" do
  class FakeCaptureBackend
    attr_reader :started, :stopped

    def initialize(samples)
      @initial_samples = samples.dup
      @samples = samples.dup
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
      @samples = @initial_samples.dup
      self
    end

    def next_sample
      @samples.shift || 0.0
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

  it "exposes Tone.js-style UserMedia helpers" do
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
end
