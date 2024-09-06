module Geode::Commands
  License.init

  class Licenses < Base
    def setup : Nil
      @name = "licenses"
      @summary = "gets shard licenses information"
      @description = <<-DESC
        Gets licening information from installed shards. This will also list general
        conditions permitted by the licenses.
        DESC
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      ensure_local_shard_and_lib!

      shard = Shard.load_local
      libs = get_libraries.select { |k| shard.dependencies.has_key? k }
      return if libs.empty?

      paths = {} of String => Array(String)
      libs.each do |child|
        paths[child] = find_licenses Path["lib"] / child
      end
      return if paths.empty?

      trigram = Trigram.new do |t|
        License.licenses.each { |l| t.add l.title }
      end
      found = Hash(String, Array(License)).new # { [] of License }

      paths.each do |name, arr|
        licenses = [] of License

        arr.each do |path|
          header = File
            .read_lines(path)
            .find!(&.presence)
            .gsub(/^The|Version\s?|\(.*\)/, "")
            .strip

          res = trigram.query header
          next if res.empty?

          licenses << License.licenses[res[0] - 1]
        end

        found[name] = licenses
      end

      found.each do |name, licenses|
        stdout << name << ":\n"
        if licenses.empty?
          stdout << "• none found"
        else
          licenses.each do |license|
            stdout << "• " << license.title << '\n'
          end
        end
        stdout << '\n'
      end

      total = found.values.flatten
      stdout << emoji_for(total.any? do |l|
        l.permissions.private_use? && !l.conditions.disclose_source?
      end) << " allows closed-source\n"

      # TODO: needs refining...
      stdout << emoji_for(total.any? do |l|
        l.permissions.commercial_use? && l.permissions.distribution?
      end) << " allows distribution\n"

      stdout << emoji_for(total.any? &.conditions.include_copyright?) << " requires copyright\n"
      stdout << emoji_for(total.any? &.conditions.network_use_disclose?) << " requires network use disclosure\n"
      stdout << emoji_for(total.any? &.conditions.same_license?) << " requires same license\n"
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

    private def emoji_for(cond : Bool)
      if cond
        "✔".colorize.green
      else
        "✘".colorize.red
      end
    end
  end
end
