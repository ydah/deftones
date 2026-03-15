# frozen_string_literal: true

RSpec.describe "Tone.js-style signal operators" do
  let(:context) { Deftones::OfflineContext.new(duration: 0.1, sample_rate: 100, buffer_size: 10) }

  it "supports additive, multiplicative, and subtractive chaining" do
    signal = Deftones::Signal.new(value: 0.25, context: context)

    derived = signal.add(0.25).multiply(4.0).subtract(1.0)

    expect(derived.process(1, 0).first).to be_within(0.001).of(1.0)
  end

  it "supports unary transforms and passthrough conversions" do
    signal = Deftones::Signal.new(value: -0.5, context: context)

    expect(signal.negate.value).to eq(0.5)
    expect(signal.abs.value).to eq(0.5)
    expect(signal.to_gain.to_audio.value).to eq(-0.5)
  end

  it "supports comparison operators" do
    signal = Deftones::Signal.new(value: 0.25, context: context)
    signal.set_value_at_time(0.75, 0.02)

    expect(signal.greater_than(0.5).process(4, 0)).to eq([0.0, 0.0, 1.0, 1.0])
    expect(signal.negate.greater_than_zero.process(2, 0)).to eq([0.0, 0.0])
  end

  it "supports scaling and exponential scaling" do
    signal = Deftones::Signal.new(value: 0.5, context: context)

    expect(signal.scale(10.0, 20.0).value).to be_within(0.001).of(15.0)
    expect(signal.scale_exp(1.0, 9.0, exponent: 2.0).value).to be_within(0.001).of(3.0)
    expect(signal.pow(2.0).value).to be_within(0.001).of(0.25)
  end

  it "supports normalization, modulo, and equal-power shaping" do
    signal = Deftones::Signal.new(value: 0.5, context: context)

    expect(signal.normalize(0.0, 1.0).value).to be_within(0.001).of(0.5)
    expect(signal.add(1.0).modulo(0.75).value).to be_within(0.001).of(0.0)
    expect(signal.equal_power_gain.value).to be_within(0.001).of(Math.sqrt(0.5))
  end

  it "supports waveshaping with a curve or a mapping block" do
    signal = Deftones::Signal.new(value: 0.25, context: context)

    expect(signal.wave_shaper([-1.0, 0.0, 1.0]).value).to be_within(0.001).of(0.25)
    expect(signal.wave_shaper { |value, _time| value * value }.value).to be_within(0.001).of(0.0625)
  end

  it "exposes compatibility aliases" do
    signal = Deftones::Signal.new(value: 0.25, context: context)

    expect(Deftones::Add.new(input: signal, addend: 0.75).value).to eq(1.0)
    expect(Deftones::Zero.new(context: context).value).to eq(0.0)
    expect(Deftones::GreaterThanZero.new(input: signal, context: context).value).to eq(1.0)
    expect(Deftones::Normalize.new(input: signal, min: 0.0, max: 1.0).value).to eq(0.25)
    expect(Deftones::WaveShaper.new(input: signal, curve: [-1.0, 0.0, 1.0]).value).to eq(0.25)
  end
end
