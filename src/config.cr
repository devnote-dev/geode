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

    PATH = CACHE_DIR / "config.ini"

    class Error < Exception
      enum Code
        NotFound
        ParseException
      end

      getter code : Code

      def initialize(@code, @message = nil)
      end
    end

    private class Metrics
      property? enabled : Bool
      property? push : Bool

      def initialize(@enabled, @push)
      end
    end

    private class Templates
      property author : String?
      property url : String?
      property license : String?
      property vcs : String?
      property vcs_fallback : String?

      def initialize(@author, @url, @license, @vcs, @vcs_fallback)
      end
    end

    property notices : Hash(String, Bool)
    property metrics : Metrics
    property templates : Templates

    def self.load : self
      data = INI.parse File.read PATH

      notices = data["notices"]?.try &.transform_values { |v| v == "true" }
      metrics = data["metrics"]?.try do |value|
        enabled = value["enabled"]?.try { |v| v == "true" } || false
        push = value["push"]?.try { |v| v == "true" } || false

        Metrics.new enabled, push
      end

      templates = data["templates"]?.try do |value|
        Templates.new(
          value["author"]?,
          value["url"]?,
          value["license"]?,
          value["vcs"]?,
          value["vcs-fallback"]?
        )
      end

      new notices, metrics, templates
    rescue File::NotFoundError
      raise Error.new :not_found
    rescue ex : INI::ParseException
      raise Error.new :parse_exception, ex.to_s
    end

    def initialize(notices, metrics, templates)
      @notices = notices || {} of String => Bool
      @metrics = metrics || Metrics.new false, false
      @templates = templates || Templates.new(nil, nil, nil, nil, nil)
    end

    def save : Nil
      File.open(PATH, mode: "w") do |file|
        INI.build file, {
          notices: @notices,
          metrics: {
            enabled: @metrics.enabled?,
            push:    @metrics.push?,
          },
          templates: {
            author:         @templates.author,
            url:            @templates.url,
            license:        @templates.license,
            vcs:            @templates.vcs,
            "vcs-fallback": @templates.vcs_fallback,
          },
        }
      end
    end
  end
end
