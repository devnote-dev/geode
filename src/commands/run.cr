module Geode::Commands
  class Run < BaseCommand
    def setup : Nil
      @name = "run"
      @summary = "runs a script from shard.yml"
      @description = <<-DESC
        Runs a specified script from a shard.yml file. If target platforms are set for
        the script, the triple matching the host system will be used. This can be
        overriden by specifying the '--target' flag. There are also special 'linux' and
        'windows' targets that can be used to target Linux-based systems and Windows
        systems respectively. If there is no matching target triple for the host system
        and no override, the command will fail.

        The host triple for this platform is: #{Geode::HOST_TRIPLE}

        Available target triples:
        • aarch64-darwin
        • aarch64-linux-android
        • aarch64-linux-gnu
        • aarch64-linux-musl
        • arm-linux-gnueabihf
        • i386-linux-gnu
        • i386-linux-musl
        • wasm32-unknown-wasi
        • x86_64-darwin
        • x86_64-freebsd
        • x86_64-openbsd
        • x86_64-linux-gnu
        • x86_64-linux-musl
        • x86_64-unknown-dragonfly
        • x86_64-unknown-netbsd
        • x86_64-windows-msvc
        DESC

      add_usage "run [--target <name>] <script>"
      add_argument "script", description: "the name of the script", required: true
      add_option "target", description: "the target triple", type: :single, default: Geode::HOST_TRIPLE
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      shard = Shard.load_local
      if shard.scripts.empty?
        error "No scripts defined in shard.yml"
        system_exit
      end

      name = arguments.get("script").as_s
      keys = shard.scripts.keys.select &.starts_with? name
      if keys.empty?
        error "Unknown script '#{name}'"
        system_exit
      end

      target = options.get("target").as_s
      if keys.any? &.includes? '@'
        if key = keys.find &.ends_with? "@#{target}"
          run_script shard.scripts[key]
        elsif key = keys.find &.ends_with? {{ flag?(:win32) ? "@windows" : "@linux" }}
          run_script shard.scripts[key]
        elsif keys.includes? name
          run_script shard.scripts[name]
        else
          error "No script target for triple: #{target}"
          system_exit
        end
      else
        run_script shard.scripts[name]
      end
    rescue File::NotFoundError
      error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
    rescue ex : YAML::ParseException
      error ["Failed to parse shard.yml contents:", ex.to_s]
    end

    private def run_script(script : String) : Nil
      stdout << "» Running script: "
      stdout << '\n' if script.lines.size > 1
      stdout << script.colorize.light_gray << "\n\n"

      status : Process::Status
      taken : Time::Span
      err = IO::Memory.new
      start = Time.monotonic

      {% begin %}
        {% if flag?(:win32) %}begin{% end %}
          status = Process.run(script, shell: true, output: stdout, error: err)
          taken = Time.monotonic - start
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
        success "Completed in #{taken.milliseconds}ms"
      else
        error "Script '#{name}' failed (#{taken.milliseconds}ms):"
        stderr.puts err
      end
    end
  end
end
