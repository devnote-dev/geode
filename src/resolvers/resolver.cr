module Geode
  abstract class Resolver
    getter shard_name : String
    getter source : String

    def initialize(@shard_name, @source)
    end

    abstract def available_releases : Array(String)
    abstract def install_sources(version : String, dest : String) : Nil

    def update_local_cache : Nil
    end
  end
end
