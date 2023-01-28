module Geode::Commands
  class Version < BaseCommand
    def setup : Nil
      @name = "version"
      @summary = "gets the version information about Geode"
      @description = "Gets the version information about Geode."

      add_usage "geode version"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      stdout.puts "Geode version #{Geode::VERSION} (#{Geode::BUILD})"
    end
  end
end
