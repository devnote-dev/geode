module Geode::Commands
  License.init

  class Licenses < Base
    def setup : Nil
      @name = "licenses"
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
      libs = get_libraries.select { |k| shard.dependencies.has_key? k }
      return if libs.empty?

      paths = [] of String
      libs.each do |child|
        paths += find_licenses Path["lib"] / child
      end

      trigram = Trigram.new do |t|
        License.licenses.each { |l| t.add l.title }
      end
      licenses = [] of License

      paths.each do |path|
        header = File
          .read_lines(path)
          .find!(&.presence)
          .gsub(/^The|Version\s?|\(.*\)/, "")
          .strip

        res = trigram.query header
        next if res.empty?

        licenses << License.licenses[res[0] - 1]
      end

      unless licenses.size == paths.size
        warn "Could not resolve licenses for #{paths.size - licenses.size} shards"
      end

      licenses.each do |license|
        stdout << "• " << license.title << '\n'
      end
    end

    private def get_libraries : Array(String)
      libs = [] of String

      Dir.each_child("lib") do |child|
        next if child.starts_with? '.'
        next unless File.exists?(path = Path["lib"] / child / "shard.yml")

        shard = Shard.from_yaml File.read path
        libs << shard.name
      rescue YAML::ParseException
        warn "Failed to parse shard.yml contents for '#{child}'"
      end

      libs
    end

    private def find_licenses(path : Path) : Array(String)
      paths = [] of String

      Dir.each_child path do |child|
        next if child.starts_with? '.'
        next if File.symlink?(path / child)

        if {"LICENSE", "LICENSE.txt", "LICENSE.rst", "LICENSE.md"}.includes?(child)
          paths << (path / child).to_s
          next
        end

        if File.directory?(dir = path / child)
          paths += find_licenses dir
        end
      end

      paths
    end
  end
end
