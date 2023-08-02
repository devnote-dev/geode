module Geode::Commands
  abstract class BaseCommand < Cling::Command
    def initialize
      super

      @inherit_options = true
      add_option "no-color", description: "disable ansi color formatting"
      add_option 'h', "help", description: "get help information"
    end

    def help_template : String
      Commands.format_command self
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

    def on_error(ex : Exception)
      case ex
      when Cling::CommandError
        error [ex.to_s, "See '#{"geode --help".colorize.bold}' for more information"]
      when Cling::ExecutionError
        on_invalid_option ex.to_s
      when SystemExit
        raise ex
      else
        error [
          "Unexpected exception:",
          ex.to_s,
          "Please report this on the Geode GitHub issues:",
          "https://github.com/devnote-dev/geode/issues",
        ]
      end
    end

    def on_missing_arguments(args : Array(String))
      format = if args.size > 1
                 args[..-2].join(", ") + " and " + args.last
               else
                 args[0]
               end

      command = "geode #{self.name} --help".colorize.bold
      error [
        "Missing required argument#{"s" if args.size > 1} for this command:",
        format,
        "See '#{command}' for more information",
      ]
      system_exit
    end

    def on_unknown_arguments(args : Array(String))
      format = if args.size > 1
                 args[..-2].join(", ") + " and " + args.last
               else
                 args[0]
               end

      command = %(geode #{self.name == "app" ? "" : self.name + " "}--help).colorize.bold
      error [
        "Unexpected argument#{"s" if args.size > 1} for this command:",
        format,
        "See '#{command}' for more information",
      ]
      system_exit
    end

    def on_invalid_option(message : String)
      command = "geode #{self.name} --help".colorize.bold
      error [message, "See '#{command}' for more information"]
      system_exit
    end

    def on_unknown_options(options : Array(String))
      format = if options.size > 1
                 options[..-2].join(", ") + " and " + options.last
               else
                 options[0]
               end

      command = %(geode #{self.name == "app" ? "" : self.name + " "}--help).colorize.bold
      error [
        "Unexpected option#{"s" if options.size > 1} for this command:",
        format,
        "See '#{command}' for more information",
      ]
      system_exit
    end

    protected def success(msg : String) : Nil
      stdout << "» Success".colorize.green << ": " << msg << '\n'
    end

    protected def warn(msg : String) : Nil
      stdout << "» Warning".colorize.yellow << ": " << msg << '\n'
    end

    protected def warn(args : Array(String)) : Nil
      stdout << "» Warning".colorize.yellow << ": " << args[0] << '\n'
      args[1..].each { |arg| stdout << "»  ".colorize.yellow << arg << '\n' }
    end

    protected def error(msg : String) : Nil
      stderr << "» Error".colorize.red << ": " << msg << '\n'
    end

    protected def error(args : Array(String)) : Nil
      stderr << "» Error".colorize.red << ": " << args[0] << '\n'
      args[1..].each { |arg| stderr << "»  ".colorize.red << arg << '\n' }
    end

    protected def system_exit : NoReturn
      raise SystemExit.new
    end
  end
end
