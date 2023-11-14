module Geode::Commands
  class Watch < Base
    def setup : Nil
      @name = "watch"
      @summary = "builds and watches a target from shard.yml"

      add_usage "watch [-c|--check-start] [--dry] [-i|--interval <time>] [-p|--pipe] [-s|--skip-start] [target]"
      add_argument "target", description: "the name of the target"
      add_option 'c', "check-start", description: "check for the target executable at the start"
      add_option "dry", description: "build as a dry-run (does not create a new binary)"
      add_option 'i', "interval", description: "the wait interval in seconds", type: :single, default: 0.5
      add_option 'p', "pipe", description: "pipe the build output"
      add_option 's', "skip-start", description: "skip building at the start"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      shard = Shard.load_local
      if shard.targets.empty?
        error "No targets defined in shard.yml"
        system_exit
      end

      Dir.mkdir_p "bin"

      name = arguments.get?("target").try(&.as_s) || shard.targets.first_key
      unless target = shard.targets[name]?
        error "Unknown target '#{name}'"
        system_exit
      end

      unless target.has_key? "main"
        error "Missing 'main' field for target: #{name}"
        system_exit
      end

      begin
        interval = options.get("interval").as_f
      rescue
        error "Could not parse interval (must be a number)"
        system_exit
      end

      unless old_stamps = get_timestamps
        error "No Crystal files found to watch"
        system_exit
      end

      dry = options.has? "dry"
      pipe = options.has? "pipe"
      err = IO::Memory.new
      proc = Process.new "echo" # dummy process for variable access

      should_build = if options.has?("skip-start")
                       false
                     elsif options.has?("check-start")
                       !(File.executable?(Path["bin", name]) ||
                         File.executable?(Path["bin", name + ".exe"]))
                     else
                       true
                     end

      if should_build
        stdout.puts "» Building: #{name}"
        proc = new_process name, target["main"], target["flags"]?, dry, pipe, err
        start = Time.monotonic
        status = proc.wait
        taken = format_time(Time.monotonic - start)

        if status.success?
          success "Target built in #{taken}"
        else
          stderr.puts err
          error "Target failed (#{taken})"
        end
      end

      stdout.puts "» Waiting for file changes..."

      sig = Channel(Int32).new
      Process.on_interrupt do
        sig.close
        exit 1
      end

      spawn do
        loop do
          break if sig.closed?
          sleep interval

          unless new_stamps = get_timestamps
            sig.close
            break
          end

          unless old_stamps == new_stamps || new_stamps.all? &.in?(old_stamps)
            diff = (new_stamps - old_stamps).size
            sig.send diff
            old_stamps.concat new_stamps
          end
        end
      end

      loop do
        break unless count = sig.receive?
        if proc.exists?
          stdout.puts if pipe
          stdout.puts "» Cancelling build"
          proc.terminate
        end

        stdout.puts "» Rebuilding (#{count} file change#{"s" if count > 1})"
        proc = new_process name, target["main"], target["flags"]?, dry, pipe, err

        spawn do
          start = Time.monotonic
          status = proc.wait
          taken = format_time(Time.monotonic - start)

          if status.success?
            success "Target rebuilt in #{taken}"
            stdout.puts "» Waiting for file changes..."
          elsif status.normal_exit?
            stderr.puts err
            error "Target failed (#{taken})"
            stdout.puts "» Waiting for file changes..."
          end
        end
      end
    end

    private def get_timestamps : Array(Int64)?
      files = Dir.glob "src/**/*.cr"
      return nil if files.empty?

      files.map { |path| File.info(path).modification_time.to_unix }
    end

    private def new_process(name : String, main : String, flags : String?, dry : Bool,
                            pipe : Bool, err : IO::Memory) : Process
      command = ["build", "-o", (Path["bin"] / name).to_s, main]
      command << "--no-codegen" if dry
      command.concat flags.split if flags
      err.clear

      Process.new(
        "crystal",
        command,
        output: pipe ? stdout : Process::Redirect::Close,
        error: pipe ? stderr : err
      )
    end
  end
end
