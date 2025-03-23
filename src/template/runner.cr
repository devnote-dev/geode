module Lua
  class Runner
    @script : String
    @output : IO
    @state : Lua::State

    def initialize(@script, @output)
      @state = Lua::State.new
      @state.open :all
    end

    def load_normal_env : Nil
      Lua.create_function @state, "current_dir" do |_|
        Dir.current
      end

      Lua.create_function @state, "run_command" do |args|
        command, *rest = args.map(&.as_s) rescue raise "expected all string arguments to 'run_command'"
        Process.run(command, rest).exit_code
      end
    end

    def load_test_env : Nil
      Lua.create_function @state, "current_dir" do |_|
        Dir.current
      end

      Lua.create_function @state, "run_command" do |_|
        0
      end
    end

    def load_checks_env : Nil
      # TODO
    end

    def run : Nil
    end
  end
end
