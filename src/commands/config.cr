module Geode::Commands
  class Config < Base
    def setup : Nil
      @name = "config"
      @summary = "manage the geode config"

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
      stdout << "shardbox: " << config.notices.shardbox? << '\n'
      stdout << "crystaldoc: " << config.notices.crystaldoc? << "\n\n"

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
          fatal "System paths are not configurable"
        when "notices.shardbox"
          fatal "A value is required for this key" if value.nil?

          config.notices.shardbox = value.to_bool
        when "notices.crystaldoc"
          fatal "A value is required for this key" if value.nil?

          config.notices.crystaldoc = value.to_bool
        when "presets.author"
          config.presets.author = value.try &.as_s
        when "presets.url"
          config.presets.url = value.try &.as_s
        when "presets.license"
          config.presets.license = value.try &.as_s
        when "presets.vcs"
          config.presets.vcs = value.try &.as_s
        else
          fatal(
            "Unknown config key: #{key}",
            "See '#{"geode config --help".colorize.bold}' for available config keys",
          )
        end

        config.save
      rescue ArgumentError
        fatal "Expected value for '#{key}' to be a boolean, not a string"
      end
    end

    class Setup < Base
      def setup : Nil
        @name = "setup"
        @summary = "setup the geode config"

        add_option "force", description: "force override the existing config"
      end

      def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
        unless Dir.exists? Geode::Config::CACHE_DIR
          Dir.mkdir_p Geode::Config::CACHE_DIR
        end

        unless Dir.exists? Geode::Config::LIBRARY_DIR
          Dir.mkdir_p Geode::Config::LIBRARY_DIR
        end

        if options.has? "force"
          Geode::Config.new.save
        else
          begin
            Geode::Config.path
            warn "A config already exists", "Rerun with the '--force' flag to override"
          rescue
            Geode::Config.new.save
          end
        end
      end
    end
  end
end
