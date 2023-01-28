module Geode
  class Package
    include YAML::Serializable
    include YAML::Serializable::Unmapped

    NAME_REGEX = /\A[a-z][a-z0-9_-]+\z/

    property name : String
    property description : String?
    property authors : Array(String)?
    property version : String
    property crystal : String?
    property license : String?
    property dependencies : Array(Dependency) = [] of Dependency
    @[YAML::Field(name: "development_dependencies")]
    property dev_dependencies : Array(Dependency) = [] of Dependency
    property documentation : String?
    property executables : Array(String)?
    property libraries : Hash(String, String)?
    property targets : Hash(String, Hash(String, String))?
  end

  class Dependency
    include YAML::Serializable

    property path : String?
    property git : String?
    property github : String?
    property gitlab : String?
    property bitbucket : String?
    property hg : String?
    property fossil : String?
    property version : String?
    property branch : String?
    property commit : String?
    property tag : String?
    property bookmark : String?
  end
end
