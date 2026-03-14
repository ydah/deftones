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
end
