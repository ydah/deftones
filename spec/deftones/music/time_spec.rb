# frozen_string_literal: true

RSpec.describe Deftones::Music::Time do
  it "parses note values using the transport tempo" do
    Deftones.transport.bpm = 120

    expect(described_class.parse("4n")).to eq(0.5)
    expect(described_class.parse(:eighth)).to eq(0.25)
    expect(described_class.parse("8t")).to be_within(0.0001).of(1.0 / 6.0)
    expect(described_class.parse("4n.")).to eq(0.75)
  end

  it "parses transport and measure notation" do
    Deftones.transport.bpm = 120
    Deftones.transport.time_signature = [4, 4]

    expect(described_class.parse("1:2:0")).to eq(3.0)
    expect(described_class.parse("2m")).to eq(4.0)
  end

  it "treats hz notation as a period in seconds" do
    expect(described_class.parse("500hz")).to eq(0.002)
  end

  it "evaluates arithmetic expressions" do
    expect(described_class.parse("4n + 8n")).to eq(0.75)
    expect(described_class.parse("(4n + 8n) / 2")).to eq(0.375)
  end

  it "raises for unknown values" do
    expect { described_class.parse("banana") }.to raise_error(ArgumentError)
  end
end
