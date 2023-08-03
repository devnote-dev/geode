module Geode
  class Shard
    include YAML::Serializable
    include YAML::Serializable::Unmapped

    NAME_REGEX = /\A[a-z][a-z0-9_-]+\z/

    alias Dependency = Hash(String, Hash(String, String))

    property name : String
    property description : String?
    property authors : Array(String)?
    property version : String
    property crystal : String?
    property documentation : String?
    property license : String?
    property repository : String?
    property dependencies : Dependency = Dependency.new
    @[YAML::Field(name: "development_dependencies")]
    property development : Dependency = Dependency.new
    property libraries : Hash(String, String) = {} of String => String
    property executables : Array(String) = [] of String
    property scripts : Hash(String, String) = {} of String => String
    property targets : Hash(String, Hash(String, String)) = Hash(String, Hash(String, String)).new

    def self.load_local : self
      from_yaml File.read "shard.yml"
    end
  end
end
