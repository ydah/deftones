# frozen_string_literal: true

RSpec.describe "Transport unit wrappers" do
  let(:transport) { Deftones.transport }

  before do
    transport.bpm = 120
    transport.time_signature = [4, 4]
    transport.ppq = 192
    transport.position = 0
  end

  it "parses ticks notation through Time" do
    expect(Deftones::Time.parse("192i")).to eq(0.5)
    expect(Deftones::Time.parse("96i + 8n")).to eq(0.5)
  end

  it "converts transport time and ticks wrappers" do
    transport_time = Deftones::TransportTime.new("1:0:0", transport: transport)
    ticks = Deftones::Ticks.new("4n", transport: transport)

    expect(transport_time.to_seconds).to eq(2.0)
    expect(transport_time.to_ticks).to eq(768)
    expect(ticks.to_i).to eq(192)
    expect(ticks.to_seconds).to eq(0.5)
    expect(ticks.to_bars_beats_sixteenths).to eq("0:1:0")
  end

  it "tracks ticks on the transport" do
    transport.position = Deftones::TransportTime.new("0:2:0", transport: transport)
    expect(transport.ticks).to eq(384)

    transport.ticks = "96i"
    expect(transport.position).to eq("0:0:2")

    transport.set_loop_points("4n", "1m")
    expect(transport.loop_start).to eq(0.5)
    expect(transport.loop_end).to eq(2.0)
  end
end
