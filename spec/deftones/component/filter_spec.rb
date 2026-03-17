# frozen_string_literal: true

RSpec.describe Deftones::Component::Filter do
  it "processes audio through a lowpass filter" do
    context = Deftones::OfflineContext.new(duration: 0.1)
    oscillator = Deftones::Oscillator.new(type: :sawtooth, frequency: 880, context: context).start(0.0)
    filter = described_class.new(type: :lowpass, frequency: 400, q: 0.7, context: context)

    oscillator >> filter >> context.output
    filtered = context.render

    expect(filtered.peak).to be > 0.01
    expect(filtered.rms).to be > 0.01
  end

  it "supports detune through the BiquadFilter compatibility surface" do
    context = Deftones::OfflineContext.new(duration: 0.1, sample_rate: 8_000, buffer_size: 128)
    oscillator = Deftones::Oscillator.new(type: :sawtooth, frequency: 1_200, context: context).start(0.0)
    base = Deftones::BiquadFilter.new(type: :lowpass, frequency: 300, detune: 0.0, context: context)
    detuned = Deftones::BiquadFilter.new(type: :lowpass, frequency: 300, detune: 1_200.0, context: context)

    oscillator >> base
    base_peak = Deftones::Buffer.from_mono(base.render(800, 0), sample_rate: 8_000).peak

    oscillator.disconnect(base)
    oscillator >> detuned
    detuned_peak = Deftones::Buffer.from_mono(detuned.render(800, 0), sample_rate: 8_000).peak

    expect(detuned_peak).to be > base_peak
  end
end
