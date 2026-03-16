# frozen_string_literal: true

RSpec.describe "Core compatibility helpers" do
  it "emits events through Emitter" do
    emitter = Deftones::Emitter.new
    values = []

    emitter.on(:tick) { |value| values << [:on, value] }
    emitter.once(:tick) { |value| values << [:once, value] }

    emitter.emit(:tick, 1)
    emitter.emit(:tick, 2)

    expect(values).to eq([[:on, 1], [:once, 1], [:on, 2]])
    expect(emitter.listeners(:tick).length).to eq(1)
  end

  it "tracks tick positions through Clock" do
    context = Deftones::Context.new(autostart: false)
    clock = Deftones::Clock.new(frequency: 2.0, context: context)

    clock.start(0.0, offset: 1.0)

    expect(clock.ticks(0.5)).to eq(2.0)
    expect(clock.seconds(0.5)).to eq(1.0)
    expect(clock.getTicksAtTime(1.0)).to eq(3.0)
    expect(clock.nextTickTime(0.6)).to be_within(0.001).of(1.0)
  end

  it "delays a signal through Delay" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5, channels: 1)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.new([1.0, 0.0, 0.0, 0.0, 0.0], channels: 1, sample_rate: 100),
      context: context
    ).start(0.0)
    delay = Deftones::Delay.new(delay_time: 0.01, max_delay: 0.05, context: context)

    source >> delay >> context.output
    rendered = context.render

    expect(rendered.samples[0]).to eq(0.0)
    expect(rendered.samples[1]).to eq(1.0)
  end
end
