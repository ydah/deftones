# frozen_string_literal: true

RSpec.describe "Instrument voices" do
  it "renders the extended synth classes" do
    context = Deftones::OfflineContext.new(duration: 0.5)

    Deftones::MonoSynth.new(context: context).to_output.play("C3", duration: 0.1, at: 0.0)
    Deftones::FMSynth.new(context: context).to_output.play("E3", duration: 0.1, at: 0.05)
    Deftones::AMSynth.new(context: context).to_output.play("G3", duration: 0.1, at: 0.1)
    Deftones::DuoSynth.new(context: context).to_output.play("B3", duration: 0.12, at: 0.15)
    Deftones::NoiseSynth.new(context: context).to_output.play(duration: 0.05, at: 0.2)
    Deftones::PluckSynth.new(context: context).to_output.play("C4", duration: 0.1, at: 0.24)
    Deftones::MembraneSynth.new(context: context).to_output.play("A2", duration: 0.08, at: 0.3)
    Deftones::MetalSynth.new(context: context).to_output.play("C5", duration: 0.05, at: 0.36)

    buffer = context.render

    expect(buffer.peak).to be > 0.1
    expect(buffer.rms).to be > 0.01
  end

  it "exposes compatibility helpers on instruments" do
    context = Deftones::OfflineContext.new(duration: 0.1, sample_rate: 100, buffer_size: 10)
    synth = Deftones::Synth.new(context: context)
    synth.volume.value = -6.0
    synth >> context.output

    synth.triggerAttack("A4", 0.0, 0.8)
    synth.triggerRelease(0.03)
    rendered = context.render

    expect(synth.get(:volume, :mute)).to eq({ volume: synth.volume, mute: false })
    expect(context.output.gain.value).to eq(1.0)
    expect(synth.output.gain.value).to be_within(0.001).of(Deftones.db_to_gain(-6.0))
    expect(rendered.peak).to be > 0.01

    synth.mute = true
    expect(synth.output.gain.value).to eq(0.0)
  end

  it "releases all poly synth voices through compatibility helpers" do
    context = Deftones::OfflineContext.new(duration: 0.12, sample_rate: 100, buffer_size: 12)
    synth = Deftones::PolySynth.new(context: context, release: 0.02)
    synth >> context.output

    synth.triggerAttack("C4", 0.0, 0.8)
    synth.triggerAttack("E4", 0.0, 0.8)
    synth.releaseAll(0.04)
    rendered = context.render

    expect(synth.max_polyphony).to eq(8)
    expect(synth.loaded).to eq(true)
    expect(rendered.mono.last(4).all? { |sample| sample.abs < 1.0e-6 }).to eq(true)
  end

  it "supports PolySynth voice stealing and retrigger policies" do
    quiet = Deftones::PolySynth.new(voices: 2, voice_stealing: :quietest, context: Deftones::OfflineContext.new(duration: 0.01))

    quiet.triggerAttack("C4", 0.0, 0.1)
    quiet.triggerAttack("E4", 0.0, 0.9)
    quiet.triggerAttack("G4", 0.0, 0.5)

    expect(quiet.active_notes).to contain_exactly("E4", "G4")
    expect(quiet.active_voice_count).to eq(2)

    ignored = Deftones::PolySynth.new(voices: 1, retrigger: :ignore, context: Deftones::OfflineContext.new(duration: 0.01))
    ignored.triggerAttack("C4", 0.0, 0.1)
    ignored.triggerAttack("C4", 0.01, 0.9)

    expect(ignored.active_voice_count).to eq(1)
    expect(ignored.retrigger).to eq(:ignore)
    expect { Deftones::PolySynth.new(voice_stealing: :unknown) }.to raise_error(ArgumentError, /voice stealing/)
    expect { Deftones::PolySynth.new(retrigger: :unknown) }.to raise_error(ArgumentError, /retrigger/)
  end

  it "manages sampler buffers through compatibility helpers" do
    context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    buffer = Deftones::Buffer.from_mono([1.0, 0.5, 0.0, 0.0], sample_rate: 100)
    sampler = Deftones::Sampler.new(samples: { C4: buffer }, context: context)
    sampler.add("E4", buffer)
    sampler >> context.output

    sampler.triggerAttackRelease("E4", 0.03, 0.0, 0.8)
    rendered = context.render

    expect(sampler.get("C4")).to eq(buffer)
    expect(sampler.has?("E4")).to eq(true)
    expect(sampler.loaded?).to eq(true)
    expect(rendered.peak).to be > 0.1

    sampler.releaseAll(0.01)
    sampler.dispose
    expect(sampler.voices).to eq([])
  end

  it "stops and disposes the oldest sampler voice when stealing" do
    context = Deftones::OfflineContext.new(duration: 0.04, sample_rate: 100, buffer_size: 4)
    buffer = Deftones::Buffer.from_mono([1.0, 0.5, 0.0, 0.0], sample_rate: 100)
    sampler = Deftones::Sampler.new(samples: { C4: buffer }, max_voices: 1, context: context)

    sampler.trigger_attack("C4", 0.0, 1.0)
    stolen_player = sampler.voices.first[:player]
    sampler.trigger_attack("E4", 0.01, 1.0)

    expect(stolen_player.disposed?).to eq(true)
    expect(sampler.voices.length).to eq(1)
  end

  it "supports sampler release fades, one-shot playback, and choke groups" do
    context = Deftones::OfflineContext.new(duration: 0.08, sample_rate: 100, buffer_size: 8)
    buffer = Deftones::Buffer.from_mono(Array.new(8, 1.0), sample_rate: 100)
    sampler = Deftones::Sampler.new(
      samples: { C4: buffer },
      release: 0.02,
      one_shot: true,
      choke_group: :hat,
      context: context
    )

    sampler.trigger_attack("C4", 0.0, 1.0)
    first_player = sampler.voices.first[:player]
    sampler.trigger_release("C4", 0.01)
    sampler.trigger_attack("C4", 0.02, 1.0)

    expect(sampler.oneShot).to eq(true)
    expect(sampler.release).to eq(0.02)
    expect(first_player.disposed?).to eq(true)
    expect(sampler.voices.length).to eq(1)
    expect(sampler.voices.first[:player].fade_out).to eq(0.02)
  end

  it "raises early when a sampler has no samples" do
    sampler = Deftones::Sampler.new(samples: {}, context: Deftones::OfflineContext.new(duration: 0.01))

    expect { sampler.trigger_attack("C4") }.to raise_error(ArgumentError, /at least one sample/)
  end
end
