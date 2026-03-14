# frozen_string_literal: true

RSpec::Matchers.define :have_frequency do |expected_frequency, tolerance: 10.0|
  match do |buffer|
    @actual_frequency = dominant_frequency_for(buffer)
    (@actual_frequency - expected_frequency.to_f).abs <= tolerance.to_f
  end

  failure_message do
    "expected dominant frequency #{expected_frequency}Hz +/- #{tolerance}Hz, got #{@actual_frequency}Hz"
  end

  def dominant_frequency_for(buffer)
    samples = padded_samples(buffer.mono)
    magnitudes = Deftones::FFT.magnitudes(samples)
    peak_bin = magnitudes.each_with_index.max_by(&:first)&.last || 0
    (peak_bin * buffer.sample_rate.to_f) / samples.length
  end

  def padded_samples(samples)
    source = samples.first(4096)
    size = 1
    size <<= 1 while size < source.length
    padded = source.first(size)
    padded.fill(0.0, padded.length...size)
    padded
  end
end
