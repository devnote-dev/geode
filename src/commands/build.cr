module Geode::Commands
  class Build < BaseCommand
    def setup : Nil
      @name = "build"
      @summary = "builds one or more targets from shard.yml"
      @description = <<-DESC
        Builds one or more specified targets from a shard.yml file. If no targets are
        specified, the first target defined in the shard.yml file is chosen. The output
        of the build from the compiler can be logged by specifying the '--pipe' flag.
        You should avoid using this flag if you are building multiple targets as they
        are built concurrently, meaning that the output of the targets will be logged at
        the same time.
        DESC

      add_usage "build [-p|--pipe] [targets...]"
      add_argument "targets", description: "the targets to build", multiple: true
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

      pipe = options.has? "pipe"
      if targets = arguments.get?("targets").try &.as_set
        known, unknown = targets.partition { |t| shard.targets.has_key? t }
        unless unknown.empty?
          warn ["Skipping unknown targets:", unknown.join(", ")]
        end

        warn "Output piping is not recommended for multiple targets" if pipe && known.size > 1

        wait = Channel(Nil).new
        count = 0

        known.each do |name|
          target = shard.targets[name]
          unless target.has_key? "main"
            error "Target '#{name}' missing field 'main'; skipping"
            next
          end

          stdout.puts "» Building: #{name}"
          count += 1

          spawn do
            build name, target["main"], target["args"]?, pipe
            wait.send nil
          end
        end

        count.times { wait.receive }
      else
        name, target = shard.targets.first
        unless target.has_key? "main"
          error "Missing 'main' field for target: #{name}"
          system_exit
        end

        stdout.puts "» Building: #{name}"
        build name, target["main"], target["args"]?, pipe
      end
    rescue File::NotFoundError
      error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
    rescue ex : YAML::ParseException
      error ["Failed to parse shard.yml contents:", ex.to_s]
    end

    private def build(name : String, main : String, args : String?, pipe : Bool) : Nil
      err = IO::Memory.new
      command = ["build", "-o", (Path["bin"] / name).to_s, main]
      if extra = args
        command.concat extra.split
      end

      start = Time.monotonic
      status = Process.run("crystal", command, output: pipe ? stdout : Process::Redirect::Close, error: err)
      taken = format(Time.monotonic - start)

      if status.success?
        success "Target '#{name}' built in #{taken}"
      else
        error "Target '#{name}' failed (#{taken}):"
        stderr.puts err
      end
    end

    private def format(time : Time::Span) : String
      String.build do |io|
        unless time.hours.zero?
          io << time.hours << 'h'
        end

        unless time.minutes.zero?
          io << time.minutes << 'm' << ' '
        end

        unless time.seconds.zero?
          io << time.seconds << 's' << ' '
        end

        unless time.milliseconds.zero?
          io << time.milliseconds << "ms"
        end
      end
    end
  end
end
