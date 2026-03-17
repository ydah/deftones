# frozen_string_literal: true

module Deftones
  module Component
    class Panner3D < Core::AudioNode
      attr_accessor :cone_inner_angle, :cone_outer_angle, :cone_outer_gain,
                    :distance_model, :max_distance, :panning_model, :ref_distance, :rolloff_factor
      attr_reader :listener, :orientation_x, :orientation_y, :orientation_z, :position_x, :position_y, :position_z

      def initialize(position_x: 0.0, position_y: 0.0, position_z: 0.0,
                     orientation_x: 1.0, orientation_y: 0.0, orientation_z: 0.0,
                     panning_model: :equal_power, distance_model: :inverse,
                     ref_distance: 1.0, rolloff_factor: 1.0, max_distance: 10_000.0,
                     cone_inner_angle: 360.0, cone_outer_angle: 360.0, cone_outer_gain: 0.0,
                     listener: Deftones.listener, context: Deftones.context)
        super(context: context)
        @listener = listener
        @position_x = Core::Signal.new(value: position_x, units: :number, context: context)
        @position_y = Core::Signal.new(value: position_y, units: :number, context: context)
        @position_z = Core::Signal.new(value: position_z, units: :number, context: context)
        @orientation_x = Core::Signal.new(value: orientation_x, units: :number, context: context)
        @orientation_y = Core::Signal.new(value: orientation_y, units: :number, context: context)
        @orientation_z = Core::Signal.new(value: orientation_z, units: :number, context: context)
        @panning_model = panning_model.to_sym
        @distance_model = distance_model.to_sym
        @ref_distance = ref_distance.to_f
        @rolloff_factor = rolloff_factor.to_f
        @max_distance = max_distance.to_f
        @cone_inner_angle = cone_inner_angle.to_f
        @cone_outer_angle = cone_outer_angle.to_f
        @cone_outer_gain = cone_outer_gain.to_f
        @hrtf_delay_lines = []
      end

      def position_x=(value)
        @position_x.value = value
      end

      def position_y=(value)
        @position_y.value = value
      end

      def position_z=(value)
        @position_z.value = value
      end

      def orientation_x=(value)
        @orientation_x.value = value
      end

      def orientation_y=(value)
        @orientation_y.value = value
      end

      def orientation_z=(value)
        @orientation_z.value = value
      end

      def set_position(x, y, z)
        self.position_x = x
        self.position_y = y
        self.position_z = z
        self
      end

      def set_orientation(x, y, z)
        self.orientation_x = x
        self.orientation_y = y
        self.orientation_z = z
        self
      end

      alias positionX position_x
      alias positionY position_y
      alias positionZ position_z
      alias orientationX orientation_x
      alias orientationY orientation_y
      alias orientationZ orientation_z
      alias setPosition set_position
      alias setOrientation set_orientation

      def positionX=(value)
        self.position_x = value
      end

      def positionY=(value)
        self.position_y = value
      end

      def positionZ=(value)
        self.position_z = value
      end

      def orientationX=(value)
        self.orientation_x = value
      end

      def orientationY=(value)
        self.orientation_y = value
      end

      def orientationZ=(value)
        self.orientation_z = value
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        position_x_values = @position_x.process(num_frames, start_frame)
        position_y_values = @position_y.process(num_frames, start_frame)
        position_z_values = @position_z.process(num_frames, start_frame)
        orientation_x_values = @orientation_x.process(num_frames, start_frame)
        orientation_y_values = @orientation_y.process(num_frames, start_frame)
        orientation_z_values = @orientation_z.process(num_frames, start_frame)

        listener_position = [
          @listener.position_x.value,
          @listener.position_y.value,
          @listener.position_z.value
        ]
        listener_forward = normalize_vector([
          @listener.forward_x.value,
          @listener.forward_y.value,
          @listener.forward_z.value
        ])
        listener_up = normalize_vector([
          @listener.up_x.value,
          @listener.up_y.value,
          @listener.up_z.value
        ])

        stereo_input = input_block.fit_channels(2)
        mono_input = input_block.mono
        left = Array.new(num_frames)
        right = Array.new(num_frames)

        num_frames.times do |index|
          source_position = [position_x_values[index], position_y_values[index], position_z_values[index]]
          orientation = [orientation_x_values[index], orientation_y_values[index], orientation_z_values[index]]
          gain = distance_gain(source_position, listener_position) * cone_gain(source_position, listener_position, orientation)
          pan = stereo_pan_value(source_position, listener_position, listener_forward, listener_up)
          if @panning_model == :hrtf
            left[index], right[index] = hrtf_frame(
              input_block,
              stereo_input,
              mono_input,
              index,
              gain,
              pan
            )
            next
          end

          angle = stereo_pan_angle(pan)
          if input_block.channels == 1
            left[index] = mono_input[index] * gain * Math.cos(angle)
            right[index] = mono_input[index] * gain * Math.sin(angle)
          else
            left[index] = stereo_input.channel_data[0][index] * gain * Math.cos(angle)
            right[index] = stereo_input.channel_data[1][index] * gain * Math.sin(angle)
          end
        end

        Core::AudioBlock.from_channel_data([left, right])
      end

      def render(num_frames, start_frame = 0, cache = {})
        position_x_values = @position_x.process(num_frames, start_frame)
        position_y_values = @position_y.process(num_frames, start_frame)
        position_z_values = @position_z.process(num_frames, start_frame)
        orientation_x_values = @orientation_x.process(num_frames, start_frame)
        orientation_y_values = @orientation_y.process(num_frames, start_frame)
        orientation_z_values = @orientation_z.process(num_frames, start_frame)
        listener_position = [
          @listener.position_x.value,
          @listener.position_y.value,
          @listener.position_z.value
        ]
        listener_forward = normalize_vector([
          @listener.forward_x.value,
          @listener.forward_y.value,
          @listener.forward_z.value
        ])
        listener_up = normalize_vector([
          @listener.up_x.value,
          @listener.up_y.value,
          @listener.up_z.value
        ])
        mono_input = send(:mix_source_blocks, num_frames, start_frame, cache).mono

        Array.new(num_frames) do |index|
          source_position = [position_x_values[index], position_y_values[index], position_z_values[index]]
          orientation = [orientation_x_values[index], orientation_y_values[index], orientation_z_values[index]]
          gain = distance_gain(source_position, listener_position) * cone_gain(source_position, listener_position, orientation)
          mono_input[index] * gain
        end
      end

      private

      def uses_legacy_render_for_block?
        false
      end

      def distance_gain(source_position, listener_position)
        distance = distance_between(source_position, listener_position)
        return 1.0 if distance <= @ref_distance

        case @distance_model
        when :linear
          denominator = [@max_distance - @ref_distance, 1.0e-6].max
          1.0 - (@rolloff_factor * (distance - @ref_distance) / denominator)
        when :exponential
          (distance / @ref_distance)**(-@rolloff_factor)
        else
          @ref_distance / (@ref_distance + (@rolloff_factor * (distance - @ref_distance)))
        end.clamp(0.0, 1.0)
      end

      def cone_gain(source_position, listener_position, orientation)
        return 1.0 if @cone_outer_angle >= 360.0 && @cone_inner_angle >= 360.0

        to_listener = normalize_vector(vector_between(source_position, listener_position))
        facing = normalize_vector(orientation)
        angle = Math.acos(dot_product(facing, to_listener).clamp(-1.0, 1.0)) * 180.0 / Math::PI
        inner_half = @cone_inner_angle * 0.5
        outer_half = @cone_outer_angle * 0.5

        return 1.0 if angle <= inner_half
        return @cone_outer_gain if angle >= outer_half

        progress = (angle - inner_half) / [outer_half - inner_half, 1.0e-6].max
        1.0 + ((@cone_outer_gain - 1.0) * progress)
      end

      def distance_between(point_a, point_b)
        Math.sqrt(point_a.zip(point_b).sum { |left, right| (left - right)**2 })
      end

      def vector_between(from, to)
        to.zip(from).map { |target, origin| target - origin }
      end

      def normalize_vector(vector)
        magnitude = Math.sqrt(vector.sum { |value| value * value })
        return [0.0, 0.0, -1.0] if magnitude.zero?

        vector.map { |value| value / magnitude }
      end

      def dot_product(left, right)
        left.zip(right).sum { |lhs, rhs| lhs * rhs }
      end

      def stereo_pan_value(source_position, listener_position, listener_forward, listener_up)
        relative = vector_between(listener_position, source_position)
        listener_right = normalize_vector(cross_product(listener_forward, listener_up))
        lateral = dot_product(relative, listener_right)
        forwardness = dot_product(relative, listener_forward)
        angle = Math.atan2(lateral, forwardness)
        (angle / (Math::PI * 0.5)).clamp(-1.0, 1.0)
      end

      def stereo_pan_angle(pan)
        ((pan + 1.0) * Math::PI) * 0.25
      end

      def hrtf_frame(input_block, stereo_input, mono_input, index, gain, pan)
        input_left, input_right =
          if input_block.channels == 1
            sample = mono_input[index]
            [sample, sample]
          else
            [stereo_input.channel_data[0][index], stereo_input.channel_data[1][index]]
          end

        ensure_hrtf_delay_lines
        delay = hrtf_delay_samples(pan.abs)
        near_gain = 1.0
        far_gain = 1.0 - (0.35 * pan.abs)

        if pan.positive?
          [
            @hrtf_delay_lines[0].tap(delay, input_sample: input_left * gain * far_gain),
            @hrtf_delay_lines[1].write(input_right * gain * near_gain)
          ]
        elsif pan.negative?
          [
            @hrtf_delay_lines[0].write(input_left * gain * near_gain),
            @hrtf_delay_lines[1].tap(delay, input_sample: input_right * gain * far_gain)
          ]
        else
          [
            @hrtf_delay_lines[0].write(input_left * gain),
            @hrtf_delay_lines[1].write(input_right * gain)
          ]
        end
      end

      def ensure_hrtf_delay_lines
        return unless @hrtf_delay_lines.empty?

        max_delay = [(context.sample_rate * 0.0006).ceil, 2].max
        @hrtf_delay_lines = Array.new(2) { DSP::DelayLine.new(max_delay) }
      end

      def hrtf_delay_samples(pan_amount)
        pan_amount.to_f.clamp(0.0, 1.0) * (context.sample_rate * 0.0006)
      end

      def cross_product(left, right)
        [
          (left[1] * right[2]) - (left[2] * right[1]),
          (left[2] * right[0]) - (left[0] * right[2]),
          (left[0] * right[1]) - (left[1] * right[0])
        ]
      end
    end
  end
end
