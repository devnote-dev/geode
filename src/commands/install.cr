module Geode::Commands
  class Install < BaseCommand
    def setup : Nil
      @name = "install"
      @summary = "installs dependencies from shard.yml"
      @description = "Installs dependencies from a shard.yml file. This includes development dependencies " \
        "unless you include the '--production' flag."

      add_usage "install [-D|--no-development] [--frozen] [--production] [--verbose]"
      add_option 'D', "no-development"
      add_option "frozen"
      add_option "production"
    end

    def pre_run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      super arguments, options

      nodev = options.has? "no-development"
      frozen = options.has? "frozen"
      production = options.has? "production"

      if (nodev || frozen) && production
        flags = [] of String
        flags << "no-development" if nodev
        flags << "frozen" if frozen

        stdout.puts "#{"❖  Warning".colorize.yellow}: unnecessary flag#{"s" if nodev && frozen} specified:"
        stdout.puts "#{"»".colorize.yellow}  production"
        stdout.puts %(#{"»".colorize.yellow}    ↳ implies #{flags.join " and "})
      end
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      unless File.exists? "shard.yml"
        stderr.puts "#{"❖ Error".colorize.red}: shard.yml file not found"
        stderr.puts "#{"»".colorize.red}  Run '#{"geode init".colorize.light_magenta}' to create one"
        system_exit
      end
    end
  end
end
