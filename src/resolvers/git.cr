module Geode
  class GitResolver < Resolver
    private PROVIDERS = {"github.com", "www.github.com"}

    def initialize(key : String, source : String)
      # TODO: what is this resolution process...
      super key, source
    end
  end
end
