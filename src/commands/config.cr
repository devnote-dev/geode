module Geode::Commands
  class Config < BaseCommand
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
      stdout << "library: " << Geode::Config::LIBRARY_DIR << '\n'
      stdout << "location: " << Geode::Config::PATH << "\n\n"

      stdout << "notices\n".colorize.bold
      stdout << "shardbox: " << (config.notices["shardbox"]? || false) << "\n\n"

      stdout << "metrics\n".colorize.bold
      stdout << "enabled: " << config.metrics.enabled? << '\n'
      stdout << "push: " << config.metrics.push? << "\n\n"

      stdout << "templates\n".colorize.bold
      stdout << "author: " << config.templates.author << '\n'
      stdout << "url: " << config.templates.url << '\n'
      stdout << "license: " << config.templates.license << '\n'
      stdout << "vcs: " << config.templates.vcs << '\n'
      stdout << "vcs-fallback: " << config.templates.vcs_fallback << '\n'
    end

    class Set < BaseCommand
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
        when "system.cache", "system.library", "system.location"
          error "System paths are not configurable"
          system_exit
        when "notices.shardbox"
          if value.nil?
            error "A value is required for this key"
            system_exit
          end

          config.notices["shardbox"] = value.as_bool
        when "metrics.enabled"
          if value.nil?
            error "A value is required for this key"
            system_exit
          end

          config.metrics.enabled = value.as_bool
        when "metrics.push"
          if value.nil?
            error "A value is required for this key"
            system_exit
          end

          config.metrics.push = value.as_bool
        when "templates.author"
          config.templates.author = value.try &.as_s
        when "templates.url"
          config.templates.url = value.try &.as_s
        when "templates.license"
          config.templates.license = value.try &.as_s
        when "templates.vcs"
          config.templates.vcs = value.try &.as_s
        when "templates.vcs-fallback"
          config.templates.vcs_fallback = value.try &.as_s
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
      end
    end

    class Setup < BaseCommand
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

        unless File.exists? Geode::Config::PATH
          Geode::Config.new(nil, nil, nil).save
        end
      end
    end
  end
end
