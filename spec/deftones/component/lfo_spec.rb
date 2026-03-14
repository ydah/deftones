# frozen_string_literal: true

RSpec.describe Deftones::Component::LFO do
  it "produces a modulation range between min and max" do
    context = Deftones::OfflineContext.new(duration: 1.0, sample_rate: 100, buffer_size: 10)
    lfo = described_class.new(frequency: 1.0, min: -2.0, max: 2.0, context: context)

    values = lfo.values(100)

    expect(values.min).to be <= -1.9
    expect(values.max).to be >= 1.9
  end
end
