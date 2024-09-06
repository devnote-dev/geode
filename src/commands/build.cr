module Geode::Commands
  class Build < Base
    def setup : Nil
      @name = "build"
      @summary = "builds one or more targets from shard.yml"
      @description = <<-DESC
        Builds one or more specified targets from a shard.yml file. If no targets are
        specified, all defined targets will be built concurrently. The output of the
        build from the compiler can be logged by specifying the '--pipe' flag. Note that
        this flag is automatically disabled when building multiple targets because of
        output log conficts.
        DESC

      add_usage "build [--dry] [-p|--pipe] [targets...]"
      add_argument "targets", description: "the targets to build", multiple: true
      add_option "dry", description: "build as a dry-run (does not create a new binary)"
      add_option 'p', "pipe", description: "pipe the build output"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      shard = Shard.load_local
      fatal "No targets defined in shard.yml" if shard.targets.empty?
      Dir.mkdir_p "bin"

      if targets = arguments.get?("targets").try &.as_set
        targets, unknown = targets.partition { |t| shard.targets.has_key? t }
        unless unknown.empty?
          warn "Skipping unknown targets:", unknown.join(", ")
        end
      else
        targets = shard.targets.keys
      end

      dry = options.has? "dry"
      pipe = options.has? "pipe"
      if targets.size > 1 && pipe
        warn "Output piping is disabled for multiple targets"
        pipe = false
      end

      wg = WaitGroup.new

      targets.each do |name|
        target = shard.targets[name]
        unless target.has_key? "main"
          error "Target '#{name}' missing field 'main'; skipping"
          next
        end

        info "Building: #{name}"

        wg.add
        spawn do
          build name, target["main"], target["flags"]?, dry, pipe
          wg.done
        end
      end

      wg.wait
    end

    private def build(name : String, main : String, flags : String?, dry : Bool, pipe : Bool) : Nil
      command = ["build", "-o", (Path["bin"] / name).to_s, main]
      command << "--no-codegen" if dry
      command.concat flags.split if flags

      start = Time.monotonic
      status = Process.run(
        "crystal",
        command,
        output: pipe ? stdout : Process::Redirect::Close,
        error: pipe ? stderr : (err = IO::Memory.new)
      )
      taken = format_time(Time.monotonic - start)

      if status.success?
        success "Target '#{name}' built in #{taken}"
      else
        unless pipe
          stderr << '\n' << err << '\n'
        end
        error "Target '#{name}' failed (#{taken})"
      end
    end
  end
end
