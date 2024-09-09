module Geode::Resolvers
  class HGResolver < Base
    def get_versions : Array(String)
      raise "not implemented"
    end

    def validate(tag : String) : Nil
      raise "not implemented"
    end

    def install(tag : String, dest : String) : Nil
      raise "not implemented"
    end
  end
end
