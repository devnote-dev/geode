module Geode::Commands
  class Version < BaseCommand
    def setup : Nil
      @name = "version"
      @description = "Gets the version information about Geode"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      stdout.puts "Geode version #{Geode::VERSION} (#{Geode::BUILD})"
    end
  end
end
