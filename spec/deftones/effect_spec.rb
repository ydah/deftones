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
    expect(rendered.uniq.sort).to eq([0.0, 0.5, 1.0])
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

  it "applies waveform and stage properties to modulation effects" do
    context = Deftones::OfflineContext.new(duration: 0.2, sample_rate: 100, buffer_size: 10)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(20, 1.0), sample_rate: 100),
      context: context
    ).start(0.0)

    chorus_a = Deftones::Chorus.new(
      frequency: 4.0,
      depth: 0.01,
      feedback: 0.2,
      spread: 0.0,
      type: :sine,
      context: context
    )
    chorus_b = Deftones::Chorus.new(
      frequency: 4.0,
      depth: 0.01,
      feedback: 0.2,
      spread: 180.0,
      type: :triangle,
      context: context
    )
    vibrato = Deftones::Vibrato.new(frequency: 5.0, depth: 0.01, type: :square, context: context)
    phaser_a = Deftones::Phaser.new(frequency: 1.0, base_frequency: 200.0, stages: 2, type: :sine, context: context)
    phaser_b = Deftones::Phaser.new(frequency: 1.0, base_frequency: 600.0, stages: 6, type: :triangle, context: context)

    source >> chorus_a >> context.output
    first = context.render.mono

    second_context = Deftones::OfflineContext.new(duration: 0.2, sample_rate: 100, buffer_size: 10)
    second_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(20, 1.0), sample_rate: 100),
      context: second_context
    ).start(0.0)
    second_source >> chorus_b >> second_context.output
    second = second_context.render.mono

    expect(chorus_a.type).to eq(:sine)
    expect(chorus_b.type).to eq(:triangle)
    expect(chorus_b.spread).to eq(180.0)
    expect(first).not_to eq(second)
    expect(vibrato.type).to eq(:square)
    expect(phaser_a.base_frequency).to eq(200.0)
    expect(phaser_b.stages).to eq(6)
    expect(phaser_b.type).to eq(:triangle)
  end

  it "applies tremolo spread as a phase offset in mono rendering" do
    tight_context = Deftones::OfflineContext.new(duration: 0.2, sample_rate: 100, buffer_size: 10)
    tight_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(20, 1.0), sample_rate: 100),
      context: tight_context
    ).start(0.0)
    tight = Deftones::Tremolo.new(frequency: 5.0, depth: 1.0, spread: 0.0, type: :sine, context: tight_context)
    tight_source >> tight >> tight_context.output
    tight_output = tight_context.render.mono

    wide_context = Deftones::OfflineContext.new(duration: 0.2, sample_rate: 100, buffer_size: 10)
    wide_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(20, 1.0), sample_rate: 100),
      context: wide_context
    ).start(0.0)
    wide = Deftones::Tremolo.new(frequency: 5.0, depth: 1.0, spread: 180.0, type: :sine, context: wide_context)
    wide_source >> wide >> wide_context.output
    wide_output = wide_context.render.mono

    expect(tight_output.uniq.length).to be > 1
    expect(wide_output).to all(be_within(0.001).of(0.5))
  end

  it "alternates ping pong delay repeats through cross-fed delay lines" do
    context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], sample_rate: 100),
      context: context
    ).start(0.0)
    delay = Deftones::PingPongDelay.new(delay_time: 0.02, feedback: 0.5, wet: 1.0, context: context)

    source >> delay >> context.output
    rendered = context.render.mono

    expect(rendered).to eq([0.0, 0.0, 1.0, 0.0, 0.5, 0.0, 0.25, 0.0])
  end

  it "shifts pitch with modulated delay heads instead of simple circular reads" do
    source_buffer = Deftones::Buffer.from_mono((0...12).map(&:to_f), sample_rate: 100)

    up_context = Deftones::OfflineContext.new(duration: 0.12, sample_rate: 100, buffer_size: 12)
    up_source = Deftones::UserMedia.new(buffer: source_buffer, context: up_context).start(0.0)
    up_shift = Deftones::PitchShift.new(
      pitch: 12.0,
      window_size: 0.04,
      delay_time: 0.02,
      wet: 1.0,
      context: up_context
    )
    up_source >> up_shift >> up_context.output
    up_output = up_context.render.mono

    down_context = Deftones::OfflineContext.new(duration: 0.12, sample_rate: 100, buffer_size: 12)
    down_source = Deftones::UserMedia.new(buffer: source_buffer, context: down_context).start(0.0)
    down_shift = Deftones::PitchShift.new(
      semitones: -12.0,
      window: 0.04,
      delay_time: 0.02,
      wet: 1.0,
      context: down_context
    )
    down_source >> down_shift >> down_context.output
    down_output = down_context.render.mono

    expect(up_shift.pitch).to eq(12.0)
    expect(up_shift.semitones).to eq(12.0)
    expect(up_shift.windowSize).to eq(0.04)
    expect(up_shift.delayTime.value).to eq(0.02)
    expect(up_output.first(2)).to eq([0.0, 0.0])
    expect(down_output.first(2)).to eq([0.0, 0.0])
    expect(up_output).not_to eq(down_output)
  end

  it "feeds pitch shifted output back into the delay network" do
    source_buffer = Deftones::Buffer.from_mono([1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], sample_rate: 100)

    no_feedback_context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    no_feedback_source = Deftones::UserMedia.new(buffer: source_buffer, context: no_feedback_context).start(0.0)
    no_feedback = Deftones::PitchShift.new(
      pitch: 0.0,
      window_size: 0.04,
      delay_time: 0.02,
      feedback: 0.0,
      wet: 1.0,
      context: no_feedback_context
    )
    no_feedback_source >> no_feedback >> no_feedback_context.output
    no_feedback_output = no_feedback_context.render.mono

    feedback_context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    feedback_source = Deftones::UserMedia.new(buffer: source_buffer, context: feedback_context).start(0.0)
    feedback = Deftones::PitchShift.new(
      pitch: 0.0,
      window_size: 0.04,
      delay_time: 0.02,
      feedback: 0.5,
      wet: 1.0,
      context: feedback_context
    )
    feedback_source >> feedback >> feedback_context.output
    feedback_output = feedback_context.render.mono

    expect(feedback.feedback.value).to eq(0.5)
    expect(no_feedback_output[2]).to be_within(0.001).of(1.0)
    expect(no_feedback_output[4].abs).to be < 0.001
    expect(feedback_output[2]).to be_within(0.001).of(1.0)
    expect(feedback_output[4]).to be_within(0.001).of(0.5)
  end

  it "follows amplitude with AutoWah sensitivity and follower settings" do
    source_buffer = Deftones::Buffer.from_mono([0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0], sample_rate: 100)

    fast_context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    fast_source = Deftones::UserMedia.new(buffer: source_buffer, context: fast_context).start(0.0)
    fast = Deftones::AutoWah.new(
      base_frequency: 80.0,
      octaves: 3.0,
      sensitivity: -30.0,
      gain: 4.0,
      follower: { attack: 0.0, release: 0.0 },
      context: fast_context
    )
    fast_source >> fast >> fast_context.output
    fast_output = fast_context.render.mono

    slow_context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    slow_source = Deftones::UserMedia.new(buffer: source_buffer, context: slow_context).start(0.0)
    slow = Deftones::AutoWah.new(
      base_frequency: 80.0,
      octaves: 3.0,
      sensitivity: -30.0,
      gain: 4.0,
      follower: { attack: 0.4, release: 0.4 },
      context: slow_context
    )
    slow_source >> slow >> slow_context.output
    slow_output = slow_context.render.mono

    insensitive_context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    insensitive_source = Deftones::UserMedia.new(buffer: source_buffer, context: insensitive_context).start(0.0)
    insensitive = Deftones::AutoWah.new(
      base_frequency: 80.0,
      octaves: 3.0,
      sensitivity: 0.0,
      gain: 1.0,
      follower: { attack: 0.0, release: 0.0 },
      context: insensitive_context
    )
    insensitive_source >> insensitive >> insensitive_context.output
    insensitive_output = insensitive_context.render.mono

    expect(fast.sensitivity).to eq(-30.0)
    expect(fast.gain).to eq(4.0)
    expect(fast.follower.attack).to eq(0.0)
    expect(fast.follower.release).to eq(0.0)
    expect(fast_output[2].abs).to be > slow_output[2].abs
    expect(fast_output.sum(&:abs)).to be > insensitive_output.sum(&:abs)
  end
end
