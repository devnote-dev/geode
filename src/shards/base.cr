module Geode
  class WrapBase < Shards::Command
    @stdout : IO
    @stderr : IO

    def initialize(@stdout : IO, @stderr : IO)
      super Dir.current
    end

    protected def puts : Nil
      @stdout.puts
    end

    protected def puts(msg : String) : Nil
      @stdout.puts msg
    end

    protected def info(msg : String) : Nil
      @stdout << "» " << msg << '\n'
    end

    protected def success(msg : String) : Nil
      @stdout << "» Success".colorize.green << ": " << msg << '\n'
    end

    protected def warn(msg : String) : Nil
      @stdout << "» Warning".colorize.yellow << ": " << msg << '\n'
    end

    protected def warn(*args : String) : Nil
      @stdout << "» Warning".colorize.yellow << ": " << args[0] << '\n'
      args[1..].each { |arg| @stdout << "»  ".colorize.yellow << arg << '\n' }
    end

    protected def error(msg : String) : Nil
      @stderr << "» Error".colorize.red << ": " << msg << '\n'
    end

    protected def error(*args : String) : Nil
      @stderr << "» Error".colorize.red << ": " << args[0] << '\n'
      args[1..].each { |arg| @stderr << "»  ".colorize.red << arg << '\n' }
    end

    protected def fatal(*args : String) : NoReturn
      error *args
      raise Cling::ExitProgram.new 1
    end
  end
end
