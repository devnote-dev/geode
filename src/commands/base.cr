module Geode::Commands
  abstract class Base < Cling::Command
    def initialize
      super

      @inherit_options = true
      add_option "no-color", description: "disable ansi color formatting"
      add_option 'h', "help", description: "get help information"
    end

    def help_template : String
      Commands.format_command self
    end

    def pre_run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      Colorize.enabled = false if options.has? "no-color"

      if options.has? "help"
        stdout.puts help_template
        exit_program 0
      end
    end

    def on_error(ex : Exception)
      case ex
      when Cling::CommandError
        error [ex.to_s, "See '#{"geode --help".colorize.bold}' for more information"]
      when Cling::ExecutionError
        on_invalid_option ex.to_s
      when Geode::Config::Error
        case ex.code
        in .not_found?
          error [
            "Config not found",
            "Location: #{Geode::Config::PATH}",
            "Run '#{"geode config setup".colorize.bold}' to get started",
          ]
        in .parse_exception?
          error ["Failed to parse config:", ex.message.as(String)]
        end
      when Geode::Shard::Error
        case ex.code
        in .not_found?
          error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
        in .parse_exception?
          error ["Failed to parse shard.yml contents:", ex.message.as(String)]
        end
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
      exit_program
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
      exit_program
    end

    def on_invalid_option(message : String)
      command = "geode #{self.name} --help".colorize.bold
      error [message, "See '#{command}' for more information"]
      exit_program
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
      exit_program
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

    protected def format_time(time : Time::Span) : String
      String.build do |io|
        unless time.hours.zero?
          io << time.hours << 'h'
        end

        unless time.minutes.zero?
          io << time.minutes << 'm' << ' '
        end

        unless time.seconds.zero?
          io << time.seconds << 's' << ' '
        end

        unless time.milliseconds.zero?
          io << time.milliseconds << "ms"
        end
      end
    end
  end
end
