module Geode
  class Dependency
    include YAML::Serializable

    property name : String { raise "unreachable" }
    property version : String?
    property branch : String?
    property commit : String?
    property path : String?
    property git : String?
    property github : String?
    property gitlab : String?
    property bitbucket : String?
    property hg : String?
    property fossil : String?

    def validate! : Nil
      case {@path, @git, @github, @gitlab, @bitbucket, @hg, @fossil}.count(&.itself)
      when 0
        raise Shard::Error.new :no_resolver, @name
      when 1
        # that's fine
      else
        raise Shard::Error.new :dup_resolver, @name
      end

      if @version && (@branch || @commit)
        raise Shard::Error.new :version_conflict, @name
      end
    end

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
        NoResolver
        DupResolver
        VersionConflict
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

    getter dependency_shards : Hash(String, Shard) do
      @dependencies.keys.map do |name|
        {name, Shard.load(name)}
      end.to_h
    end

    getter development_shards : Hash(String, Shard) do
      @development.keys.map do |name|
        {name, Shard.load(name)}
      end.to_h
    end

    def self.load(source : String) : self
      if source.ends_with? ".yml"
        from_yaml File.read source
      else
        from_yaml File.read Path["lib", source, "shard.yml"].expand
      end
    rescue File::NotFoundError
      raise Error.new :not_found
    rescue ex : YAML::ParseException
      raise Error.new :parse_exception, ex.to_s
    end

    def self.load_local : self
      load "shard.yml"
    end

    def self.load_raw(str : String) : self
      from_yaml str
    rescue ex : YAML::ParseException
      raise Error.new :parse_exception, ex.to_s
    end

    def self.exists?(source : String) : Bool
      if source.ends_with? ".yml"
        File.exists? source
      else
        File.exists? Path["lib", source, "shard.yml"].expand
      end
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

    def after_initialize : Nil
      @dependencies.each { |name, dep| dep.name = name }
      @development.each { |name, dep| dep.name = name }
    end
  end
end
