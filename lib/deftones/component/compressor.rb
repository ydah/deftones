# frozen_string_literal: true

module Deftones
  module Component
    class Compressor < Core::AudioNode
      DETECTORS = %i[peak rms].freeze

      attr_reader :threshold, :ratio, :attack, :release, :detector, :knee, :lookahead, :lookahead_samples,
                  :rms_window, :true_peak

      def initialize(threshold: -18.0, ratio: 4.0, attack: 0.01, release: 0.1, detector: :peak,
                     knee: 0.0, lookahead: 0.0, rms_window: 0.01, true_peak: false,
                     context: Deftones.context)
        super(context: context)
        @gain_db = []
        @rms_energy = []
        @lookahead_buffers = []
        @previous_detector_samples = []
        self.threshold = threshold
        self.ratio = ratio
        self.attack = attack
        self.release = release
        self.detector = detector
        self.knee = knee
        self.lookahead = lookahead
        self.rms_window = rms_window
        self.true_peak = true_peak
      end

      def threshold=(value)
        @threshold = value.to_f
      end

      def ratio=(value)
        @ratio = value.to_f
      end

      def attack=(value)
        @attack = value.to_f
        @attack_smoothing = smoothing_for(@attack)
      end

      def release=(value)
        @release = value.to_f
        @release_smoothing = smoothing_for(@release)
      end

      def detector=(value)
        @detector = normalize_detector(value)
      end

      def knee=(value)
        @knee = [value.to_f, 0.0].max
      end

      def lookahead=(value)
        @lookahead = [value.to_f, 0.0].max
        @lookahead_samples = (@lookahead * context.sample_rate).round
        @lookahead_buffers = []
      end

      def rms_window=(value)
        @rms_window = [value.to_f, 0.0].max
        @rms_smoothing = smoothing_for(@rms_window)
      end

      def true_peak=(value)
        @true_peak = !!value
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, _start_frame, _cache)
        ensure_channel_state(input_block.channels)
        Core::AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            Array.new(num_frames) { |index| compress(channel[index], channel_index) }
          end
        )
      end

      private

      def compress(sample, channel_index)
        level = [detector_level(sample, channel_index), 1.0e-9].max
        level_db = 20.0 * Math.log10(level)
        target_gain_db = gain_reduction_db(level_db)

        current_gain_db = @gain_db[channel_index]
        smoothing = target_gain_db < current_gain_db ? @attack_smoothing : @release_smoothing
        current_gain_db += (target_gain_db - current_gain_db) * smoothing
        @gain_db[channel_index] = current_gain_db
        lookahead_sample(sample, channel_index) * (10.0**(current_gain_db / 20.0))
      end

      def detector_level(sample, channel_index)
        level =
          case @detector
          when :rms then rms_level(sample, channel_index)
          else sample.abs
          end
        return level unless @true_peak

        previous_sample = @previous_detector_samples[channel_index] || sample
        @previous_detector_samples[channel_index] = sample
        [level, sample.abs, previous_sample.abs, ((previous_sample + sample) * 0.5).abs].max
      end

      def rms_level(sample, channel_index)
        energy = @rms_energy[channel_index]
        @rms_energy[channel_index] = ((1.0 - @rms_smoothing) * energy) + (@rms_smoothing * sample * sample)
        Math.sqrt(@rms_energy[channel_index])
      end

      def gain_reduction_db(level_db)
        ratio = [@ratio, 1.0].max
        return 0.0 if ratio <= 1.0
        return hard_knee_gain_reduction_db(level_db, ratio) if @knee.zero?

        over_threshold = level_db - @threshold
        half_knee = @knee * 0.5
        return 0.0 if over_threshold <= -half_knee
        return hard_knee_gain_reduction_db(level_db, ratio) if over_threshold >= half_knee

        ((1.0 / ratio) - 1.0) * ((over_threshold + half_knee)**2.0) / (2.0 * @knee)
      end

      def hard_knee_gain_reduction_db(level_db, ratio)
        return 0.0 unless level_db > @threshold

        compressed_db = @threshold + ((level_db - @threshold) / ratio)
        compressed_db - level_db
      end

      def lookahead_sample(sample, channel_index)
        return sample if @lookahead_samples.zero?

        buffer = @lookahead_buffers[channel_index]
        buffer << sample
        buffer.shift || 0.0
      end

      def smoothing_for(seconds)
        1.0 / [(seconds.to_f * context.sample_rate), 1.0].max
      end

      def ensure_channel_state(channels)
        required = [channels.to_i, 1].max
        @gain_db.fill(0.0, @gain_db.length...required)
        @rms_energy.fill(0.0, @rms_energy.length...required)
        @previous_detector_samples.fill(0.0, @previous_detector_samples.length...required)
        required.times do |channel_index|
          next if @lookahead_buffers[channel_index]&.length == @lookahead_samples

          @lookahead_buffers[channel_index] = Array.new(@lookahead_samples, 0.0)
        end
      end

      def normalize_detector(value)
        normalized = value.to_sym
        return normalized if DETECTORS.include?(normalized)

        raise ArgumentError, "Unsupported compressor detector: #{value}"
      end
    end
  end
end
