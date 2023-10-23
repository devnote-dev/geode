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

    private class Notices
      property? shardbox : Bool
      property? crystaldoc : Bool

      def initialize(@shardbox, @crystaldoc)
      end
    end

    property notices : Notices
    property presets : Presets

    def self.load : self
      data = INI.parse File.read PATH

      notices = data["notices"]?.try do |value|
        Notices.new(
          value["shardbox"]?.try { |v| v == "true" } || false,
          value["crystaldoc"]?.try { |v| v == "true" } || false,
        )
      end

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
      @notices = notices || Notices.new(false, false)
      @presets = presets || Presets.new(nil, nil, nil, nil)
    end

    def save : Nil
      File.open(PATH, mode: "w") do |file|
        INI.build file, {
          notices: {
            shardbox:   @notices.shardbox?,
            crystaldoc: @notices.crystaldoc?,
          },
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
