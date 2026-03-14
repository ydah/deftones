# frozen_string_literal: true

require "deftones"

Deftones.render_to_file("render_synth.wav", duration: 1.0) do |context|
  synth = Deftones::Synth.new(
    context: context,
    type: :sawtooth,
    attack: 0.01,
    decay: 0.08,
    sustain: 0.35,
    release: 0.2
  ).to_output

  synth.play("C4", duration: "8n", at: 0.0)
  synth.play("E4", duration: "8n", at: "4n")
  synth.play("G4", duration: "8n", at: "2n")
end
