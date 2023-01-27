require "cling"
require "colorize"

Colorize.on_tty_only!

module Geode
  VERSION = "0.1.0"

  class CLI < Cling::Command
    def setup : Nil
      @name = "app"
    end

    def help_template : String
      <<-TEXT
      #{"Geode".colorize.magenta} ❖  #{"A Crystal Build Tool".colorize.light_magenta}

      #{"Options".colorize.magenta}
      »  -h, --help  sends help information
      TEXT
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      stdout.puts help_template
    end
  end
end
