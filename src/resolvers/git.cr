module Geode::Resolvers
  class GitResolver < Base
    def initialize(@uri : String, @dep : Dependency)
      raise Error.new :no_cli, "git" unless Process.find_executable "git"
    end

    def get_versions : Array(String)
      requirement = Versions.parse @dep.version.as(String).lstrip 'v'
      available = [] of String

      execute("git ls-remote --tags #{@uri}").each_line do |line|
        tag = line.split(%r{\s+|\t})[1].sub(%r{^refs/tags/v?}, "")
        version = SemanticVersion.parse tag

        case requirement
        in Versions::Constraint
          available << tag if requirement.allows? version
        in Versions::Range
          available << tag if requirement.includes? version
        in SemanticVersion
          available << tag if requirement == version
        end
      end

      available
    end

    def validate(tag : String) : Nil
      shard = Shard.load_raw execute "git show #{tag}:shard.yml"
      raise Error.new :name_mismatch unless shard.name == @dep.name
    end

    def installed?(tag : String) : Bool
      return false unless File.exists?(path = Path[Dir.current, "lib", @dep.name, "shard.yml"])
      shard = Shard.load path.to_s rescue return false

      shard.version == tag
    end

    def install(tag : String, dest : String) : Nil
      execute "git --work-tree=#{dest} checkout #{tag} -- ."
    end
  end
end
