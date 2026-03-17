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

  it "supports value curves and target ramps" do
    signal = described_class.new(value: 0.0, context: context)
    signal.set_value_curve_at_time([0.0, 1.0, 0.0], 0.0, 0.04)
    signal.set_target_at_time(1.0, 0.05, 0.01)

    expect(signal.getValueAtTime(0.02)).to be_within(0.001).of(1.0)
    expect(signal.getValueAtTime(0.04)).to be_within(0.001).of(0.0)
    expect(signal.getValueAtTime(0.06)).to be_within(0.02).of(0.632)
  end

  it "supports cancellation and hold helpers" do
    signal = described_class.new(value: 0.0, context: context)
    signal.linearRampToValueAtTime(1.0, 0.05)
    signal.cancelAndHoldAtTime(0.02)

    held = signal.get_value_at_time(0.02)

    expect(held).to be_within(0.001).of(0.4)
    expect(signal.get_value_at_time(0.05)).to be_within(0.001).of(held)

    signal.targetRampTo(1.0, 0.02, 0.03)
    expect(signal.get_value_at_time(0.05)).to be > held

    signal.dispose
    expect(signal.disposed?).to eq(true)
  end

  it "chains scheduled ramps from the previous automation boundary" do
    signal = described_class.new(value: 0.0, context: context)
    signal.linearRampToValueAtTime(1.0, 0.05)
    signal.linearRampToValueAtTime(0.0, 0.1)

    expect(signal.get_value_at_time(0.025)).to be_within(0.001).of(0.5)
    expect(signal.get_value_at_time(0.05)).to be_within(0.001).of(1.0)
    expect(signal.get_value_at_time(0.075)).to be_within(0.001).of(0.5)
    expect(signal.get_value_at_time(0.1)).to be_within(0.001).of(0.0)
  end

  it "lets later set events interrupt an in-flight ramp" do
    signal = described_class.new(value: 0.0, context: context)
    signal.linearRampToValueAtTime(1.0, 0.05)
    signal.setValueAtTime(0.25, 0.03)

    expect(signal.get_value_at_time(0.02)).to be_within(0.001).of(0.4)
    expect(signal.get_value_at_time(0.03)).to be_within(0.001).of(0.25)
    expect(signal.get_value_at_time(0.04)).to be_within(0.001).of(0.25)
  end

  it "exposes shared signal and param helpers" do
    signal = described_class.new(value: "A4", units: :frequency, context: context)
    param = Deftones::Param.new(value: 0.0, context: context)

    expect(signal.defaultValue).to eq(440.0)
    expect(signal.getDefaults).to eq({ value: 440.0, units: :frequency })
    expect(signal.now).to eq(0.0)
    expect(signal.immediate).to eq(0.0)
    expect(signal.toSeconds("4n")).to eq(0.5)
    expect(signal.toTicks("4n")).to eq(192)
    expect(signal.toFrequency("A4")).to eq(440.0)
    expect(signal.toString).to eq("Signal")
    expect(signal.name).to eq("Signal")
    expect(signal.overridden?).to eq(false)

    signal.connect(param)
    expect(param.value).to eq(440.0)
    expect(signal.get(:units, :value)).to eq({ units: :frequency, value: 440.0 })

    signal.convert = false
    signal.apply(220)
    expect(signal.value).to eq(220.0)

    param.setParam(signal)
    param.lfo = Deftones::LFO.new(frequency: 2.0, context: context)
    expect(param.lfo).to be_a(Deftones::LFO)
  end
end
