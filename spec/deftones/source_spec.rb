# frozen_string_literal: true

RSpec.describe "Source generators" do
  it "renders the standalone source classes" do
    context = Deftones::OfflineContext.new(duration: 0.2)
    sources = [
      Deftones::Noise.new(type: :pink, context: context),
      Deftones::PulseOscillator.new(frequency: 110, width: 0.3, context: context),
      Deftones::FMOscillator.new(frequency: 220, harmonicity: 1.5, modulation_index: 3.0, context: context),
      Deftones::AMOscillator.new(frequency: 220, harmonicity: 2.0, context: context),
      Deftones::FatOscillator.new(type: :triangle, frequency: 110, count: 4, context: context),
      Deftones::PWMOscillator.new(frequency: 110, modulation_frequency: 2.0, context: context),
      Deftones::OmniOscillator.new(type: :pulse, frequency: 220, context: context)
    ]

    sources.each { |source| source >> context.output }
    karplus = Deftones::Source::KarplusStrong.new(context: context)
    karplus.trigger("C4", 0.0, 0.8)
    karplus >> context.output

    buffer = context.render

    expect(buffer.peak).to be > 0.1
    expect(buffer.rms).to be > 0.01
  end
end
