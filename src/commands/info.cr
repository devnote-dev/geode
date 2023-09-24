module Geode::Commands
  class Info < Base
    def setup : Nil
      @name = "info"
      @summary = "gets information about a shard"
      @description = "Gets information about a specified shard."

      add_usage "info <shard>"
      add_argument "shard", description: "the name of the shard", required: true
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      unless File.exists? "shard.yml"
        error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
        system_exit
      end

      unless Dir.exists? "lib"
        error "No shards installed"
        system_exit
      end

      shard = Shard.load_local
      name = arguments.get("shard").as_s
      unless shard.dependencies.has_key?(name) || shard.development.has_key?(name)
        if File.exists?(Path["lib"] / name / "shard.yml")
          error "Shard '#{name}' is installed but not listed as a dependency"
        else
          error "Shard '#{name}' not installed"
        end
        system_exit
      end

      shard = Shard.from_yaml File.read(Path["lib"] / name / "shard.yml")

      stdout << "name: ".colorize.bold << shard.name << '\n'
      if description = shard.description
        stdout << description << "\n\n"
      end

      if authors = shard.authors
        stdout << "authors:\n".colorize.bold
        authors.each { |a| stdout << "• " << a << '\n' }
        stdout << '\n'
      end

      stdout << "version: ".colorize.bold << shard.version << '\n'
      stdout << "crystal: ".colorize.bold << (shard.crystal || "unknown") << '\n'
      stdout << "documentation: ".colorize.bold << (shard.documentation || "none") << '\n'
      stdout << "license: ".colorize.bold << (shard.license || "none") << '\n'
      stdout << "repository: ".colorize.bold << (shard.repository || "none") << '\n'

      {% for key in {"dependencies", "development"} %}
        unless shard.{{ key.id }}.empty?
          stdout << "\n#{{{key == "development" ? "development " : ""}}}dependencies:\n".colorize.bold

          shard.{{ key.id }}.each do |name, dep|
            stdout << "• " << name
            if dep.version?
              stdout << ": " << dep.version
            end

            case dep
            when .path?       then stdout << " (" << dep.path << ')'
            when .git?        then stdout << " (" << dep.git << ')'
            when .github?     then stdout << " (github)"
            when .gitlab?     then stdout << " (gitlab)"
            when .bitbucket?  then stdout << " (bitbucket)"
            when .hg?         then stdout << " (hg)"
            when .fossil?     then stdout << " (fossil)"
            end

            stdout << '\n'
          end

          stdout << '\n'
        end
      {% end %}

      unless shard.libraries.empty?
        stdout << "libraries:\n".colorize.bold
        shard.libraries.each do |_name, version|
          stdout << _name << ": " << version << '\n'
        end
        stdout << '\n'
      end

      unless shard.executables.empty?
        stdout << "executables:\n".colorize.bold
        shard.executables.each { |e| stdout << "• " << e << '\n' }
        stdout << '\n'
      end
    rescue ex : YAML::ParseException
      error ["Failed to parse shard.yml contents:", ex.to_s]
      system_exit
    end
  end
end
