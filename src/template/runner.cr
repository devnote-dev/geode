module Geode
  class Runner
    @script : String
    @output : IO
    @state : Lua::State
    getter? uses_shell : Bool = false

    def initialize(@script, @output)
      @state = Lua::State.new
      @state.open Lua::Library[:string, :table, :math]
    end

    def run_normal_env : Nil
      Lua.create_function @state, "print" do |args|
        @output.puts args
      end

      Lua.create_function @state, "current_dir" do |_|
        Dir.current
      end

      Lua.create_function @state, "dir_exists" do |path|
        Dir.exists? path.as_s
      end

      Lua.create_function @state, "dir_list" do |path|
        Dir.children path.as_s
      end

      Lua.create_function @state, "dir_make" do |path|
        Dir.mkdir_p path.as_s
        nil
      end

      Lua.create_function @state, "dir_remove" do |path, recurse|
        if recurse.as_bool?
          FileUtils.rm_rf path.as_s
        else
          Dir.delete path.as_s
        end
      end

      Lua.create_function @state, "run_command" do |command|
        Process.run(command.as_s).exit_code
      end

      @state.run_string @script
    end

    def run_test_env : Nil
      Lua.create_function @state, "dir_current" do |_|
        Dir.current
      end

      Lua.create_function @state, "run_command" do |_|
        @uses_shell = true
        0
      end

      @state.run_string @script
    end
  end
end
