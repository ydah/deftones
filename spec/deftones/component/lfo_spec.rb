# frozen_string_literal: true

RSpec.describe Deftones::Component::LFO do
  it "produces a modulation range between min and max" do
    context = Deftones::OfflineContext.new(duration: 1.0, sample_rate: 100, buffer_size: 10)
    lfo = described_class.new(frequency: 1.0, min: -2.0, max: 2.0, context: context)
    lfo.start(0.0)

    values = lfo.values(100)

    expect(values.min).to be <= -1.9
    expect(values.max).to be >= 1.9
  end

  it "scales the modulation depth through amplitude" do
    context = Deftones::OfflineContext.new(duration: 1.0, sample_rate: 100, buffer_size: 10)
    lfo = described_class.new(frequency: 1.0, min: -10.0, max: 10.0, amplitude: 0.5, context: context)
    lfo.start(0.0)

    values = lfo.values(100)

    expect(values.min).to be <= -4.9
    expect(values.max).to be >= 4.9
    expect(values.min).to be >= -5.1
    expect(values.max).to be <= 5.1
  end

  it "converts the range through the configured units" do
    context = Deftones::OfflineContext.new(duration: 0.1, sample_rate: 100, buffer_size: 10)
    lfo = described_class.new(min: "A4", max: "A5", units: :frequency, context: context)

    expect(lfo.min).to eq(440.0)
    expect(lfo.max).to eq(880.0)
    expect(lfo.getDefaults[:amplitude]).to eq(1.0)
  end

  it "behaves as a source node without inputs" do
    lfo = described_class.new(context: Deftones::OfflineContext.new(duration: 0.1))

    expect(lfo.state(0.0)).to eq(:stopped)
    expect(lfo.input).to be_nil
    expect(lfo.numberOfInputs).to eq(0)
  end
end
