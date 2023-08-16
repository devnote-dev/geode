module Geode
  class Error < Exception
  end

  class Solver
    include Molinillo::SpecificationProvider(Dependency, Shard)
    include Molinillo::UI

    @shard : Shard
    @development : Bool
    @solution : Array(Package)

    def initialize(@shard, @development)
      @shard.name_dependencies
      @solution = [] of Package
    end

    def name_for(dep : Dependency)
      dep.name
    end

    def name_for(shard : Shard)
      shard.name
    end

    def name_for_explicit_dependency_source
      "shard.yml"
    end

    def name_for_locking_dependency_source
      "shard.lock"
    end

    def solve : Array(Package)
      deps = @shard.dependencies
      deps.merge! @shard.development if @development
      prefetch_local_caches deps

      base = Molinillo::DependencyGraph(Dependency, Dependency).new
      # TODO: factor in shard.lock

      pp deps.values.to_json
      result = Molinillo::Resolver(Dependency, Shard).new(self, self).resolve(deps.values, base)
      packages = [] of Package

      tsort(result).each do |res|
        pp! res
        next unless shard = res.payload.as?(Shard)
        next if shard.name == "crystal"

        # TODO: group these exceptions
        res.requirements.each do |req|
          unless req.name == shard.name
            raise "Shard name '#{shard.name}' does not match dependency name '#{req.name}'"
          end

          resolver = Resolver.from req
          packages << Package.new(shard.name, (req.version? ? req.version : "*"), resolver)
        end
      end

      packages
    end

    private def prefetch_local_caches(deps : Hash(String, Dependency)) : Nil
      active = Atomic.new 0
      sig = Channel(Exception?).new(deps.size + 1)

      deps.each do |_, dep|
        active.add 1
        while active.get > 8
          Fiber.yield
        end

        spawn do
          begin
            resolver = Resolver.from dep
            resolver.update_local_cache
            sig.send nil
          rescue ex
            sig.send ex
          ensure
            active.sub 1
          end
        end
      end

      deps.size.times do
        # TODO: group these
        if ex = sig.receive
          pp! ex
          raise ex
        end
      end
    end

    private def tsort(graph)
      sorted_vertices = typeof(graph.vertices).new

      graph.vertices.values.each do |vertex|
        if vertex.incoming_edges.empty?
          tsort_visit(vertex, sorted_vertices)
        end
      end

      sorted_vertices.values
    end

    private def tsort_visit(vertex, sorted_vertices)
      vertex.successors.each do |succ|
        unless sorted_vertices.has_key?(succ.name)
          tsort_visit(succ, sorted_vertices)
        end
      end

      sorted_vertices[vertex.name] = vertex
    end
  end
end
