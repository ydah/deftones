# frozen_string_literal: true

require "deftones"

Deftones.render_to_file("poly_chord.wav", duration: 0.75) do |context|
  synth = Deftones::PolySynth.new(
    Deftones::Synth,
    voices: 4,
    context: context
  ).to_output

  synth.play(%w[C4 E4 G4 B4], duration: 0.2, at: 0.0)
  synth.play(%w[A3 C4 E4 G4], duration: 0.2, at: 0.25)
end
