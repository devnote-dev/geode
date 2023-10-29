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

      add_option "tree", description: "list recursively in tree format"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      unless File.exists? "shard.yml"
        error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
        system_exit
      end
      return unless Dir.exists? "lib"

      root = Shard.load_local
      deps = root.load_dependency_shards
      dev = root.load_development_shards

      str = String.build do |io|
        if options.has? "tree"
          deps.each do |spec|
            io << spec.name << ": " << spec.version << '\n'
            format(io, spec, 0)
          end

          dev.each do |spec|
            io << spec.name << ": " << spec.version << " (development)".colorize.light_gray << '\n'
            format(io, spec, 0)
          end
        else
          untracked = [] of {String, String}
          Dir.each_child("lib") do |child|
            next if child.starts_with? '.'
            next if deps.find { |d| d.name == child } || dev.find { |d| d.name == child }
            next unless File.exists?(path = Path["lib", child, "shard.yml"])

            shard = Shard.from_yaml File.read path
            untracked << {shard.name, shard.version}
          end

          deps.each do |spec|
            io << spec.name << ": " << spec.version << '\n'
          end

          dev.each do |spec|
            io << spec.name << ": " << spec.version << " (development)".colorize.light_gray << '\n'
          end

          untracked.each do |(name, version)|
            io << name << ": " << version << " (untracked)".colorize.yellow << '\n'
          end
        end
      end

      stdout.puts str
    end

    private def format(io : IO, shard : Shard, level : Int32) : Nil
      io << " " * level
      deps = shard.load_dependency_shards
      dev = shard.load_development_shards

      deps.each do |spec|
        io << "• " << spec.name << ": " << spec.version << '\n'

        if spec.dependencies.size > 0 || spec.development.size > 0
          format(io, spec, level + 2)
        end
      end

      dev.each do |spec|
        io << "• " << spec.name << ": " << spec.version << " (development)".colorize.light_gray << '\n'

        if spec.dependencies.size > 0 || spec.development.size > 0
          format(io, spec, level + 2)
        end
      end
    end
  end
end
