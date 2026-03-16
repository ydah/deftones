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

      def process(input_buffer, num_frames, start_frame, _cache)
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

        Array.new(num_frames) do |index|
          source_position = [position_x_values[index], position_y_values[index], position_z_values[index]]
          orientation = [orientation_x_values[index], orientation_y_values[index], orientation_z_values[index]]
          gain = distance_gain(source_position, listener_position) * cone_gain(source_position, listener_position, orientation)
          input_buffer[index] * gain
        end
      end

      private

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
    end
  end
end
