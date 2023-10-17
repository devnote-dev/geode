module Geode::Commands
  class Config < Base
    def setup : Nil
      @name = "config"
      @summary = "manages the geode config"

      add_usage "config set <key> <value>"
      add_usage "config setup"
      add_command Set.new
      add_command Setup.new
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      config = Geode::Config.load

      stdout << "system\n".colorize.bold
      stdout << "cache: " << Geode::Config::CACHE_DIR << '\n'
      stdout << "library: " << Geode::Config::LIBRARY_DIR << "\n\n"

      stdout << "notices\n".colorize.bold
      stdout << "shardbox: " << (config.notices["shardbox"]? || false) << "\n\n"

      stdout << "presets\n".colorize.bold
      stdout << "author: " << config.presets.author << '\n'
      stdout << "url: " << config.presets.url << '\n'
      stdout << "license: " << config.presets.license << '\n'
      stdout << "vcs: " << config.presets.vcs << '\n'
    end

    class Set < Base
      def setup : Nil
        @name = "set"
        @summary = "sets a key in the config"

        add_usage "config set <key> <value>"
        add_argument "key", description: "the key in the config", required: true
        add_argument "value", description: "the value to set"
      end

      def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
        config = Geode::Config.load
        key = arguments.get("key").as_s
        value = arguments.get?("value")

        case key
        when "system.cache", "system.library"
          error "System paths are not configurable"
          system_exit
        when "notices.shardbox"
          if value.nil?
            error "A value is required for this key"
            system_exit
          end

          config.notices["shardbox"] = value.as_bool
        when "presets.author"
          config.presets.author = value.try &.as_s
        when "presets.url"
          config.presets.url = value.try &.as_s
        when "presets.license"
          config.presets.license = value.try &.as_s
        when "presets.vcs"
          config.presets.vcs = value.try &.as_s
        else
          error [
            "Unknown config key: #{key}",
            "See '#{"geode config --help".colorize.bold}' for available config keys",
          ]
          system_exit
        end

        config.save
      rescue TypeCastError
        error "Expected key '#{key}' to be a boolean, not a string"
        system_exit
      end
    end

    class Setup < Base
      def setup : Nil
        @name = "setup"
        @summary = "setup the geode config"
      end

      def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
        unless Dir.exists? Geode::Config::CACHE_DIR
          Dir.mkdir_p Geode::Config::CACHE_DIR
        end

        unless Dir.exists? Geode::Config::LIBRARY_DIR
          Dir.mkdir_p Geode::Config::LIBRARY_DIR
        end

        if File.exists? Geode::Config::PATH
          begin
            _ = INI.parse File.read Geode::Config::PATH
          rescue INI::ParseException
            warn "Failed to parse config, setting to default"
            Geode::Config.new(nil, nil).save
          end
        else
          Geode::Config.new(nil, nil).save
        end
      end
    end
  end
end
