module Geode::Commands
  class Run < Base
    def setup : Nil
      @name = "run"
      @summary = "runs a script from shard.yml"
      @description = <<-DESC
        Runs a specified script from a shard.yml file. If target platforms are set for
        the script, the triple matching the host system will be used. This can be
        overriden by specifying the '--target' flag. There are also special 'linux' and
        'windows' group targets that can be used to target Linux-based systems and
        Windows systems respectively. If there is no matching target triple for the host
        system and no override, the command will fail.

        The host triple for this platform is: #{Geode::HOST_TRIPLE}

        Available target groups and triples:

        macos:
        • aarch64-darwin
        • x86_64-darwin

        linux:
        • aarch64-linux-gnu
        • aarch64-linux-musl
        • i386-linux-gnu
        • i386-linux-musl
        • x86_64-linux-gnu
        • x86_64-linux-musl

        other (not used as a target group):
        • aarch64-linux-android
        • arm-linux-gnueabihf
        • x86_64-freebsd
        • x86_64-openbsd
        • x86_64-unknown-dragonfly
        • x86_64-unknown-netbsd
        • wasm32-unknown-wasi

        windows:
        • x86_64-windows-msvc
        • x86_64-pc-windows-msvc
        DESC

      add_usage "run [--target <name>] <script>"
      add_argument "script", description: "the name of the script", required: true
      add_option "target", description: "the target triple", type: :single
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      shard = Shard.load_local
      if shard.scripts.empty?
        error "No scripts defined in shard.yml"
        system_exit
      end

      name = arguments.get("script").as_s
      unless shard.scripts.keys.any? &.starts_with? name
        error "Unknown script '#{name}'"
        system_exit
      end

      if target = options.get?("target").try &.as_s
        script = shard.find_target_script name, target
      else
        target = Geode::HOST_PLATFORM
        script = shard.find_target_script name, target
      end

      unless script
        error "No script available for target: #{target}"
        system_exit
      end

      run_script script
    end

    private def run_script(script : String) : Nil
      stdout << "» Running script: "
      stdout << '\n' if script.lines.size > 1
      stdout << script.colorize.light_gray << "\n\n"

      status : Process::Status
      taken : String
      start = Time.monotonic

      {% begin %}
        {% if flag?(:win32) %}begin{% end %}
          status = Process.run(script, shell: true, output: stdout, error: stderr)
          taken = format_time(Time.monotonic - start)
        {% if flag?(:win32) %}
          rescue ex : File::NotFoundError
            error [
              "Failed to start process for script:",
              ex.to_s,
              "If you are using command prompt builtins or extensions,",
              "make sure the script is prefixed with 'cmd.exe /C'",
            ]
            system_exit
          end
        {% end %}
      {% end %}

      if status.success?
        success "Completed in #{taken}"
      else
        error "Script '#{name}' failed (#{taken})"
      end
    end
  end
end
