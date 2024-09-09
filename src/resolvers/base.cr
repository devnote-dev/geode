module Geode::Resolvers
  abstract class Base
    class Error < Exception
      enum Code
        CommandFailed
        NoResolver
        NoCLI
        NoVersions
        NameMismatch
      end

      getter code : Code

      def initialize(@code, @message = nil)
      end
    end

    getter uri : String
    getter dep : Dependency

    def initialize(@uri : String, @dep : Dependency)
    end

    abstract def get_versions : Array(String)
    abstract def validate(tag : String) : Nil
    abstract def install(tag : String, dest : String) : Nil

    protected def execute(command : String, dir : String = Dir.current) : String
      status = Process.run(
        command,
        shell: true,
        output: output = IO::Memory.new,
        error: error = IO::Memory.new,
        chdir: dir,
      )

      if status.success?
        output.to_s
      else
        raise Error.new :command_failed, error.to_s.sub("error:", "")
      end
    end
  end

  def self.get_for_package(dep : Dependency) : Base
    if uri = dep.git
      GitResolver.new uri, dep
    elsif uri = dep.github || dep.gitlab
      GitResolver.new(URI.parse(uri).tap do |u|
        u.host = dep.github ? "github.com" : "gitlab.com"
      end.to_s, dep)
    elsif uri = dep.bitbucket
      BitBucketResolver.new uri, dep
    elsif uri = dep.hg
      HGResolver.new uri, dep
    elsif uri = dep.fossil
      FossilResolver.new uri, dep
    else
      # TODO: might just default to git instead
      raise "BUG: could not determine a resolver"
    end
  end
end
