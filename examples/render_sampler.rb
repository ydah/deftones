# frozen_string_literal: true

require "deftones"

sample_rate = 44_100
transient = Array.new((sample_rate * 0.25).to_i) do |index|
  time = index.to_f / sample_rate
  envelope = Math.exp(-12 * time)
  Math.sin(2.0 * Math::PI * 110 * time) * envelope
end
sample = Deftones::Buffer.from_mono(transient, sample_rate: sample_rate)

Deftones.render_to_file("render_sampler.wav", duration: 1.0) do |context|
  sampler = Deftones::Sampler.new(samples: { "C4" => sample }, context: context).to_output
  sampler.play(%w[C4 E4 G4], duration: 0.2, at: 0.0)
end
