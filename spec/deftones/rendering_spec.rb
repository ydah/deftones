# frozen_string_literal: true

RSpec.describe "Offline rendering" do
  it "renders a synth voice with an amplitude envelope" do
    context = Deftones::OfflineContext.new(duration: 0.25)
    synth = Deftones::Synth.new(
      context: context,
      type: :triangle,
      attack: 0.01,
      decay: 0.02,
      sustain: 0.4,
      release: 0.03
    ).to_output

    synth.play("A4", duration: 0.05)
    buffer = context.render

    expect(buffer.peak).to be_between(0.1, 1.0)
    expect(buffer).to have_frequency(440, tolerance: 20)
    expect(buffer.mono.first(100).max).to be > 0.0
    expect(buffer.mono.last(1_000).map(&:abs).max).to be < 0.05
  end

  it "mixes multiple notes through PolySynth" do
    context = Deftones::OfflineContext.new(duration: 0.3)
    synth = Deftones::PolySynth.new(Deftones::Synth, voices: 3, context: context).to_output

    synth.play(%w[C4 E4 G4], duration: 0.08)
    buffer = context.render

    expect(buffer.peak).to be > 0.1
    expect(buffer.rms).to be > 0.01
  end

  it "supports node chaining with gain" do
    context = Deftones::OfflineContext.new(duration: 0.1)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context).start(0.0)
    gain = Deftones::Gain.new(gain: 0.25, context: context)

    oscillator >> gain >> context.output
    buffer = context.render

    expect(buffer.peak).to be_between(0.05, 0.3)
  end
end
