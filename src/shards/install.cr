module Shards::Commands
  class WrapInstall < Geode::WrapBase
    def run : Nil
      if Shards.frozen? && !lockfile?
        fatal "A shard.lock file was not found (needed for frozen install)"
      end

      check_symlink_privilege
      info "Resolving dependencies"

      solver = MolinilloSolver.new(spec, override)
      solver.locks = locks.shards if lockfile?

      solver.prepare(development: Shards.with_development?)
      packages = handle_resolver_errors { solver.solve }

      validate packages if Shards.frozen?
      install packages

      if generate_lockfile? packages
        write_lockfile packages
      elsif !Shards.frozen?
        File.touch lockfile_path
      end

      touch_install_path
      check_crystal_version packages
    end

    private def validate(packages)
      packages.each do |package|
        if lock = locks.shards.find { |d| d.name == package.name }
          if lock.resolver != package.resolver
            fatal "#{package.name} source changed"
          else
            validate_locked_version(package, lock.version)
          end
        else
          fatal "Can't install new dependency #{package.name} in production"
        end
      end
    end

    private def validate_locked_version(package, version)
      return if package.version == version
      fatal "#{package.name} requirements changed"
    end

    private def install(packages : Array(Package))
      # packages are returned by the solver in reverse topological order,
      # so transitive dependencies are installed first
      packages.each do |package|
        # first install the dependency:
        next unless install package

        # then execute the postinstall script
        # (with access to all transitive dependencies):
        package.postinstall

        # always install executables because the path resolver never actually
        # installs dependencies:
        package.install_executables
      end
    end

    private def install(package : Package)
      if package.installed?
        @stdout << "= ".colorize.blue << package.name << " (" << package.report_version << ")\n"
        return
      end

      @stdout << "+ ".colorize.green << package.name << " (" << package.report_version << ")\n"
      package.install
      package
    end

    private def generate_lockfile?(packages)
      !Shards.frozen? && (!lockfile? || outdated_lockfile?(packages))
    end

    private def outdated_lockfile?(packages)
      return true if locks.version != Shards::Lock::CURRENT_VERSION
      return true if packages.size != locks.shards.size

      packages.index_by(&.name) != locks.shards.index_by(&.name)
    end
  end
end
