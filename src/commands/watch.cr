module Geode::Commands
  class Watch < BaseCommand
    def setup : Nil
      @name = "watch"
      @summary = "builds and watches a target from shard.yml"

      add_usage "watch [-p|--pipe] [target]"
      add_argument "target", description: "the name of the target"
      add_option 'p', "pipe", description: "pipes the build output"
    end

    {% if flag?(:watch_cmd) %}
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

        unless old_stamps = get_timestamps
          error "No Crystal files found to watch"
          system_exit
        end

        pipe = options.has? "pipe"
        stdout.puts "» Building: #{name}"
        build name, target["main"], target["args"]?, pipe
        stdout.puts "» Waiting for file changes..."

        # TODO: there should probably be some kind of semaphore for this
        sig = Channel(Int32).new
        spawn do
          loop do
            sleep 0.5

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
          if count = sig.receive?
            stdout.puts "» Rebuilding (#{count} file change#{"s" if count > 1})"
            build name, target["main"], target["args"]?, pipe
            stdout.puts "» Waiting for file changes..."
          else
            break
          end
        end
      rescue File::NotFoundError
        error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
      rescue ex : YAML::ParseException
        error ["Failed to parse shard.yml contents:", ex.to_s]
      end
    {% else %}
      def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
        error "This version of Geode was built without watch support"
      end
    {% end %}

    private def build(name : String, main : String, args : String?, pipe : Bool) : Nil
      err = IO::Memory.new
      command = ["build", "-o", (Path["bin"] / name).to_s, main]
      if extra = args
        command.concat extra.split
      end

      start = Time.monotonic
      status = Process.run("crystal", command, output: pipe ? stdout : Process::Redirect::Close, error: err)
      taken = format_time(Time.monotonic - start)

      if status.success?
        success "Target rebuilt in #{taken}"
      else
        error "Target failed (#{taken}):"
        stderr.puts err
      end
    end

    private def get_timestamps : Array(Int64)?
      files = Dir.glob("src/**/*").select &.ends_with? ".cr"
      return nil if files.empty?

      files.map { |path| File.info(path).modification_time.to_unix }
    end
  end
end
