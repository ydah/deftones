# frozen_string_literal: true

require "digest"
require "tmpdir"

RSpec.describe "Offline rendering" do
  it "renders a synth voice with an amplitude envelope" do
    context = Deftones::OfflineContext.new(duration: 0.25)
    synth = Deftones::Synth.new(
      context: context,
      type: :triangle,
      attack: 0.01,
      decay: 0.02,
      sustain: 0.4,
      release: 0.03
    ).to_output

    synth.play("A4", duration: 0.05)
    buffer = context.render

    expect(buffer.peak).to be_between(0.1, 1.0)
    expect(buffer).to have_frequency(440, tolerance: 20)
    expect(buffer.mono.first(100).max).to be > 0.0
    expect(buffer.mono.last(1_000).map(&:abs).max).to be < 0.05
  end

  it "mixes multiple notes through PolySynth" do
    context = Deftones::OfflineContext.new(duration: 0.3)
    synth = Deftones::PolySynth.new(Deftones::Synth, voices: 3, context: context).to_output

    synth.play(%w[C4 E4 G4], duration: 0.08)
    buffer = context.render

    expect(buffer.peak).to be > 0.1
    expect(buffer.rms).to be > 0.01
  end

  it "supports node chaining with gain" do
    context = Deftones::OfflineContext.new(duration: 0.1)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context).start(0.0)
    gain = Deftones::Gain.new(gain: 0.25, context: context)

    oscillator >> gain >> context.output
    buffer = context.render

    expect(buffer.peak).to be_between(0.05, 0.3)
  end

  it "keeps deterministic audio snapshot hashes stable" do
    first = Deftones.render(duration: 0.03, sample_rate: 100, buffer_size: 3, channels: 1, seed: 42) do |context|
      Deftones::Oscillator.new(type: :sine, frequency: 5, context: context).start(0.0) >> context.output
    end
    second = Deftones.render(duration: 0.03, sample_rate: 100, buffer_size: 3, channels: 1, seed: 42) do |context|
      Deftones::Oscillator.new(type: :sine, frequency: 5, context: context).start(0.0) >> context.output
    end

    expect(first.samples).to eq(second.samples)
    expect(Digest::SHA256.hexdigest(first.samples.pack("E*"))).to eq(
      "6a941cb8bddbed528f6b668354391b58ebca6c592d4e246ba48d8c044bb8a0fc"
    )
  end

  it "renders across common sample rates and channel counts" do
    [8_000, 44_100, 48_000, 96_000].each do |sample_rate|
      context = Deftones::OfflineContext.new(duration: 0.001, sample_rate: sample_rate, buffer_size: 16, channels: 1)
      Deftones::Oscillator.new(type: :sine, frequency: 100, context: context).start(0.0) >> context.output

      rendered = context.render
      expect(rendered.sample_rate).to eq(sample_rate)
      expect(rendered.frames).to eq((sample_rate * 0.001).ceil)
    end

    [1, 2, 4].each do |channels|
      context = Deftones::OfflineContext.new(duration: 0.01, sample_rate: 100, buffer_size: 1, channels: channels)
      Deftones::UserMedia.new(buffer: Deftones::Buffer.from_mono([0.25], sample_rate: 100), context: context).start(0.0) >> context.output

      rendered = context.render
      expect(rendered.number_of_channels).to eq(channels)
      expect(rendered.to_array).to all(eq([0.25]))
    end
  end

  it "preserves stereo channels through Envelope" do
    context = Deftones::OfflineContext.new(duration: 0.04, sample_rate: 100, buffer_size: 4, channels: 2)
    merge = Deftones::Merge.new(context: context)
    left_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([1.0, 1.0, 1.0, 1.0], sample_rate: 100),
      context: context
    ).start(0.0)
    right_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([0.5, 0.5, 0.5, 0.5], sample_rate: 100),
      context: context
    ).start(0.0)
    envelope = Deftones::Envelope.new(attack: 0.0, decay: 0.0, sustain: 1.0, release: 0.0, context: context)

    left_source >> merge.left
    right_source >> merge.right
    merge >> envelope >> context.output
    envelope.trigger_attack(0.0, 1.0)
    buffer = context.render

    expect(buffer.get_channel_data(0)).to eq([1.0, 1.0, 1.0, 1.0])
    expect(buffer.get_channel_data(1)).to eq([0.5, 0.5, 0.5, 0.5])
  end

  it "exposes render position and dispatches transport callbacks by block" do
    Deftones.reset!
    context = Deftones::OfflineContext.new(duration: 0.3, sample_rate: 100, buffer_size: 10, channels: 1)
    positions = []
    callback_position = nil

    Deftones.transport.schedule(0.25) do |time|
      callback_position = [context.current_frame, context.current_time, time]
    end

    context.render_each_block do |_block, start_frame|
      positions << [start_frame, context.current_time]
    end

    expect(positions).to eq([[0, 0.0], [10, 0.1], [20, 0.2]])
    expect(callback_position).to eq([20, 0.2, 0.25])
    expect(context.current_time).to eq(0.0)
  ensure
    Deftones.reset!
  end

  it "supports context-scoped transport and draw events during offline rendering" do
    Deftones.reset!
    context = Deftones::OfflineContext.new(duration: 0.03, sample_rate: 100, buffer_size: 3, channels: 1)
    context_transport_calls = []
    global_transport_calls = []
    draw_calls = []

    context.transport.schedule(0.02) { |time| context_transport_calls << time }
    Deftones.transport.schedule(0.02) { |time| global_transport_calls << time }
    context.draw.schedule(0.01) { |time| draw_calls << time }

    context.render

    expect(context_transport_calls).to eq([0.02])
    expect(global_transport_calls).to eq([0.02])
    expect(draw_calls).to eq([0.01])
  ensure
    Deftones.reset!
  end

  it "returns render metadata and reports progress" do
    context = Deftones::OfflineContext.new(duration: 0.02, sample_rate: 100, buffer_size: 1, channels: 1)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([0.5, 1.0], sample_rate: 100),
      context: context
    ).start(0.0)
    progress = []

    source >> context.output
    result = context.render_with_metadata(progress: ->(value) { progress << value })

    expect(result.buffer).to be_a(Deftones::Buffer)
    expect(result.metadata).to include(frames: 2, channels: 1, sample_rate: 100, peak: 1.0, clip_count: 1)
    expect(context.last_render_metadata).to eq(result.metadata)
    expect(progress).to eq([0.5, 1.0])
  end

  it "supports seeded renders and cancellation" do
    first = Deftones.render(duration: 0.03, sample_rate: 100, buffer_size: 3, channels: 1, seed: 123) do |context|
      Deftones::Noise.new(type: :white, context: context).start(0.0) >> context.output
    end
    second = Deftones.render(duration: 0.03, sample_rate: 100, buffer_size: 3, channels: 1, seed: 123) do |context|
      Deftones::Noise.new(type: :white, context: context).start(0.0) >> context.output
    end

    expect(first.samples).to eq(second.samples)

    context = Deftones::OfflineContext.new(duration: 0.02, sample_rate: 100, buffer_size: 1)
    expect do
      context.render(cancel: ->(progress) { progress >= 0.5 })
    end.to raise_error(Deftones::OfflineContext::RenderCancelled)
  end

  it "streams offline rendering directly to a wav file" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "streamed.wav")
      context = Deftones::OfflineContext.new(duration: 0.02, sample_rate: 100, buffer_size: 5, channels: 1)
      source = Deftones::UserMedia.new(
        buffer: Deftones::Buffer.from_mono([0.25, 0.25], sample_rate: 100),
        context: context
      ).start(0.0)

      source >> context.output

      expect(context.render_to_file(path, streaming: true, bit_depth: 24)).to eq(path)
      expect(File.binread(path, 12)).to eq("RIFF" + File.binread(path, 8)[4, 4] + "WAVE")
      expect(File.size(path)).to eq(44 + (2 * 3))
    end
  end
end
