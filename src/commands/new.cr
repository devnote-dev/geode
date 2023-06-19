module Geode::Commands
  class New < BaseCommand
    def setup : Nil
      @name = "new"

      add_argument "template", required: false
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
    end
  end
end
