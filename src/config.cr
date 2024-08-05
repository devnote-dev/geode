module Geode
  class Config
    CACHE_DIR = {% if flag?(:win32) %}
                  Path[ENV["LOCALAPPDATA"], "geode"]
                {% else %}
                  Path[ENV["XDG_CACHE_HOME"]? || Path.home / ".config" / "geode"]
                {% end %}

    LIBRARY_DIR = {% if flag?(:win32) %}
                    Path[ENV["APPDATA"], "geode"]
                  {% else %}
                    Path[ENV["XDG_DATA_HOME"]? || Path.home / ".local" / "share" / "geode"]
                  {% end %}

    TEMPLATES = LIBRARY_DIR / "templates"

    class Error < Exception
      enum Code
        NotFound
        Parsing
        Saving
      end

      getter code : Code

      def initialize(@code, @message = nil, @cause = nil)
      end
    end

    class Notices
      include YAML::Serializable

      property? shardbox : Bool
      property? crystaldoc : Bool

      def initialize(@shardbox, @crystaldoc)
      end
    end

    class Presets
      include YAML::Serializable

      @[YAML::Field(emit_null: true)]
      property author : String?
      @[YAML::Field(emit_null: true)]
      property url : String?
      @[YAML::Field(emit_null: true)]
      property license : String?
      @[YAML::Field(emit_null: true)]
      property vcs : String?

      def initialize(@author, @url, @license, @vcs)
      end
    end

    include YAML::Serializable

    getter notices : Notices
    getter presets : Presets

    class_getter path : String do
      if File.exists?(path = CACHE_DIR / "config.yml")
        path
      elsif File.exists?(path = CACHE_DIR / "config.yaml")
        path
      else
        raise Error.new :not_found
      end.to_s
    end

    def self.load : self
      File.open(path) do |file|
        from_yaml file
      end
    rescue ex : YAML::Error
      raise Error.new :parsing, ex.message, cause: ex
    end

    def initialize
      @notices = Notices.new(true, true)
      @presets = Presets.new(nil, nil, nil, nil)
    end

    def save : Nil
      dest = Geode::Config.path rescue CACHE_DIR / "config.yml"
      File.write dest, to_yaml
    rescue ex
      raise Error.new :saving, ex.message, cause: ex
    end
  end
end
