# frozen_string_literal: true

RSpec.describe Deftones::Core::Signal do
  let(:context) { Deftones::OfflineContext.new(duration: 0.1, sample_rate: 100, buffer_size: 10) }

  it "supports scheduled set operations" do
    signal = described_class.new(value: 0.0, context: context)
    signal.set_value_at_time(1.0, 0.03)

    values = signal.process(6, 0)

    expect(values[0]).to eq(0.0)
    expect(values[2]).to eq(0.0)
    expect(values[3]).to eq(1.0)
  end

  it "supports linear automation ramps" do
    signal = described_class.new(value: 0.0, context: context)
    signal.linear_ramp_to(1.0, 0.05)

    values = signal.process(6, 0)

    expect(values[0]).to eq(0.0)
    expect(values[2]).to be_within(0.01).of(0.4)
    expect(values[5]).to eq(1.0)
  end

  it "converts note names when used as a frequency signal" do
    signal = described_class.new(value: "A4", units: :frequency, context: context)

    expect(signal.value).to eq(440.0)
  end
end
