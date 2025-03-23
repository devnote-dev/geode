module Geode::Commands
  class Watch < Base
    def setup : Nil
      @name = "watch"
      @summary = "build and watch a target from shard.yml"
      @description = <<-DESC
        Builds a target from a local shard.yml file. This defaults to the first defined
        target if none is specified. The 'src' directory will be checked at an interval
        period (default is 0.5 seconds) which can be changed specifying the '--interval'
        flag. By default the process output stream for the executed target is not piped
        to the program output, this can be overriden by specifying the '--pipe' flag.
        Note that process error stream is always piped to the program output.
        DESC

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
      fatal "No targets defined in shard.yml" if shard.targets.empty?
      Dir.mkdir_p "bin"

      name = arguments.get?("target").try(&.as_s) || shard.targets.first_key
      fatal "Unknown target '#{name}'" unless target = shard.targets[name]?
      fatal "Missing 'main' field for target: #{name}" unless target.has_key? "main"

      begin
        interval = options.get("interval").to_f64.seconds
      rescue
        fatal "Could not parse interval (must be a number)"
      end

      unless old_stamps = get_timestamps
        fatal "No Crystal files found to watch"
      end

      dry = options.has? "dry"
      pipe = options.has? "pipe"
      err = IO::Memory.new
      proc = uninitialized Process

      should_build = if options.has?("skip-start")
                       false
                     elsif options.has?("check-start")
                       !(File::Info.executable?(Path["bin", name]) ||
                         File::Info.executable?(Path["bin", name + ".exe"]))
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

      info "Waiting for file changes..."

      sig = Channel(Int32).new
      Process.on_terminate do |_|
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
            sig.send (new_stamps - old_stamps).size
            old_stamps.concat new_stamps
          end
        end
      end

      loop do
        break unless count = sig.receive?
        if proc.exists?
          puts if pipe
          info "Cancelling build"
          proc.terminate
        end

        spawn do
          info "Rebuilding (#{count} file change#{"s" if count > 1})"
          proc = new_process name, target["main"], target["flags"]?, dry, pipe, err
          start = Time.monotonic
          status = proc.wait
          taken = format_time(Time.monotonic - start)

          if status.success?
            success "Target rebuilt in #{taken}"
            info "Waiting for file changes..."
          elsif status.normal_exit?
            stderr.puts err
            error "Target failed (#{taken})"
            info "Waiting for file changes..."
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
