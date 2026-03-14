# frozen_string_literal: true

require "deftones"

context = Deftones::OfflineContext.new(duration: 1.0)
synth = Deftones::MonoSynth.new(context: context, type: :sawtooth).to_output

Deftones.transport.bpm = 120
Deftones::Sequence.new(notes: ["C4", "E4", "G4", "B4"], subdivision: "8n", loop: false) do |time, note|
  synth.play(note, duration: "16n", at: time)
end.start(0)

context.render.save("render_sequence.wav")
