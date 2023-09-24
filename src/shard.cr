module Geode
  class Dependency
    include YAML::Serializable

    property! name : String
    property! version : String
    property! path : String
    property! git : String
    property! github : String
    property! gitlab : String
    property! bitbucket : String
    property! hg : String
    property! fossil : String

    def to_s(io : IO) : Nil
      io << name
    end
  end

  class Shard
    include YAML::Serializable

    NAME_REGEX = /\A[a-z][a-z0-9_-]+\z/

    class Error < Exception
      enum Code
        NotFound
        ParseException
      end

      getter code : Code

      def initialize(@code, @message = nil)
      end
    end

    property name : String
    property description : String?
    property authors : Array(String)?
    property version : String
    property crystal : String?
    property documentation : String?
    property license : String?
    property repository : String?
    property dependencies : Hash(String, Dependency) = {} of String => Dependency
    @[YAML::Field(key: "development_dependencies")]
    property development : Hash(String, Dependency) = {} of String => Dependency
    property libraries : Hash(String, String) = {} of String => String
    property executables : Array(String) = [] of String
    property scripts : Hash(String, String) = {} of String => String
    property targets : Hash(String, Hash(String, String)) = Hash(String, Hash(String, String)).new

    def self.load_local : self
      from_yaml File.read "shard.yml"
    rescue File::NotFoundError
      raise Error.new :not_found
    rescue ex : YAML::ParseException
      raise Error.new :parse_exception, ex.to_s
    end

    def name_dependencies : Nil
      @dependencies.each { |name, dep| dep.name = name }
      @development.each { |name, dep| dep.name = name }
    end

    def has_postinstall? : Bool
      @scripts.keys.any? &.starts_with? "postinstall"
    end

    def find_target_script(name : String, target : String) : String?
      if @scripts.keys.any? &.starts_with? "#{name}@"
        if script = @scripts["#{name}@#{target}"]?
          script
        else
          @scripts[name]?
        end
      else
        @scripts[name]?
      end
    end
  end
end
