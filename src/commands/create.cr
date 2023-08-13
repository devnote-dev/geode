module Geode::Commands
  class Create < Base
    def setup : Nil
      @name = "create"

      add_argument "template", required: true
      add_argument "name", required: true
      add_argument "directory"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
    end
  end
end
