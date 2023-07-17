module Geode::Commands
  class Version < BaseCommand
    def setup : Nil
      @name = "version"
      @summary = "gets the version information about Geode"
      @description = "Gets the version information about Geode."

      add_usage "geode version"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      stdout.puts "geode version #{Geode::VERSION} [#{Geode::BUILD_HASH}] (#{Geode::BUILD_DATE})"
    end
  end
end
