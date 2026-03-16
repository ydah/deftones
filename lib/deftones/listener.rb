# frozen_string_literal: true

module Deftones
  class Listener
    attr_reader :forward_x, :forward_y, :forward_z, :position_x, :position_y, :position_z, :up_x, :up_y, :up_z

    def initialize(context: Deftones.context)
      @position_x = Core::Signal.new(value: 0.0, units: :number, context: context)
      @position_y = Core::Signal.new(value: 0.0, units: :number, context: context)
      @position_z = Core::Signal.new(value: 0.0, units: :number, context: context)
      @forward_x = Core::Signal.new(value: 0.0, units: :number, context: context)
      @forward_y = Core::Signal.new(value: 0.0, units: :number, context: context)
      @forward_z = Core::Signal.new(value: -1.0, units: :number, context: context)
      @up_x = Core::Signal.new(value: 0.0, units: :number, context: context)
      @up_y = Core::Signal.new(value: 1.0, units: :number, context: context)
      @up_z = Core::Signal.new(value: 0.0, units: :number, context: context)
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

    def forward_x=(value)
      @forward_x.value = value
    end

    def forward_y=(value)
      @forward_y.value = value
    end

    def forward_z=(value)
      @forward_z.value = value
    end

    def up_x=(value)
      @up_x.value = value
    end

    def up_y=(value)
      @up_y.value = value
    end

    def up_z=(value)
      @up_z.value = value
    end

    def set_position(x, y, z)
      self.position_x = x
      self.position_y = y
      self.position_z = z
      self
    end

    def set_orientation(forward_x, forward_y, forward_z, up_x = 0.0, up_y = 1.0, up_z = 0.0)
      self.forward_x = forward_x
      self.forward_y = forward_y
      self.forward_z = forward_z
      self.up_x = up_x
      self.up_y = up_y
      self.up_z = up_z
      self
    end

    alias positionX position_x
    alias positionY position_y
    alias positionZ position_z
    alias forwardX forward_x
    alias forwardY forward_y
    alias forwardZ forward_z
    alias upX up_x
    alias upY up_y
    alias upZ up_z
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

    def forwardX=(value)
      self.forward_x = value
    end

    def forwardY=(value)
      self.forward_y = value
    end

    def forwardZ=(value)
      self.forward_z = value
    end

    def upX=(value)
      self.up_x = value
    end

    def upY=(value)
      self.up_y = value
    end

    def upZ=(value)
      self.up_z = value
    end
  end
end
