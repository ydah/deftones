# frozen_string_literal: true

RSpec.describe Deftones::Frequency do
  it "wraps frequency values with compatibility conversions" do
    frequency = described_class.new("A4")

    expect(frequency.to_hz).to eq(440.0)
    expect(frequency.to_seconds).to be_within(0.000001).of(1.0 / 440.0)
    expect(frequency.to_midi).to eq(69)
    expect(frequency.value_of).to eq(440.0)
  end
end
