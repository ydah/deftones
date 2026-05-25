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
    expect(described_class.parse("-4n + 2n")).to eq(0.5)
  end

  it "raises for unknown values" do
    expect { described_class.parse("banana") }.to raise_error(Deftones::InvalidTimeError)
    expect { described_class.parse("4n banana") }.to raise_error(Deftones::InvalidTimeError)
    expect { described_class.parse("()") }.to raise_error(Deftones::InvalidTimeError)
    expect { described_class.parse("(4n + 8n") }.to raise_error(Deftones::InvalidTimeError)
  end

  it "rejects malformed expressions without partially parsing them" do
    ["4n +", "4n ** 2", "4n / / 8n", "(( ))", "4n + $", "1::2"].each do |value|
      expect { described_class.parse(value) }.to raise_error(Deftones::InvalidTimeError)
    end
  end

  it "wraps time values with compatibility conversions" do
    transport = Deftones.transport
    transport.bpm = 120
    transport.time_signature = [4, 4]
    value = described_class.new("1:0:0", transport: transport)

    expect(value.to_seconds).to eq(2.0)
    expect(value.to_ticks).to eq(768.0)
    expect(value.to_bars_beats_sixteenths).to eq("1:0:0")
    expect(value.to_frequency).to eq(0.5)
    expect(value.to_milliseconds).to eq(2000.0)
    expect(value.to_samples(100)).to eq(200)
    expect(value.to_notation).to eq("1m")
    expect(value.quantize("4n")).to eq(2.0)
    expect(value.toString).to eq("1:0:0")
    expect(value.dispose.disposed?).to eq(true)
    expect(value.value_of).to eq(2.0)
  end
end
