module Geode::Commands
  class Init < BaseCommand
    def setup : Nil
      @name = "init"
      @summary = "initializes a shard.yml file"
      @description = <<-DESC
        Initializes a shard.yml file in the current directory. By default this command is
        interactive, but you can skip it by including the '--skip' flag. The command will
        fail if one already exists unless you use the '--force' flag.
        DESC

      add_usage "geode init [-f|--force] [-s|--skip] [options]"
      add_usage "geode init --skip"
      add_usage "geode init -fs"
      add_option 'f', "force", description: "force create the shard.yml file"
      add_option 's', "skip", description: "skip the interactive setup"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      if File.exists?("shard.yml") && !options.has?("force")
        error [
          "A shard.yml file already exists in this directory",
          "Run this command with the '#{"--force".colorize.magenta}' flag to overwrite",
        ]
        system_exit
      end

      name = Path[Dir.current].basename.underscore
      return write_shard name if options.has? "skip"

      unless STDIN.tty?
        warn "This console does not have interactive support; creating the file as normal"
        return write_shard name
      end

      command = {% if flag?(:darwin) %}"Cmd"{% else %}"Ctrl"{% end %}
      char = {% if flag?(:darwin) %}"Q"{% else %}"C"{% end %}

      Process.on_interrupt do
        stdout.puts "\n❖  Setup cancelled\n"
        exit 0
      end

      stdout.puts <<-INTRO
        ❖  Welcome to the #{"Geode interactive shard setup".colorize.magenta}!
        This setup will walk you through creating a new shard.yml file.
        If you want to skip this setup, exit and run '#{"geode init --skip".colorize.light_magenta}'
        Press '^#{char}' (#{command}+#{char}) to exit at any time.
        INTRO
      stdout.puts

      prompt("name: (#{name}) ") do |input|
        unless Package::NAME_REGEX.matches? input
          raise "package name can only contain lowercase letters, numbers, dashes and underscores"
        end
        name = input
      end

      description = nil
      prompt("description: ") do |input|
        description = input
      end

      version = "0.1.0"
      prompt("version: (0.1.0) ") do |input|
        # TODO: add validation for this
        version = input
      end

      crystal = Crystal::VERSION
      prompt("crystal: (#{crystal}) ") do |input|
        # TODO: add validation for this too
        crystal = input
      end

      license = "MIT"
      prompt("license: (MIT) ") do |input|
        # TODO: add validation for this as well...
        license = input
      end

      stdout.puts
      write_shard(name, description, version, crystal, license)
    end

    private def write_shard(name : String, description : String? = nil, version : String = "0.1.0",
                            crystal : String = Crystal::VERSION, license : String = "MIT") : Nil
      unless Package::NAME_REGEX.matches? name
        name = "my_project"
      end
      description ||= "A short description of #{name}"

      File.write("shard.yml", <<-YAML)
      name: #{name}
      description: #{description}

      version: #{version}

      dependencies:
        kemal:
          github: kemalcr/kemal

      development_dependencies:
        webmock:
          github: manastech/webmock.cr

      crystal: #{crystal}

      license: #{license}
      YAML

      stdout.puts "#{"❖".colorize.green}  Created shard.yml"
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
