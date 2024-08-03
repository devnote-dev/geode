module Geode::Commands
  class Remove < Base
    def setup : Nil
      @name = "remove"
      @summary = "removes one or more dependencies from shard.yml"

      add_usage "remove <shards...>"
      add_argument "shards", description: "the names of the shards", multiple: true, required: true
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      unless File.exists? "shard.yml"
        error ["A shard.yml file was not found", "Run 'geode init' to initialize one"]
        exit_program
      end

      unless Dir.exists? "lib"
        error "No shards installed"
        exit_program
      end

      shard = Shard.load_local
      names = arguments.get("shards").as_a
      removed = false

      names.each do |name|
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
          removed = true
        elsif untracked
          success "Removed untracked shard '#{name}'"
          removed = true
        else
          warn "Shard '#{name}' not installed"
        end
      end

      warn "Make sure to remove the shard from your shard.yml file" if removed
    end
  end
end
