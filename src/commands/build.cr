module Geode::Commands
  class Build < BaseCommand
    def setup : Nil
      @name = "build"
      @summary = "builds one or more targets from shard.yml"
      @description = <<-DESC
        Builds one or more specified targets from a shard.yml file. If no targets are
        specified, the first target defined in the shard.yml file is chosen.
        DESC

      add_usage "build [-C|--no-check] [targets...]"
      add_argument "targets", description: "the targets to build", multiple: true
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

      if targets = arguments.get?("targets").try &.as_set
        known, unknown = targets.partition { |t| shard.targets.has_key? t }
        unless unknown.empty?
          warn ["Skipping unknown targets:", unknown.join(", ")]
        end

        wait = Channel(Nil).new
        count = 0

        known.each do |name|
          target = shard.targets[name]
          unless target.has_key? "main"
            error "Target '#{name}' missing field 'main'; skipping"
            next
          end

          stdout.puts "Building: #{name}"
          count += 1

          spawn do
            build name, target["main"]
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

        stdout.puts "Building: #{name}"
        build name, target["main"]
      end
    rescue File::NotFoundError
      error [
        "A shard.yml file was not found",
        "Run '#{"geode init".colorize.bold}' to initialize one",
      ]
    rescue ex : YAML::ParseException
      error [
        "Failed to parse shard.yml contents:",
        ex.to_s,
      ]
    end

    # TODO: include target args
    private def build(name : String, main : String) : Nil
      err = IO::Memory.new
      start = Time.monotonic
      status = Process.run("crystal", ["build", "-o", (Path["bin"] / name).to_s, main], error: err)
      taken = Time.monotonic - start

      if status.success?
        success "Target '#{name}' built in #{taken.milliseconds}ms"
      else
        error "Target '#{name}' failed (#{taken.milliseconds}):"
        stderr.puts err
      end
    end
  end
end
