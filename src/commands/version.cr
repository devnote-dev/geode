module Geode::Commands
  class Version < BaseCommand
    def setup : Nil
      @name = "version"
      @summary = "gets the version information about Geode"
      @description = "Gets the version information about Geode."

      add_usage "geode version"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      stdout << "geode version " << Geode::VERSION
      stdout << " [" << Geode::BUILD_HASH << "] ("
      stdout << Geode::BUILD_DATE << ")\n\n"
      stdout << "Host Triple: " << Geode::HOST_TRIPLE << '\n'
    end
  end
end
