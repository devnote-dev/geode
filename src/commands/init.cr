module Geode::Commands
  class Init < Base
    private COMMAND = {% if flag?(:darwin) %}"Cmd"{% else %}"Ctrl"{% end %}
    private CHAR    = {% if flag?(:darwin) %}"Q"{% else %}"C"{% end %}

    def setup : Nil
      @name = "init"
      @summary = "initialize a shard.yml file"
      @description = <<-DESC
        Initializes a shard.yml file in the current directory. By default this command is
        interactive, but you can skip it by including the '--skip' flag. The command will
        fail if one already exists unless you use the '--force' flag.
        DESC

      add_usage "geode init [-f|--force] [-s|--skip]"
      add_usage "geode init --skip"
      add_usage "geode init -fs"
      add_option 'f', "force", description: "force create the shard.yml file"
      add_option 's', "skip", description: "skip the interactive setup"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      if File.exists?("shard.yml") && !options.has?("force")
        fatal(
          "A shard.yml file already exists in this directory",
          "Run this command with the '--force' flag to overwrite",
        )
      end

      name = Path[Dir.current].basename.underscore
      config = Geode::Config.load rescue Geode::Config.new
      author = config.presets.author
      crystal = begin
        version = `crystal version`.split(' ', 3)[1]
        ">= #{version}"
      rescue
        ">= #{Crystal::VERSION}"
      end
      license = config.presets.license || "MIT"

      return write_shard(name, nil, author, "0.1.0", crystal, license) if options.has? "skip"

      unless STDIN.tty?
        # FIXME: might need to add logic for dumb terminals vs pipes
        # warn "This console does not have interactive support; creating the file as normal"
        return write_shard(name, nil, author, "0.1.0", crystal, license)
      end

      Process.on_terminate do |_|
        puts "\nSetup cancelled\n"
        exit 0
      end

      puts <<-INTRO
        Welcome to the #{"Geode interactive shard setup".colorize.magenta}!
        This setup will walk you through creating a new shard.yml file.
        If you want to skip this setup, exit and run 'geode init --skip'.
        Press '^#{CHAR}' (#{COMMAND}+#{CHAR}) to exit at any time.
        INTRO
      puts

      prompt("name: (#{name}) ") do |input|
        unless Shard::NAME_REGEX.matches? input
          raise "shard name can only contain lowercase letters, numbers, dashes and underscores"
        end
        name = input
      end

      description = nil
      prompt("description: ") do |input|
        description = input
      end

      message = "author: "
      message += "(#{author}) " if author.presence
      prompt(message) do |input|
        author = input
      end

      version = "0.1.0"
      prompt("version: (0.1.0) ") do |input|
        version = SemanticVersion.parse(input).to_s
      end

      prompt("crystal: (#{crystal}) ") do |input|
        # TODO: needs version requirement checks
        crystal = input
      end

      prompt("license: (#{license}) ") do |input|
        # TODO: add validation for this as well...
        license = input
      end

      puts
      write_shard(name, description, author, version, crystal, license)
    end

    private def write_shard(name : String, description : String?, author : String?,
                            version : String, crystal : String, license : String?) : Nil
      name = "my_project" unless Shard::NAME_REGEX.matches? name
      description ||= "A short description of #{name}"

      File.open("shard.yml", mode: "w") do |file|
        file << "name: " << name << '\n'
        file << "description: "

        if description.size > 60
          file << "|\n"
          lines = [] of String
          current = IO::Memory.new

          description.split(' ').each do |word|
            if word.size + current.size > 60
              lines << current.to_s.strip
              current.clear
            end
            current << word << ' '
          end

          lines << current.to_s.strip unless current.empty?
          lines.each do |line|
            file << "  " << line << '\n'
          end
          file << '\n'
        else
          file << description << '\n'
        end

        if author.presence
          file << "authors:\n  - " << author << '\n'
        end

        file << "\nversion: " << version << '\n'
        file << "crystal: '" << crystal << "'\n"
        file << "license: " << (license || "MIT") << "\n\n"

        file << <<-YAML
          development_dependencies:
            ameba:
              github: crystal-ameba/ameba
              version: ~> 1.5.0
          YAML

        file << '\n'
      end

      success "Created shard.yml"
    end

    private def prompt(message : String, & : String ->) : Nil
      loop do
        stdout << message
        input = STDIN.gets || ""
        return if input.blank?

        begin
          yield input
          break
        rescue ex
          stderr.puts "#{"»".colorize.red} #{ex.message}"
        end
      end
    end
  end
end
