module Geode::Commands
  class Run < Base
    def setup : Nil
      @name = "run"
      @summary = "run a script from shard.yml"
      @description = <<-DESC
        Runs a specified script from a local shard.yml file. You can also run a script
        from an installed shard by specifying the '--shard' flag. If target platforms
        are set for the script, the triple matching the host system will be used. This
        can be overriden by specifying the '--target' flag. There are also special
        'linux' and 'windows' group targets that can be used to target Linux-based
        systems and Windows systems respectively. If there is no matching target triple
        for the host system and no override, the command will fail.

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

      add_usage "run [--shard <name>] [--target <name>] <script>"
      add_argument "script", description: "the name of the script", required: true
      add_option "shard", description: "the name of the shard", type: :single
      add_option "target", description: "the target triple", type: :single
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      shard = Shard.load_local
      dir = Path.new Dir.current

      if options.has? "shard"
        name = options.get("shard").as_s

        if shard.dependencies.has_key? name
          if Shard.exists? name
            shard = Shard.load name
            dir = dir / "lib" / name
          else
            fatal "Shard '#{name}' is listed as a dependency but not installed"
          end
        elsif shard.development.has_key? name
          if Shard.exists? name
            shard = Shard.load name
            dir = dir / "lib" / name
          else
            fatal "Shard '#{name}' is listed as a development dependency but not installed"
          end
        elsif Shard.exists? name
          fatal "Shard '#{name}' is installed but not listed as a dependency"
        else
          fatal "Shard '#{name}' is not installed"
        end
      end

      fatal "No scripts defined in shard.yml" if shard.scripts.empty?
      name = arguments.get("script").as_s

      unless shard.scripts.keys.any? &.starts_with? name
        fatal "Unknown script '#{name}'"
      end

      if target = options.get?("target").try &.as_s
        script = shard.find_target_script name, target
      else
        target = Geode::HOST_PLATFORM
        script = shard.find_target_script name, target
      end

      fatal "No script available for target: #{target}" unless script
      run_script script, dir.to_s
    end

    private def run_script(script : String, dir : String) : Nil
      stdout << "» Running script: "
      stdout << '\n' if script.lines.size > 1
      stdout << script.colorize.light_gray << '\n'

      status : Process::Status
      taken : String
      start = Time.monotonic

      {% if flag?(:win32) %}
        begin
          temp = File.tempfile("geode-tmp-run", ".cmd") do |file|
            file << script
          end
          status = Process.run("cmd.exe", {"/Q", "/C", temp.path}, chdir: dir, output: stdout, error: stderr)
          taken = format_time(Time.monotonic - start)
        ensure
          temp.try &.delete
        end
      {% else %}
        status = Process.run(script, shell: true, chdir: dir, output: stdout, error: stderr)
        taken = format_time(Time.monotonic - start)
      {% end %}

      puts
      if status.success?
        success "Completed in #{taken}"
      else
        error "Script '#{name}' failed (#{taken})"
      end
    end
  end
end
