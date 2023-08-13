module Geode::Commands
  class List < Base
    def setup : Nil
      @name = "list"
      @summary = "lists installed shards"
      @description = <<-DESC
        Lists the shards that have been installed. Due to the nature of the Shards CLI,
        transitive dependencies will also be listed even if they are not directly
        required by your project.
        DESC

      add_usage "list"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      unless File.exists? "shard.yml"
        error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
        system_exit
      end
      return unless Dir.exists? "lib"

      dependencies = begin
        shard = Shard.load_local
        shard.dependencies.merge shard.development
      rescue ex : YAML::ParseException
        warn ["Failed to parse shard.yml contents:", ex.to_s]
        {} of String => Dependency
      end

      libs = get_libraries
      return if libs.empty?

      libs.each do |name, version|
        stdout << "• " << name << ": " << version
        unless dependencies.has_key? name
          stdout << " (untracked)".colorize.light_gray
        end
        stdout << '\n'
      end
    end

    private def get_libraries : Hash(String, String)
      libs = {} of String => String

      Dir.each_child("lib") do |child|
        next if child.starts_with? '.'
        next unless File.exists?(path = Path["lib"] / child / "shard.yml")

        shard = Shard.from_yaml File.read path
        libs[shard.name] = shard.version
      rescue YAML::ParseException
        warn "Failed to parse shard.yml contents for '#{child}'"
      end

      libs
    end
  end
end
