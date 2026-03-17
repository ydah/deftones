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

  it "syncs source timing against the transport and exposes stop callbacks" do
    Deftones.reset!
    Deftones.transport.bpm = 120
    context = Deftones::OfflineContext.new(duration: 0.6, sample_rate: 100, buffer_size: 10)
    stopped_at = nil
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 5, context: context)
    oscillator.onstop = ->(time) { stopped_at = time }
    oscillator.sync
    oscillator >> context.output

    oscillator.start("8n")
    oscillator.stop("4n")
    rendered = context.render

    expect(oscillator.synced?).to eq(true)
    expect(rendered.mono.first(25).all?(&:zero?)).to eq(true)
    expect(rendered.mono[25, 24].any? { |sample| sample.nonzero? }).to eq(true)
    expect(rendered.mono.last(10).all?(&:zero?)).to eq(true)
    expect(stopped_at).to be_within(0.001).of(0.5)

    oscillator.unsync
    expect(oscillator.synced?).to eq(false)
  ensure
    Deftones.reset!
  end

  it "supports restart and cancelStop on standalone sources" do
    oscillator = Deftones::Oscillator.new(frequency: 10, context: Deftones::OfflineContext.new(duration: 0.1))

    oscillator.start(0.0)
    oscillator.stop(0.02)
    oscillator.cancelStop
    oscillator.restart(0.05)

    expect(oscillator.state(0.03)).to eq(:stopped)
    expect(oscillator.state(0.06)).to eq(:started)
  end

  it "exposes source nodes without inputs" do
    oscillator = Deftones::Oscillator.new(context: Deftones::OfflineContext.new(duration: 0.1))

    expect(oscillator.input).to be_nil
    expect(oscillator.numberOfInputs).to eq(0)
  end

  it "applies shared volume and mute helpers on sources" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    buffer = Deftones::Buffer.from_mono([1.0, 1.0, 1.0, 1.0, 1.0], sample_rate: 100)
    player = Deftones::Player.new(buffer: buffer, context: context)
    player.volume.value = -6.0
    player.start(0.0)
    player >> context.output

    expect(player.volume.value).to eq(-6.0)
    expect(player.mute?).to eq(false)
    expect(context.render.mono.first(3)).to all(be_within(0.001).of(Deftones.db_to_gain(-6.0)))

    muted_context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    muted_player = Deftones::Player.new(buffer: buffer, context: muted_context)
    muted_player.mute = true
    muted_player.start(0.0)
    muted_player >> muted_context.output

    expect(muted_player.mute?).to eq(true)
    expect(muted_context.render.mono).to all(eq(0.0))
  end

  it "exposes noise playbackRate compatibility helpers" do
    srand(12_345)
    context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    noise = Deftones::Noise.new(type: :white, playback_rate: 0.25, context: context)
    noise.playbackRate = 0.25
    noise >> context.output
    noise.start(0.0)

    rendered = context.render.mono

    expect(noise.playbackRate).to eq(0.25)
    expect(rendered[0, 4].uniq.length).to eq(1)
    expect(rendered[4, 4].uniq.length).to eq(1)
    expect(rendered[0]).not_to eq(rendered[4])
  end

  it "applies fadeIn and fadeOut to noise sources" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    noise = Deftones::Noise.new(type: :white, fade_in: 0.02, fade_out: 0.02, context: context)
    allow(noise).to receive(:next_noise_sample).and_return(1.0)
    noise.instance_variable_set(:@held_sample, 1.0)
    noise >> context.output

    noise.start(0.0)
    noise.stop(0.05)
    rendered = context.render.mono

    expect(noise.fadeIn).to eq(0.02)
    expect(noise.fadeOut).to eq(0.02)
    expect(rendered.zip([0.0, 0.5, 1.0, 1.0, 0.5]).all? do |actual, expected|
      (actual - expected).abs <= 0.001
    end).to eq(true)
  end

  it "exposes detune and oscillator property compatibility helpers" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 5, detune: 1_200.0, context: context)
    oscillator >> context.output
    oscillator.start(0.0)

    rendered = context.render.mono
    fm = Deftones::FMOscillator.new(modulation_index: 3.0, detune: 700.0, context: context)
    pwm = Deftones::PWMOscillator.new(modulation_frequency: 2.0, modulation_depth: 0.4, detune: 300.0, context: context)

    expect(rendered[1]).to be_within(0.001).of(0.5878)
    expect(oscillator.detune.value).to eq(1_200.0)
    expect(fm.modulationIndex).to eq(fm.modulation_index)
    expect(fm.detune.value).to eq(700.0)
    expect(pwm.modulationFrequency).to eq(pwm.modulation_frequency)
    expect(pwm.modulationDepth).to eq(pwm.modulation_depth)
    expect(pwm.detune.value).to eq(300.0)
  end

  it "preserves state and current controls when OmniOscillator changes type" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    stopped_at = nil
    omni = Deftones::OmniOscillator.new(type: :sine, frequency: 5, context: context)
    omni.onstop = ->(time) { stopped_at = time }

    omni.start(0.0)
    omni.frequency.value = 10.0
    omni.volume.value = -6.0
    omni.type = :pulse
    omni.stop(0.02)
    omni >> context.output
    rendered = context.render

    expect(omni.source).to be_a(Deftones::PulseOscillator)
    expect(omni.state(0.0)).to eq(:started)
    expect(omni.state(0.03)).to eq(:stopped)
    expect(omni.frequency.value).to eq(10.0)
    expect(omni.volume.value).to eq(-6.0)
    expect(rendered.peak).to be > 0.4
    expect(stopped_at).to be_within(0.01).of(0.02)
  end

  it "keeps grain timing separate from grain pitch" do
    base_buffer = Deftones::Buffer.from_mono((0...10).map(&:to_f), sample_rate: 100)

    stretched_context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    stretched = Deftones::GrainPlayer.new(
      buffer: base_buffer,
      playback_rate: 0.5,
      grain_size: 0.04,
      overlap: 0.0,
      jitter: 0.0,
      context: stretched_context
    )
    stretched.start(0.0)
    stretched >> stretched_context.output

    pitched_context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    pitched = Deftones::GrainPlayer.new(
      buffer: base_buffer,
      playback_rate: 0.5,
      detune: 1_200.0,
      grain_size: 0.04,
      overlap: 0.0,
      jitter: 0.0,
      context: pitched_context
    )
    pitched.start(0.0)
    pitched >> pitched_context.output

    stretched_output = stretched_context.render.mono.first(8)
    pitched_output = pitched_context.render.mono.first(8)

    expect(stretched_output).to eq([0.0, 1.0, 2.0, 3.0, 2.0, 3.0, 4.0, 5.0])
    expect(pitched_output).to eq([0.0, 2.0, 4.0, 6.0, 2.0, 4.0, 6.0, 8.0])
  end

  it "exposes compatibility Player helpers" do
    context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    buffer = Deftones::Buffer.from_mono((0...8).map(&:to_f), sample_rate: 100)
    stopped_at = nil
    player = Deftones::Player.new(
      buffer: buffer,
      fade_in: 0.01,
      autostart: true,
      onstop: ->(time) { stopped_at = time },
      context: context
    )
    player >> context.output

    expect(player.loaded).to eq(true)
    expect(player.autostart).to eq(true)
    expect(player.state(0.0)).to eq(:started)
    expect(player.seek).to eq(0.0)
    expect(player.sourceType).to eq("player")

    player.playbackRate = 1.0
    player.loopStart = 0.01
    player.loopEnd = 0.03
    player.start(0.0, 0.01, 0.03)
    rendered = context.render

    expect(player.state(0.04)).to eq(:stopped)
    expect(rendered.mono.first(4)).to eq([0.0, 2.0, 3.0, 0.0])
    expect(stopped_at).to be_within(0.01).of(0.03)

    player.dispose
    expect(player.loaded?).to eq(false)
  end

  it "exposes compatibility Players collection helpers" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    buffer = Deftones::Buffer.from_mono([1.0, 0.0, 1.0, 0.0, 1.0], sample_rate: 100)
    players = Deftones::Players.new({ kick: buffer }, context: context)
    snare = players.add(:snare, buffer)

    expect(players.get(:kick)).to be_a(Deftones::Player)
    expect(players.player(:kick)).to eq(players.get(:kick))
    expect(players.has?(:snare)).to eq(true)
    expect(players.loaded).to eq(true)
    expect(players.names).to eq(%i[kick snare])
    expect(players.mute?).to eq(false)
    expect(players.volume.value).to eq(0.0)

    players.volume.value = -6.0
    expect(players.get(:kick).volume.value).to eq(-6.0)
    expect(players.get(:snare).volume.value).to eq(-6.0)

    players.mute = true
    expect(players.get(:kick).mute?).to eq(true)
    expect(players.get(:snare).mute?).to eq(true)
    players.mute = false
    players.volume.value = 0.0

    players.each { |player| player >> context.output }
    players.get(:kick).start(0.0)
    snare.start(0.0)
    rendered = context.render

    expect(rendered.peak).to eq(2.0)
    expect(players.state(:kick, time: 0.0)).to eq(:started)
    expect(players.state(time: 0.02)).to eq({ kick: :started, snare: :started })
    players.stopAll(0.01)
    expect(players.get(:kick).state(0.02)).to eq(:stopped)

    players.dispose
    expect(players.loaded?).to eq(false)
  end
end
