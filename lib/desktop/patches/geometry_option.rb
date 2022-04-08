module Slop
  class GeometryOption < Option
    def call(value)
      if value !~ /^[0-9]+x[0-9]+$/
        raise 'invalid geometry string'
      else
        value.to_s
      end
    end
  end
end
