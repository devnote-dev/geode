module Geode::YAML
  class Location
    property line_start : Int32
    property line_stop : Int32
    property column_start : Int32
    property column_stop : Int32

    def initialize(@line_start, @column_start)
      @line_stop = @column_stop = 0
    end

    def &(other : Location) : Location
      loc = dup
      loc.line_stop = other.line_stop
      loc.column_stop = other.column_stop

      loc
    end
  end

  class Token
    enum Type
      Scalar
      Colon
      Pipe
      Fold
      List
      DocumentStart
      DocumentEnd

      Space
      Newline
      EOF
    end

    property type : Type
    property loc : Location
    property! value : String

    def initialize(@type, @loc, @value = nil)
    end
  end
end
