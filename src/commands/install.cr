module Geode::Commands
  class Install < Base
    def setup : Nil
      @name = "install"
      @summary = "install dependencies from shard.yml"
      @description = <<-DESC
        Installs dependencies from a shard.yml file. This includes development dependencies
        unless you specify the '--production' flag.
        DESC

      add_usage "install [-D|--without-development] [-E|--skip-executables] [--frozen]" \
                "\n\t[-j|--jobs <n>] [--local] [--production] [-P|--skip-postinstall]"

      add_option 'D', "without-development"
      add_option 'E', "skip-executables"
      add_option "frozen"
      add_option 'j', "jobs", type: :single
      add_option "local"
      add_option "production"
      add_option 'P', "skip-postinstall"
      # add_option 'S', "shard"
    end

    def pre_run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      if options.has? "jobs"
        unless options.get("jobs").to_i32?
          fatal "Expected flag 'jobs' to be an integer, not a string"
        end
      end

      nodev = options.has? "without-development"
      frozen = options.has? "frozen"
      production = options.has? "production"
      return unless (nodev || frozen) && production

      flags = [] of String
      flags << "without-development" if nodev
      flags << "frozen" if frozen

      warn(
        "Unnecessary flag#{"s" if nodev && frozen} specified:",
        "production",
        %(  ↳ implies #{flags.join " and "}),
      )
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      ensure_local_shard!

      reader, writer = IO.pipe(write_blocking: true)
      Shards::Log.backend = ::Log::IOBackend.new writer

      if options.has? "production"
        Shards.frozen = true
        Shards.with_development = false
      else
        Shards.frozen = options.has? "frozen"
        Shards.with_development = !options.has?("without-development")
      end

      Shards.skip_executables = options.has? "skip-executables"
      Shards.jobs = options.get("jobs").to_i32 if options.has?("jobs")
      Shards.local = options.has? "local"
      Shards.skip_postinstall = options.has? "skip-postinstall"

      spawn do
        while input = reader.gets
          if input.includes? "Fetching"
            stdout << "• " << input.split("Fetching ")[1] << '\n'
          end
        end
      end

      start = Time.monotonic
      Shards::Commands::WrapInstall.new(stdout, stderr).run
      Fiber.yield

      success "Install completed in #{format_time(Time.monotonic - start)}"
    end

    private def run_postinstall(name : String, script : String) : Nil
      stdout << "» Running " << name << " postinstall (" << Geode::HOST_PLATFORM << "):\n"
      stdout << script.colorize.light_gray << "\n\n"

      status : Process::Status
      taken : String
      start = Time.monotonic

      {% begin %}
        {% if flag?(:win32) %}begin{% end %}
          status = Process.run(script, shell: true, chdir: Path["lib"] / name, output: stdout, error: stderr)
          taken = format_time(Time.monotonic - start)
        {% if flag?(:win32) %}
          rescue ex : File::NotFoundError
            error(
              "Failed to start process for script:",
              ex.to_s,
            )
            return
          end
        {% end %}
      {% end %}

      if status.success?
        success "Script completed in #{taken}"
      else
        error "Script '#{name}' failed (#{taken})"
      end
    end
  end
end
