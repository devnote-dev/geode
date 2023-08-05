module Geode::Commands
  class Config < BaseCommand
    def setup : Nil
      @name = "config"
      @summary = "manages the geode config"

      add_usage "config set <key> <value>"
      add_usage "config setup"
      add_command Setup.new
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      config = Geode::Config.load

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
