# frozen_string_literal: true

RSpec.describe "Advanced Tone.js-style components" do
  def constant_buffer(value, frames: 128, sample_rate: 44_100)
    Deftones::Buffer.from_mono(Array.new(frames, value), sample_rate: sample_rate)
  end

  it "convolves an input with an impulse response buffer" do
    context = Deftones::OfflineContext.new(duration: 0.04, sample_rate: 100, buffer_size: 4)
    source = Deftones::UserMedia.new(buffer: constant_buffer(1.0, frames: 4, sample_rate: 100), context: context).start(0.0)
    convolver = Deftones::Convolver.new(Deftones::Buffer.from_mono([1.0, 0.5], sample_rate: 100), context: context)

    source >> convolver >> context.output
    rendered = context.render

    expect(rendered.mono.first(4)).to eq([1.0, 1.5, 1.5, 1.5])
  end

  it "normalizes the impulse response when requested" do
    context = Deftones::OfflineContext.new(duration: 0.03, sample_rate: 100, buffer_size: 3)
    source = Deftones::UserMedia.new(buffer: constant_buffer(1.0, frames: 3, sample_rate: 100), context: context).start(0.0)
    convolver = Deftones::Convolver.new(
      Deftones::Buffer.from_mono([2.0, 1.0], sample_rate: 100),
      normalize: true,
      context: context
    )

    source >> convolver >> context.output
    rendered = context.render

    expect(rendered.mono.first(3)).to eq([1.0, 1.5, 1.5])
  end

  it "splits and merges a centered signal through mid/side nodes" do
    context = Deftones::OfflineContext.new(duration: 0.02, sample_rate: 100)
    source = Deftones::UserMedia.new(buffer: constant_buffer(0.25, frames: 2, sample_rate: 100), context: context).start(0.0)
    split = Deftones::MidSideSplit.new(context: context)
    merge = Deftones::MidSideMerge.new(context: context)

    source >> split
    split.mid >> merge.mid
    split.side >> merge.side
    merge >> context.output

    rendered = context.render

    expect(split.mid.render(2, 0).first).to be_within(0.001).of(0.25 * Math.sqrt(2.0))
    expect(split.side.render(2, 0)).to eq([0.0, 0.0])
    expect(rendered.peak).to be_within(0.001).of(0.25)
  end

  it "exposes component aliases for compatibility" do
    expect(Deftones::Convolver).to eq(Deftones::Component::Convolver)
    expect(Deftones::MidSideSplit).to eq(Deftones::Component::MidSideSplit)
    expect(Deftones::MidSideMerge).to eq(Deftones::Component::MidSideMerge)
    expect(Deftones::Mono).to eq(Deftones::Component::Mono)
  end

  it "splits low, mid, and high bands" do
    context = Deftones::OfflineContext.new(duration: 0.1, sample_rate: 8_000, buffer_size: 128)
    low_source = Deftones::Oscillator.new(type: :sine, frequency: 120, context: context).start(0.0)
    high_source = Deftones::Oscillator.new(type: :sine, frequency: 2_400, context: context).start(0.0)
    low_split = Deftones::MultibandSplit.new(low_frequency: 300, high_frequency: 1_000, context: context)
    high_split = Deftones::MultibandSplit.new(low_frequency: 300, high_frequency: 1_000, context: context)

    low_source >> low_split.input
    low_band_peak = Deftones::Buffer.from_mono(low_split.low.render(800, 0), sample_rate: 8_000).peak
    high_band_from_low_peak = Deftones::Buffer.from_mono(low_split.high.render(800, 0), sample_rate: 8_000).peak

    high_source >> high_split.input
    high_band_peak = Deftones::Buffer.from_mono(high_split.high.render(800, 0), sample_rate: 8_000).peak
    low_band_from_high_peak = Deftones::Buffer.from_mono(high_split.low.render(800, 0), sample_rate: 8_000).peak

    expect(low_band_peak).to be > (high_band_from_low_peak * 3.0)
    expect(high_band_peak).to be > (low_band_from_high_peak * 3.0)
  end

  it "compresses each band through the multiband compressor" do
    context = Deftones::OfflineContext.new(duration: 0.1, sample_rate: 8_000, buffer_size: 128)
    source = Deftones::Oscillator.new(type: :sine, frequency: 440, context: context).start(0.0)
    compressor = Deftones::MultibandCompressor.new(
      low_frequency: 300,
      high_frequency: 1_000,
      mid: { threshold: -36.0, ratio: 12.0, attack: 0.001, release: 0.01 },
      context: context
    )

    source >> compressor.input
    compressed = Deftones::Buffer.from_mono(compressor.render(800, 0), sample_rate: 8_000)
    dry = Deftones::Buffer.from_mono(source.render(800, 0), sample_rate: 8_000)

    expect(compressed.peak).to be < dry.peak
    expect(compressor.low_frequency.value).to eq(300.0)
    expect(compressor.high_frequency.value).to eq(1_000.0)
  end

  it "tracks amplitude envelopes with Follower" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([0.0, 1.0, 1.0, 0.0, 0.0], sample_rate: 100),
      context: context
    ).start(0.0)
    follower = Deftones::Follower.new(smoothing: 0.02, context: context)

    source >> follower
    output = follower.render(5, 0)

    expect(output[1]).to be > 0.3
    expect(output[2]).to be > output[1]
    expect(output[3]).to be < output[2]
    expect(output[3]).to be > 0.1
  end

  it "filters with a one-pole lowpass or highpass response" do
    context = Deftones::OfflineContext.new(duration: 0.1, sample_rate: 8_000, buffer_size: 128)
    low_source = Deftones::Oscillator.new(type: :sine, frequency: 120, context: context).start(0.0)
    high_source = Deftones::Oscillator.new(type: :sine, frequency: 2_400, context: context).start(0.0)
    lowpass = Deftones::OnePoleFilter.new(type: :lowpass, frequency: 300, context: context)
    highpass = Deftones::OnePoleFilter.new(type: :highpass, frequency: 300, context: context)
    lowpass_high = Deftones::OnePoleFilter.new(type: :lowpass, frequency: 300, context: context)
    highpass_high = Deftones::OnePoleFilter.new(type: :highpass, frequency: 300, context: context)

    low_source >> lowpass
    low_source >> highpass
    high_source >> lowpass_high
    high_source >> highpass_high

    lowpass_peak = Deftones::Buffer.from_mono(lowpass.render(800, 0), sample_rate: 8_000).peak
    highpass_peak = Deftones::Buffer.from_mono(highpass.render(800, 0), sample_rate: 8_000).peak
    lowpass_high_peak = Deftones::Buffer.from_mono(lowpass_high.render(800, 0), sample_rate: 8_000).peak
    highpass_high_peak = Deftones::Buffer.from_mono(highpass_high.render(800, 0), sample_rate: 8_000).peak

    expect(lowpass_peak).to be > (highpass_peak * 2.0)
    expect(highpass_high_peak).to be > (lowpass_high_peak * 2.0)
  end

  it "creates resonant comb filter responses" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([1.0, 0.0, 0.0, 0.0, 0.0], sample_rate: 100),
      context: context
    ).start(0.0)
    comb = Deftones::FeedbackCombFilter.new(delay_time: 0.01, resonance: 0.5, context: context)

    source >> comb

    expect(comb.render(5, 0)).to eq([0.0, 1.0, 0.5, 0.25, 0.125])
  end

  it "dampens the comb filter feedback path" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    impulse = Deftones::Buffer.from_mono([1.0, 0.0, 0.0, 0.0, 0.0], sample_rate: 100)
    source = Deftones::UserMedia.new(buffer: impulse, context: context).start(0.0)
    reference = Deftones::FeedbackCombFilter.new(delay_time: 0.01, resonance: 0.5, context: context)
    damped_source = Deftones::UserMedia.new(buffer: impulse, context: context).start(0.0)
    damped = Deftones::LowpassCombFilter.new(delay_time: 0.01, resonance: 0.5, dampening: 5.0, context: context)

    source >> reference
    damped_source >> damped

    reference_output = reference.render(5, 0)
    damped_output = damped.render(5, 0)

    expect(damped_output[1]).to eq(1.0)
    expect(damped_output[2]).to be < reference_output[2]
    expect(damped_output[3]).to be < reference_output[3]
  end

  it "attenuates by distance through Panner3D" do
    context = Deftones::OfflineContext.new(duration: 0.04, sample_rate: 100, buffer_size: 4)
    listener = Deftones::Listener.new(context: context)
    source_buffer = Deftones::Buffer.from_mono([1.0, 1.0, 1.0, 1.0], sample_rate: 100)
    near_source = Deftones::UserMedia.new(buffer: source_buffer, context: context).start(0.0)
    far_source = Deftones::UserMedia.new(buffer: source_buffer, context: context).start(0.0)
    near = Deftones::Panner3D.new(position_z: 1.0, listener: listener, context: context)
    far = Deftones::Panner3D.new(position_z: 10.0, listener: listener, context: context)

    near_source >> near
    far_source >> far

    near_peak = Deftones::Buffer.from_mono(near.render(4, 0), sample_rate: 100).peak
    far_peak = Deftones::Buffer.from_mono(far.render(4, 0), sample_rate: 100).peak

    expect(near_peak).to be > far_peak
    expect(far_peak).to be_within(0.001).of(0.1)
  end

  it "applies source cone attenuation in Panner3D" do
    context = Deftones::OfflineContext.new(duration: 0.04, sample_rate: 100, buffer_size: 4)
    listener = Deftones::Listener.new(context: context)
    source_buffer = Deftones::Buffer.from_mono([1.0, 1.0, 1.0, 1.0], sample_rate: 100)
    facing_source = Deftones::UserMedia.new(buffer: source_buffer, context: context).start(0.0)
    away_source = Deftones::UserMedia.new(buffer: source_buffer, context: context).start(0.0)
    facing = Deftones::Panner3D.new(
      position_x: 1.0,
      orientation_x: -1.0,
      cone_inner_angle: 60.0,
      cone_outer_angle: 180.0,
      cone_outer_gain: 0.25,
      listener: listener,
      context: context
    )
    away = Deftones::Panner3D.new(
      position_x: 1.0,
      orientation_x: 1.0,
      cone_inner_angle: 60.0,
      cone_outer_angle: 180.0,
      cone_outer_gain: 0.25,
      listener: listener,
      context: context
    )

    facing_source >> facing
    away_source >> away

    facing_peak = Deftones::Buffer.from_mono(facing.render(4, 0), sample_rate: 100).peak
    away_peak = Deftones::Buffer.from_mono(away.render(4, 0), sample_rate: 100).peak

    expect(facing_peak).to be > away_peak
    expect(away_peak).to be_within(0.001).of(0.25)
  end

  it "exposes Tone.js-style spatial aliases on Panner3D and Listener" do
    context = Deftones::OfflineContext.new(duration: 0.04, sample_rate: 100, buffer_size: 4)
    listener = Deftones::Listener.new(context: context)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([1.0, 1.0, 1.0, 1.0], sample_rate: 100),
      context: context
    ).start(0.0)
    panner = Deftones::Panner3D.new(listener: listener, context: context)

    listener.positionX = 1.0
    listener.positionY = 2.0
    listener.positionZ = 3.0
    listener.setOrientation(0.0, 0.0, -1.0, 0.0, 1.0, 0.0)
    panner.setPosition(1.0, 2.0, 4.0)
    panner.orientationX = 0.0
    panner.orientationY = 0.0
    panner.orientationZ = -1.0

    source >> panner
    output = panner.render(4, 0)

    expect(listener.positionX.value).to eq(1.0)
    expect(listener.positionY.value).to eq(2.0)
    expect(listener.positionZ.value).to eq(3.0)
    expect(panner.positionX.value).to eq(1.0)
    expect(panner.positionY.value).to eq(2.0)
    expect(panner.positionZ.value).to eq(4.0)
    expect(panner.orientationZ.value).to eq(-1.0)
    expect(output.first).to be > 0.0
  end

  it "compresses the mid channel through MidSideCompressor" do
    context = Deftones::OfflineContext.new(duration: 0.04, sample_rate: 100, buffer_size: 4)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([1.0, 1.0, 1.0, 1.0], sample_rate: 100),
      context: context
    ).start(0.0)
    compressor = Deftones::MidSideCompressor.new(
      mid: { threshold: -36.0, ratio: 20.0, attack: 0.001, release: 0.01 },
      context: context
    )

    source >> compressor
    compressed_peak = Deftones::Buffer.from_mono(compressor.render(4, 0), sample_rate: 100).peak

    expect(compressed_peak).to be < 1.0
    expect(compressor.mid).to be_a(Deftones::Compressor)
    expect(compressor.side).to be_a(Deftones::Compressor)
  end
end
