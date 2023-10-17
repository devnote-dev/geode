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

    PATH      = CACHE_DIR / "config.ini"
    TEMPLATES = LIBRARY_DIR / "templates"

    class Error < Exception
      enum Code
        NotFound
        ParseException
      end

      getter code : Code

      def initialize(@code, @message = nil)
      end
    end

    private class Presets
      property author : String?
      property url : String?
      property license : String?
      property vcs : String?

      def initialize(@author, @url, @license, @vcs)
      end
    end

    property notices : Hash(String, Bool)
    property presets : Presets

    def self.load : self
      data = INI.parse File.read PATH

      notices = data["notices"]?.try &.transform_values { |v| v == "true" }
      presets = data["presets"]?.try do |value|
        Presets.new(
          value["author"]?,
          value["url"]?,
          value["license"]?,
          value["vcs"]?,
        )
      end

      new notices, presets
    rescue File::NotFoundError
      raise Error.new :not_found
    rescue ex : INI::ParseException
      raise Error.new :parse_exception, ex.to_s
    end

    def initialize(notices, presets)
      @notices = notices || {} of String => Bool
      @presets = presets || Presets.new(nil, nil, nil, nil)
    end

    def save : Nil
      File.open(PATH, mode: "w") do |file|
        INI.build file, {
          notices: @notices,
          presets: {
            author:  @presets.author,
            url:     @presets.url,
            license: @presets.license,
            vcs:     @presets.vcs,
          },
        }
      end
    end
  end
end
