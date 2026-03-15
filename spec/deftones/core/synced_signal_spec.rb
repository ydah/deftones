# frozen_string_literal: true

RSpec.describe Deftones::Core::SyncedSignal do
  let(:context) { Deftones::OfflineContext.new(duration: 1.0, sample_rate: 4, buffer_size: 4) }
  let(:transport) { Deftones.transport }

  before do
    Deftones.reset!
    transport.bpm = 120
    transport.time_signature = [4, 4]
    transport.position = 0
  end

  it "schedules values against the transport timeline" do
    signal = described_class.new(value: 0.0, context: context, transport: transport)
    signal.set_value_at_time(1.0, "4n")

    expect(signal.process(4, 0)).to eq([0.0, 0.0, 1.0, 1.0])
  end

  it "starts ramps from the current transport position" do
    transport.position = "0:1:0"
    signal = described_class.new(value: 0.0, context: context, transport: transport)
    signal.linear_ramp_to(1.0, "4n")

    expect(signal.process(4, 0)).to eq([0.0, 0.5, 1.0, 1.0])
  end

  it "can be unsynced back to context time semantics" do
    transport.position = "1:0:0"
    signal = described_class.new(value: 0.0, context: context, transport: transport).unsync
    signal.set_value_at_time(1.0, 0.25)

    expect(signal.synced?).to eq(false)
    expect(signal.process(4, 0)).to eq([0.0, 1.0, 1.0, 1.0])
  end
end
