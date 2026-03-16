# frozen_string_literal: true

RSpec.describe Deftones::Frequency do
  it "wraps frequency values with compatibility conversions" do
    frequency = described_class.new("A4")

    expect(frequency.to_hz).to eq(440.0)
    expect(frequency.to_frequency).to eq(440.0)
    expect(frequency.to_seconds).to be_within(0.000001).of(1.0 / 440.0)
    expect(frequency.to_midi).to eq(69)
    expect(frequency.to_note).to eq("A4")
    expect(frequency.to_ticks).to eq(1)
    expect(frequency.to_milliseconds).to be_within(0.001).of(2.273)
    expect(frequency.to_samples(44_100)).to eq(100)
    expect(frequency.to_notation).to eq("128n")
    expect(frequency.transpose(12).to_note).to eq("A5")
    expect(frequency.harmonize([0, 12]).map(&:to_note)).to eq(%w[A4 A5])
    expect(frequency.quantize(0.001)).to eq(500.0)
    expect(described_class.mtof(69)).to eq(440.0)
    expect(described_class.ftom("440hz")).to eq(69)
    expect(frequency.toString).to eq("A4")
    expect(frequency.dispose.disposed?).to eq(true)
    expect(frequency.value_of).to eq(440.0)
  end
end
