module Geode::Commands
  class Watch < Base
    def setup : Nil
      @name = "watch"
      @summary = "builds and watches a target from shard.yml"

      add_usage "watch [-i|--interval <time>] [-p|--pipe] [target]"
      add_argument "target", description: "the name of the target"
      add_option 'i', "interval", description: "the wait interval in seconds", type: :single, default: 0.5
      add_option 'p', "pipe", description: "pipes the build output"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      shard = Shard.load_local
      if shard.targets.empty?
        error "No targets defined in shard.yml"
        system_exit
      end

      unless Dir.exists? "bin"
        begin
          Dir.mkdir "bin"
        rescue ex
          error ["Failed to create bin directory:", ex.to_s]
          system_exit
        end
      end

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

      stdout.puts "» Building: #{name}"
      pipe = options.has? "pipe"
      err = IO::Memory.new
      proc = new_process name, target["main"], target["args"]?, pipe, err
      start = Time.monotonic
      status = proc.wait
      taken = format_time(Time.monotonic - start)

      if status.success?
        success "Target built in #{taken}"
      else
        error "Target failed (#{taken}):"
        stderr.puts err
      end
      stdout.puts "» Waiting for file changes..."

      sig = Channel(Int32).new
      spawn do
        loop do
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
        proc = new_process name, target["main"], target["args"]?, pipe, err

        spawn do
          start = Time.monotonic
          status = proc.wait
          taken = format_time(Time.monotonic - start)

          if status.success?
            success "Target rebuilt in #{taken}"
            stdout.puts "» Waiting for file changes..."
          elsif status.normal_exit?
            error "Target failed (#{taken}):"
            stderr.puts err
            stdout.puts "» Waiting for file changes..."
          end
        end
      end
    rescue File::NotFoundError
      error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
    rescue ex : YAML::ParseException
      error ["Failed to parse shard.yml contents:", ex.to_s]
    end

    private def get_timestamps : Array(Int64)?
      files = Dir.glob "src/**/*.cr"
      return nil if files.empty?

      files.map { |path| File.info(path).modification_time.to_unix }
    end

    private def new_process(name : String, main : String, args : String?, pipe : Bool, err : IO::Memory) : Process
      command = ["build", "-o", (Path["bin"] / name).to_s, main]
      if extra = args
        command.concat extra.split
      end
      err.rewind

      Process.new("crystal", command, output: pipe ? stdout : Process::Redirect::Close, error: err)
    end
  end
end
