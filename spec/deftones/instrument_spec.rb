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
end
