module Geode::Commands
  class Remove < Base
    def setup : Nil
      @name = "remove"
      @summary = "removes a specified dependency from shard.yml"

      add_usage "remove <shard>"
      add_argument "shard", description: "the name of the shard", required: true
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      unless File.exists? "shard.yml"
        error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
        system_exit
      end

      unless Dir.exists? "lib"
        error "No shards installed"
        system_exit
      end

      shard = Shard.load_local
      name = arguments.get("shard").as_s
      untracked = false
      if Dir.exists?(path = Path["lib"] / name)
        FileUtils.rm_rf path
        untracked = true
      elsif shard.dependencies.has_key?(name) || shard.development.has_key?(name)
        warn "Shard '#{name}' is not installed but listed as a dependency"
      end

      if shard.dependencies.delete(name) || shard.development.delete(name)
        # TODO: this should really update shard.yml but the YAML module does it really badly
        # This may require a custom shard.yml file parser
        success "Removed shard '#{name}'"
        warn "Make sure to remove the shard from your shard.yml file"
      elsif untracked
        success "Removed untracked shard '#{name}'"
      else
        error "Shard '#{name}' not installed"
        system_exit
      end
    end
  end
end
