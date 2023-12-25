module Geode::YAML
  abstract class Node
    getter loc : Location

    def initialize(@loc)
    end
  end

  class Scalar < Node
    property value : String
    property? pipe : Bool
    property? fold : Bool

    def initialize(loc, @value, @pipe = false, @fold = false)
      super loc
    end
  end

  class Mapping < Node
    property key : Node
    property value : Node

    def initialize(loc, @key, @value)
      super loc
    end
  end

  class List < Node
    property values : Array(Node)

    def initialize(loc, @values)
      super loc
    end
  end

  class DocumentStart < Node
  end

  class DocumentEnd < Node
  end

  class Space < Node
    property value : String

    def initialize(loc, @value)
      super loc
    end
  end

  class Newline < Node
  end
end
