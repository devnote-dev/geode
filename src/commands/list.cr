module Geode::Commands
  class List < Base
    private class Entry
      enum Kind
        Direct
        Development
        Transitive
        Untracked
      end

      getter name : String
      getter version : String
      property kind : Kind

      def_equals @name, @version

      def initialize(@name, @version, @kind)
      end
    end

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
      entries = root.dependency_shards.map { |name, spec| Entry.new(name, spec.version, :direct) }
      entries.concat root.development_shards.map { |name, spec| Entry.new(name, spec.version, :development) }

      deps = root.load_dependency_shards
      dev = root.load_development_shards
      entries = deps.map { |dep| Entry.new(dep.name, dep.version, :direct) }
      entries.concat dev.map { |dep| Entry.new(dep.name, dep.version, :development) }

      untracked = [] of Entry
      Dir.each_child("lib") do |child|
        next if child.starts_with? '.'
        next unless File.exists?(path = Path["lib", child, "shard.yml"])

        shard = Shard.from_yaml File.read path
        next if deps.find { |d| d.name == shard.name } || dev.find { |d| d.name == shard.name }

        untracked << Entry.new(shard.name, shard.version, :untracked)
      end

      unless untracked.empty?
        resolve_untracked root, entries, untracked
        entries.concat untracked
      end

      pp entries
      return

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

    private def resolve_untracked(shard : Shard, resolved : Array(Entry), untracked : Array(Entry)) : Nil
      deps = shard.load_dependency_shards
      dev = shard.load_development_shards

      untracked.each do |entry|
        deps.each do |dep|
          if dep.dependencies.has_key? name
            entry.kind = :transitive
            resolved << entry
          elsif dep.development.has_key? name
            entry.kind = :transitive
            resolved << entry
          end
        end

        dev.each do |dep|
          if dep.dependencies.has_key? name
            entry.kind = :development
            resolved << entry
          elsif dep.development.has_key? name
            entry.kind = :development
            resolved << entry
          end
        end
      end
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
