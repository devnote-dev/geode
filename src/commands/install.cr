module Geode::Commands
  class Install < BaseCommand
    def setup : Nil
      @name = "install"
      @summary = "installs dependencies from shard.yml"
      @description = <<-DESC
        Installs dependencies from a shard.yml file. This includes development dependencies
        unless you include the '--production' flag.
        DESC

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
      return unless (nodev || frozen) && production

      flags = [] of String
      flags << "no-development" if nodev
      flags << "frozen" if frozen

      warn [
        "Unnecessary flag#{"s" if nodev && frozen} specified:",
        "production",
        %(  ↳ implies #{flags.join " and "}),
      ]
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      return if File.exists? "shard.yml"
      error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
      system_exit
    end
  end
end
