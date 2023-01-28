require "cling"
require "colorize"
require "yaml"

require "./commands/*"
require "./package"

Colorize.on_tty_only!

module Geode
  VERSION = "0.1.0"
  BUILD = "dev"

  class CLI < Commands::BaseCommand
    def setup : Nil
      @name = "app"
      @header = %(#{"❖  Geode".colorize.magenta}: #{"A Crystal Build Tool".colorize.light_magenta})

      add_command Commands::Version.new
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      stdout.puts help_template
    end
  end
end
