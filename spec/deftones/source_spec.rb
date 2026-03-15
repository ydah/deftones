# frozen_string_literal: true

RSpec.describe "Source generators" do
  it "renders the standalone source classes" do
    context = Deftones::OfflineContext.new(duration: 0.2)
    sources = [
      Deftones::Noise.new(type: :pink, context: context),
      Deftones::PulseOscillator.new(frequency: 110, width: 0.3, context: context),
      Deftones::FMOscillator.new(frequency: 220, harmonicity: 1.5, modulation_index: 3.0, context: context),
      Deftones::AMOscillator.new(frequency: 220, harmonicity: 2.0, context: context),
      Deftones::FatOscillator.new(type: :triangle, frequency: 110, count: 4, context: context),
      Deftones::PWMOscillator.new(frequency: 110, modulation_frequency: 2.0, context: context),
      Deftones::OmniOscillator.new(type: :pulse, frequency: 220, context: context)
    ]

    sources.each { |source| source >> context.output }
    karplus = Deftones::Source::KarplusStrong.new(context: context)
    karplus.trigger("C4", 0.0, 0.8)
    karplus >> context.output

    buffer = context.render

    expect(buffer.peak).to be > 0.1
    expect(buffer.rms).to be > 0.01
  end

  it "renders ToneBufferSource with offset, duration, and detune" do
    context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    buffer = Deftones::Buffer.from_mono((0...8).map(&:to_f), sample_rate: 100)
    ended_at = nil
    source = Deftones::ToneBufferSource.new(
      buffer: buffer,
      playback_rate: 1.0,
      detune: 1_200.0,
      context: context
    )
    source.onended = ->(time) { ended_at = time }
    source >> context.output

    expect(source.state(0.0)).to eq(:stopped)

    source.start(0.0, 0.01, 0.02)
    rendered = context.render

    expect(source.state(0.03)).to eq(:stopped)
    expect(rendered.mono.first(4)).to eq([1.0, 3.0, 0.0, 0.0])
    expect(ended_at).to be_within(0.01).of(0.02)
  end

  it "renders ToneOscillatorNode with detune and stop state" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    ended_at = nil
    oscillator = Deftones::ToneOscillatorNode.new(type: :sine, frequency: 5, detune: 1_200.0, context: context)
    oscillator.onended = ->(time) { ended_at = time }
    oscillator >> context.output

    oscillator.start(0.0)
    oscillator.stop(0.02)
    rendered = context.render

    expect(oscillator.state(0.0)).to eq(:started)
    expect(oscillator.state(0.03)).to eq(:stopped)
    expect(rendered.peak).to be > 0.5
    expect(ended_at).to be_within(0.01).of(0.02)
  end

  it "exposes Tone.js-style Player helpers" do
    context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    buffer = Deftones::Buffer.from_mono((0...8).map(&:to_f), sample_rate: 100)
    stopped_at = nil
    player = Deftones::Player.new(buffer: buffer, fade_in: 0.01, onstop: ->(time) { stopped_at = time }, context: context)
    player >> context.output

    expect(player.loaded).to eq(true)
    expect(player.state(0.0)).to eq(:stopped)

    player.playbackRate = 1.0
    player.loopStart = 0.01
    player.loopEnd = 0.03
    player.start(0.0, 0.01, 0.03)
    rendered = context.render

    expect(player.state(0.04)).to eq(:stopped)
    expect(rendered.mono.first(4)).to eq([0.0, 2.0, 3.0, 0.0])
    expect(stopped_at).to be_within(0.01).of(0.03)
  end

  it "exposes Tone.js-style Players collection helpers" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    buffer = Deftones::Buffer.from_mono([1.0, 0.0, 1.0, 0.0, 1.0], sample_rate: 100)
    players = Deftones::Players.new({ kick: buffer }, context: context)
    snare = players.add(:snare, buffer)

    expect(players.get(:kick)).to be_a(Deftones::Player)
    expect(players.has?(:snare)).to eq(true)
    expect(players.loaded).to eq(true)

    players.each { |player| player >> context.output }
    players.get(:kick).start(0.0)
    snare.start(0.0)
    rendered = context.render

    expect(rendered.peak).to eq(2.0)
    players.stopAll(0.01)
    expect(players.get(:kick).state(0.02)).to eq(:stopped)

    players.dispose
    expect(players.loaded?).to eq(false)
  end
end
