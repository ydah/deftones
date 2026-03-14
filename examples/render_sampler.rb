# frozen_string_literal: true

require "deftones"

sample = Deftones::Buffer.load("kick.wav")

Deftones.render_to_file("render_sampler.wav", duration: 1.0) do |context|
  sampler = Deftones::Sampler.new(samples: { "C4" => sample }, context: context).to_output
  sampler.play(%w[C4 E4 G4], duration: 0.2, at: 0.0)
end
