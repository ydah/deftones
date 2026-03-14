# frozen_string_literal: true

RSpec.describe Deftones::Component::Filter do
  it "processes audio through a lowpass filter" do
    context = Deftones::OfflineContext.new(duration: 0.1)
    oscillator = Deftones::Oscillator.new(type: :sawtooth, frequency: 880, context: context)
    filter = described_class.new(type: :lowpass, frequency: 400, q: 0.7, context: context)

    oscillator >> filter >> context.output
    filtered = context.render

    expect(filtered.peak).to be > 0.01
    expect(filtered.rms).to be > 0.01
  end
end
