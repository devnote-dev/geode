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
      @summary = "list installed shards"
      @description = <<-DESC
        Lists the shards that have been installed. By default this will only show direct
        dependencies listed in shard.yml, development dependencies can be shown by
        specifying the '--development' flag. Transitive dependencies (shards used by your
        dependencies) can be listed by specifying the '--transitive' flag. Untracked
        dependencies (shards that have been installed but aren't listed in shard.yml) can
        be listed by specifying the '--untracked' flag.
        DESC

      add_option 'd', "development"
      add_option 't', "transitive"
      add_option 'u', "untracked"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      ensure_local_shard_and_lib!

      root = Shard.load_local
      entries = [] of Entry
      development = options.has? "development"
      transitive = options.has? "transitive"
      untracked = options.has? "untracked"

      root.dependency_shards.each do |name, shard|
        entries << Entry.new(name, shard.version, :direct)

        if transitive
          shard.dependency_shards.each do |_, dep|
            entries << Entry.new(dep.name, dep.version, :transitive)
          end
        end
      end

      root.development_shards.each do |name, shard|
        entries << Entry.new(name, shard.version, :development)

        if transitive
          shard.development_shards.each do |_, dep|
            entries << Entry.new(dep.name, dep.version, :transitive)
          end
        end
      end

      Dir.each_child("lib") do |child|
        next if child.starts_with? '.'
        next unless Shard.exists? child

        shard = Shard.load child
        entry = Entry.new(shard.name, shard.version, :untracked)
        next if entries.includes? entry

        entries << entry
      end

      entries.each do |entry|
        if entry.kind.direct? ||
           (development && entry.kind.development?) ||
           (transitive && entry.kind.transitive?) ||
           (untracked && entry.kind.untracked?)
          stdout << "• " if entry.kind.transitive?
          stdout << entry.name << ": " << entry.version
          case entry.kind
          when .development? then stdout << " (development)".colorize.light_gray
          when .transitive?  then stdout << " (transitive)".colorize.light_gray
          when .untracked?   then stdout << " (untracked)".colorize.yellow
          end
          stdout << '\n'
        end
      end
    end
  end
end
