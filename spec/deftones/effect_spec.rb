# frozen_string_literal: true

RSpec.describe "Effects and dynamics" do
  def render_with(node)
    context = Deftones::OfflineContext.new(duration: 0.25)
    oscillator = Deftones::Oscillator.new(type: :sawtooth, frequency: 220, context: context)
    oscillator >> node >> context.output
    context.render
  end

  it "renders the effect classes" do
    effects = [
      Deftones::Distortion.new(amount: 0.7),
      Deftones::BitCrusher.new(bits: 6, downsample: 3),
      Deftones::Chebyshev.new(order: 4),
      Deftones::FeedbackDelay.new(delay_time: 0.03, feedback: 0.25),
      Deftones::PingPongDelay.new(delay_time: 0.025, feedback: 0.2),
      Deftones::Reverb.new(decay: 0.55),
      Deftones::Freeverb.new(decay: 0.65),
      Deftones::JCReverb.new(decay: 0.45),
      Deftones::Chorus.new(frequency: 1.2),
      Deftones::Phaser.new(frequency: 0.8),
      Deftones::Tremolo.new(frequency: 4.0),
      Deftones::Vibrato.new(frequency: 5.0),
      Deftones::AutoFilter.new(frequency: 1.5),
      Deftones::AutoPanner.new(frequency: 2.0),
      Deftones::AutoWah.new(base_frequency: 250),
      Deftones::FrequencyShifter.new(frequency: 40),
      Deftones::PitchShift.new(semitones: 5),
      Deftones::StereoWidener.new(width: 0.7)
    ]

    effects.each do |effect|
      buffer = render_with(effect)
      expect(buffer.peak).to be > 0.001
    end
  end

  it "renders eq and dynamics nodes" do
    context = Deftones::OfflineContext.new(duration: 0.25)
    oscillator = Deftones::Oscillator.new(type: :triangle, frequency: 220, context: context)
    eq = Deftones::EQ3.new(low: 3.0, mid: -1.0, high: 2.0, context: context)
    compressor = Deftones::Compressor.new(threshold: -24.0, ratio: 3.0, context: context)
    limiter = Deftones::Limiter.new(context: context)
    gate = Deftones::Gate.new(threshold: -60.0, context: context)

    oscillator >> eq >> compressor >> limiter >> gate >> context.output
    buffer = context.render

    expect(buffer.peak).to be > 0.001
    expect(buffer.rms).to be > 0.001
  end
end
