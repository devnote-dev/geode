module Geode::Commands
  abstract class BaseCommand < Cling::Command
    def initialize
      super

      @inherit_options = true
      add_option "no-color", description: "disable ansi color formatting"
      add_option 'h', "help", description: "get help information"
    end

    def help_template : String
      <<-TEXT
      #{"❖  Geode".colorize.magenta}: #{"A Crystal Build Tool".colorize.light_magenta}

      #{"Commands".colorize.magenta}
      »  version    Sends version information about Geode

      #{"Options".colorize.magenta}
      »  -h, --help  sends help information
      TEXT
    end

    def pre_run(arguments : Cling::Arguments, options : Cling::Options) : Bool
      Colorize.enabled = false if options.has? "no-color"

      if options.has? "help"
        stdout.puts help_template

        false
      else
        true
      end
    end

    def on_unknown_arguments(args : Array(String))
      stderr.puts %(#{"❖".colorize.red}  Unexpected argument#{"s" if args.size > 1} for this command:)
      if args.size > 1
        stderr.puts %(#{"»".colorize.red}  #{args[..-2].join ", "} and #{args.last})
      else
        stderr.puts %(#{"»".colorize.red}  #{args.first})
      end

      command = %(geode #{self.name == "app" ? "" : self.name + " "}--help).colorize.light_magenta
      stderr.puts "\nSee '#{command}' for more information"
      exit 1
    end

    def on_unknown_options(options : Array(String))
      stderr.puts %(#{"❖".colorize.red}  Unexpected option#{"s" if options.size > 1} for this command:)
      if options.size > 1
        stderr.puts %(#{"»".colorize.red}  #{options[..-2].join ", "} and #{options.last})
      else
        stderr.puts %(#{"»".colorize.red}  #{options.first})
      end

      command = %(geode #{self.name == "app" ? "" : self.name + " "}--help).colorize.light_magenta
      stderr.puts "\nSee '#{command}' for more information"
      exit 1
    end
  end
end
