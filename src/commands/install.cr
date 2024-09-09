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
      add_option 'F', "file", type: :single, default: "shard.yml"
      add_option "frozen"
      add_option 'j', "jobs", type: :single
      add_option "local"
      add_option "production"
      add_option 'P', "skip-postinstall"
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

      shard = Shard.load options.get("file").as_s
      start = Time.monotonic
      info "Resolving dependencies"

      shard.dependencies.each do |name, dep|
        begin
          dep.validate!
        rescue ex : Shard::Error
          case ex.code
          when .no_resolver?
            error "No source set for '#{name}'; cannot install"
          when .dup_resolver?
            error "Multiple sources set for '#{name}'", "Pick one and try again"
          when .version_conflict?
            error "Cannot specify version with branch or commit for '#{name}'"
          end
          next
        end

        resolver = Resolvers.get_for_package dep
        stdout << "• " << resolver.uri << '\n'

        if dep.version
          resolver.get_versions.reverse_each do |tag|
            begin
              resolver.validate tag
            rescue ex : Resolvers::Base::Error
              case ex.code
              when .command_failed?
                warn(
                  "No shard.yml file found for '#{name}' on version #{tag}",
                  "Trying next version"
                )
              when .name_mismatch?
                warn(
                  "Mismatched names for shard '#{name}' on version #{tag}",
                  "Trying next version"
                )
              end
              next
            rescue Shard::Error
              warn(
                "Failed to parse shard.yml for '#{name}' on version #{tag}",
                "Trying next version"
              )
              next
            end

            if resolver.installed? tag
              info "Using #{name} (#{tag})"
              break
            else
              begin
                resolver.install tag, Path[Dir.current, "lib", tag].to_s
                break
              rescue ex : Resolvers::Base::Error
                # TODO
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
