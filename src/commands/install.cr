module Geode::Commands
  class Install < Base
    def setup : Nil
      @name = "install"
      @summary = "install dependencies from shard.yml"
      @description = <<-DESC
        Installs dependencies from a shard.yml file. This includes development dependencies
        unless you include the '--production' flag.
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

      shards = Process.find_executable "shards"
      fatal(
        "Could not find the Shards executable",
        "(wrapped around for dependency resolution)",
      ) unless shards

      args = %w[install --skip-executables --skip-postinstall]
      args << "--frozen" if options.has? "frozen"
      args << "--no-color" if options.has? "no-color"
      if value = options.get?("jobs").try &.as_i
        args << "--jobs=#{value}"
      end
      args << "--local" if options.has? "local"
      args << "--production" if options.has? "production"
      args << "--without-development" if options.has? "without-development"

      start = Time.monotonic
      deps = [] of String

      Process.run(shards, args) do |proc|
        while message = proc.output.gets
          if message.includes?("Installing") || message.includes?("Using")
            deps << message.split(' ', 3)[1]
          end
          puts message
        end
        puts
      end

      if $?.success?
        if deps.empty? || (options.has?("skip-executables") && options.has?("skip-postinstall"))
          success "Install completed in #{format_time(Time.monotonic - start)}"
          return
        end
      else
        fatal "Install failed (#{format_time(Time.monotonic - start)})"
      end

      shards = [] of Shard
      Dir.each_child("lib") do |child|
        next if child.starts_with? '.'
        next unless Shard.exists? child

        shards << Shard.load child
      rescue YAML::ParseException
        warn "Failed to parse shard.yml contents for '#{child}'"
      end

      unless options.has? "skip-postinstall"
        shards.select(&.has_postinstall?).each do |shard|
          if script = shard.find_target_script "postinstall", Geode::HOST_PLATFORM
            run_postinstall shard.name, script
          else
            warn "No postinstall script available for this platform"
          end
        end
      end

      unless options.has? "skip-executables"
        Dir.mkdir_p "bin"

        shards.reject(&.executables.empty?).each do |shard|
          shard.executables.each do |exe|
            src = Path["lib"] / shard.name / "bin" / exe

            {% if flag?(:win32) %}
              unless File.exists?(src) || exe.ends_with?(".exe")
                src = Path[src.basename, exe + ".exe"]
              end
            {% end %}

            unless File.exists? src
              warn "Executable '#{exe}' not found for #{shard.name}"
              next
            end

            dest = Path["bin", exe].expand
            unless File.exists? dest
              begin
                File.copy src, dest
                info "Added executable '#{exe}'"
              rescue
                error "Failed to link #{shard.name} executable '#{exe}'"
              end
            end
          end
        end
      end

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
