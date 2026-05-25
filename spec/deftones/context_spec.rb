# frozen_string_literal: true

RSpec.describe Deftones::Context do
  class FakeRealtimeBackend
    attr_reader :samples, :stopped, :closed

    def initialize(context:)
      @context = context
      @samples = nil
      @stopped = false
      @closed = false
    end

    def start
      @samples = @context.send(:pull_realtime_samples, 4)
      self
    end

    def stop
      @stopped = true
      self
    end

    def close
      @closed = true
      self
    end

    def time
      0.25
    end
  end

  class FailingRealtimeBackend
    def initialize(context:)
      @context = context
    end

    def start
      raise "stream open failed"
    end

    def close
      true
    end
  end

  it "renders through an injected realtime backend" do
    context = described_class.new(sample_rate: 8, channels: 2, realtime_backend: FakeRealtimeBackend)
    buffer = Deftones::Buffer.from_mono([0.25, 0.25, 0.25, 0.25], sample_rate: 8)
    user_media = Deftones::UserMedia.new(buffer: buffer, context: context).start(0.0)
    user_media >> context.instance_variable_get(:@output)

    context.start
    backend = context.instance_variable_get(:@stream)

    expect(context.realtime?).to eq(true)
    expect(context.current_time).to eq(0.25)
    expect(backend.samples).to eq([0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25])

    context.stop

    expect(backend.stopped).to eq(true)
    expect(backend.closed).to eq(true)
  end

  it "dispatches realtime transport callbacks before rendering a block" do
    context = described_class.new(sample_rate: 8, channels: 1, realtime_backend: FakeRealtimeBackend)
    buffer = Deftones::Buffer.from_mono([0.5, 0.5, 0.5, 0.5], sample_rate: 8)
    user_media = Deftones::UserMedia.new(buffer: buffer, context: context)

    user_media >> context.instance_variable_get(:@output)
    context.transport.schedule(0.0) { user_media.start(0.0) }
    context.start

    expect(context.instance_variable_get(:@stream).samples).to eq([0.5, 0.5, 0.5, 0.5])

    context.stop
  end

  it "autostarts when its output is accessed" do
    context = described_class.new(realtime_backend: FakeRealtimeBackend)

    expect(context.running?).to eq(false)

    context.output

    expect(context.running?).to eq(true)
    expect(context.realtime?).to eq(true)
  end

  it "records backend errors without crashing the context" do
    context = described_class.new(realtime_backend: FailingRealtimeBackend)

    context.start

    expect(context.running?).to eq(true)
    expect(context.realtime?).to eq(false)
    expect(context.stream_error).to be_a(RuntimeError)
    expect(context.stream_error.message).to eq("stream open failed")
  end

  it "notifies realtime stream errors and supports continue mode" do
    errors = []
    context = described_class.new(
      autostart: false,
      on_stream_error: ->(error) { errors << error.message },
      stream_error_mode: :continue
    )
    error = RuntimeError.new("callback failed")

    expect(context.send(:handle_stream_error, error)).to eq(:continue)
    expect(context.stream_error).to eq(error)
    expect(errors).to eq(["callback failed"])

    context.streamErrorMode = :abort
    expect(context.send(:handle_stream_error, RuntimeError.new("again"))).to eq(:abort)
    expect { context.streamErrorMode = :unknown }.to raise_error(ArgumentError, /stream error mode/)
  end

  it "records realtime stream status flags" do
    context = described_class.new(autostart: false)

    context.send(:record_stream_status_flags, :output_underflow)
    context.send(:record_stream_status_flags, 0)
    context.send(:record_stream_status_flags, nil)

    expect(context.streamStatusFlags).to eq([:output_underflow])

    context.start(use_realtime: false)
    expect(context.stream_status_flags).to eq([])
  end

  it "materializes Draw callbacks during realtime rendering" do
    Deftones::Draw.reset!
    context = described_class.new(sample_rate: 8, channels: 1, realtime_backend: FakeRealtimeBackend)
    callback_times = []

    Deftones.draw.schedule(0.25) { |time| callback_times << time }
    context.start

    expect(callback_times).to eq([0.25])

    context.stop
  ensure
    Deftones::Draw.reset!
  end

  it "keeps transport and draw schedulers scoped to each context" do
    first = described_class.new(sample_rate: 8, channels: 1, realtime_backend: FakeRealtimeBackend)
    second = described_class.new(sample_rate: 8, channels: 1, realtime_backend: FakeRealtimeBackend)
    first_calls = []
    second_calls = []

    first.draw.schedule(0.25) { |time| first_calls << time }
    second.draw.schedule(0.25) { |time| second_calls << time }

    first.start

    expect(first_calls).to eq([0.25])
    expect(second_calls).to eq([])

    first.stop
  end

  it "resets context-local scheduler state" do
    context = described_class.new(autostart: false)
    transport = context.transport
    draw = context.draw

    context.reset!

    expect(context.transport).not_to eq(transport)
    expect(context.draw).not_to eq(draw)
    expect(context.stream_error).to eq(nil)
  end

  it "reference-counts the PortAudio lifecycle" do
    portaudio = Module.new do
      class << self
        attr_accessor :init_count, :terminate_count

        def init
          @init_count += 1
        end

        def terminate
          @terminate_count += 1
        end
      end
    end
    portaudio.init_count = 0
    portaudio.terminate_count = 0
    stub_const("PortAudio", portaudio)
    Deftones::PortAudioSupport.instance_variable_set(:@ref_count, 0)

    Deftones::PortAudioSupport.acquire!
    Deftones::PortAudioSupport.acquire!
    Deftones::PortAudioSupport.release
    Deftones::PortAudioSupport.release

    expect(portaudio.init_count).to eq(1)
    expect(portaudio.terminate_count).to eq(1)
  ensure
    Deftones::PortAudioSupport.instance_variable_set(:@ref_count, 0)
  end
end
