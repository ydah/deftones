# frozen_string_literal: true

RSpec.describe "Effects and dynamics" do
  def render_with(node)
    context = Deftones::OfflineContext.new(duration: 0.25)
    oscillator = Deftones::Oscillator.new(type: :sawtooth, frequency: 220, context: context)
    oscillator >> node >> context.output
    context.render
  end

  it "renders the effect classes" do
    effects = [
      Deftones::Distortion.new(amount: 0.7),
      Deftones::BitCrusher.new(bits: 6, downsample: 3),
      Deftones::Chebyshev.new(order: 4),
      Deftones::FeedbackDelay.new(delay_time: 0.03, feedback: 0.25),
      Deftones::PingPongDelay.new(delay_time: 0.025, feedback: 0.2),
      Deftones::Reverb.new(decay: 0.55),
      Deftones::Freeverb.new(decay: 0.65),
      Deftones::JCReverb.new(decay: 0.45),
      Deftones::Chorus.new(frequency: 1.2),
      Deftones::Phaser.new(frequency: 0.8),
      Deftones::Tremolo.new(frequency: 4.0),
      Deftones::Vibrato.new(frequency: 5.0),
      Deftones::AutoFilter.new(frequency: 1.5),
      Deftones::AutoPanner.new(frequency: 2.0),
      Deftones::AutoWah.new(base_frequency: 250),
      Deftones::FrequencyShifter.new(frequency: 40),
      Deftones::PitchShift.new(semitones: 5),
      Deftones::StereoWidener.new(width: 0.7)
    ]

    effects.each do |effect|
      buffer = render_with(effect)
      expect(buffer.peak).to be > 0.001
    end
  end

  it "renders eq and dynamics nodes" do
    context = Deftones::OfflineContext.new(duration: 0.25)
    oscillator = Deftones::Oscillator.new(type: :triangle, frequency: 220, context: context)
    eq = Deftones::EQ3.new(low: 3.0, mid: -1.0, high: 2.0, context: context)
    compressor = Deftones::Compressor.new(threshold: -24.0, ratio: 3.0, context: context)
    limiter = Deftones::Limiter.new(context: context)
    gate = Deftones::Gate.new(threshold: -60.0, context: context)

    oscillator >> eq >> compressor >> limiter >> gate >> context.output
    buffer = context.render

    expect(buffer.peak).to be > 0.001
    expect(buffer.rms).to be > 0.001
  end

  it "controls modulation effects through compatibility helpers" do
    Deftones.reset!
    Deftones.transport.bpm = 120
    context = Deftones::OfflineContext.new(duration: 0.6, sample_rate: 100, buffer_size: 10)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(60, 1.0), sample_rate: 100),
      context: context
    ).start(0.0)
    tremolo = Deftones::Tremolo.new(frequency: 5.0, depth: 1.0, context: context)
    source >> tremolo >> context.output
    tremolo.sync

    tremolo.start("8n")
    tremolo.stop("4n")
    rendered = context.render.mono

    expect(tremolo.synced?).to eq(true)
    expect(tremolo.state(0.1)).to eq(:stopped)
    expect(tremolo.state(0.3)).to eq(:started)
    expect(rendered.first(25).uniq).to eq([1.0])
    expect(rendered[25, 20].uniq.length).to be > 1
    expect(rendered.last(10).uniq).to eq([1.0])

    tremolo.unsync
    expect(tremolo.synced?).to eq(false)
  ensure
    Deftones.reset!
  end

  it "exposes modulation waveform properties on compatibility effects" do
    context = Deftones::OfflineContext.new(duration: 0.2, sample_rate: 100, buffer_size: 10)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(20, 1.0), sample_rate: 100),
      context: context
    ).start(0.0)
    tremolo = Deftones::Tremolo.new(frequency: 5.0, depth: 1.0, spread: 120.0, type: :square, context: context)
    auto_panner = Deftones::AutoPanner.new(frequency: 5.0, depth: 0.5, type: :triangle, context: context)
    auto_filter = Deftones::AutoFilter.new(
      frequency: 2.0,
      base_frequency: 300.0,
      depth: 0.25,
      type: :sawtooth,
      context: context
    )
    source >> tremolo >> context.output

    rendered = context.render.mono

    expect(tremolo.type).to eq(:square)
    expect(tremolo.spread).to eq(120.0)
    expect(rendered.uniq.sort).to eq([0.0, 1.0])
    expect(auto_panner.type).to eq(:triangle)
    expect(auto_filter.type).to eq(:sawtooth)
    expect(auto_filter.baseFrequency).to eq(300.0)
    expect(auto_filter.depth).to eq(0.25)
    expect(auto_filter.filter.type).to eq(:lowpass)

    auto_filter.filter.type = :highpass
    auto_filter.q = 2.0
    expect(auto_filter.filter.type).to eq(:highpass)
    expect(auto_filter.q).to eq(2.0)
  end
end
