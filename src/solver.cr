module Geode
  class Solver
    include Molinillo::SpecificationProvider(Package, Shard)
    include Molinillo::UI

    @shard : Shard
    @development : Bool
    @solution : Array(Package)

    def initialize(@shard, @development)
    end

    def name_for_explicit_dependency_source
      "shard.yml"
    end

    def name_for_locking_dependency_source
      "shard.lock"
    end

    def solve : Array(Package)
      deps = @shard.dependencies
      deps += @shard.development if @development
      prefetch_local_caches deps

      base = Molinillo::DependencyGraph(Package, Package).new
      # TODO: factor in shard.lock

      result = Molinillo::Resolver(Package, Shard).new(self, self).resolve(deps, base)
      packages = [] of Package

      tsort(result).each do |res|
        next unless package = res.payload
        next if package.name == "crystal"

        # TODO: group these exceptions
        res.requirements.each do |req|
          unless req.name == package.name
            raise "Shard name '#{package.name}' does not match dependency name '#{req.name}'"
          end

          packages << Package.new(package.name, package.resolver, package.version)
        end
      end

      packages
    end

    private def prefetch_local_caches(dependencies : Array(Shard::Dependency)) : Nil
      active = Atomic.new 0
      sig = Channel(Exception?).new(dependencies.size + 1)

      dependencies.each do |dep|
        active.add 1
        while active.get > 8
          Fiber.yield
        end

        spawn do
          begin
            dep.resolver.update_local_cache
            sig.send nil
          rescue ex
            sig.send ex
          ensure
            active.sub 1
          end
        end
      end

      dependencies.size.times do
        # TODO: group these
        if ex = sig.receive
          raise ex
        end
      end
    end
  end
end
