# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveMap
      module Helpers
        module GraphTraversal
          module_function

          def dijkstra(locations, from, to)
            dist = Hash.new(Float::INFINITY)
            prev = {}
            dist[from] = 0.0
            queue = [[0.0, from]]

            until queue.empty?
              d, u = queue.min_by { |x, _| x }
              queue.delete([d, u])
              break if u == to
              next if d > dist[u]

              relax_edges(locations, u, dist, prev, queue)
            end

            build_path_result(locations, prev, from, to, dist[to])
          end

          def bfs_reachable(locations, start, max_distance)
            visited = { start => 0.0 }
            queue = [[0.0, start]]
            reachable = []

            until queue.empty?
              dist, current = queue.min_by { |d, _| d }
              queue.delete([dist, current])
              next if dist > max_distance

              reachable << { id: current, distance: dist.round(4) } unless current == start
              expand_neighbors(locations, current, dist, max_distance, visited, queue)
            end

            reachable.sort_by { |r| r[:distance] }
          end

          def connected_components(locations)
            visited = {}
            components = []
            locations.each_key do |id|
              next if visited[id]

              component = []
              bfs_component(locations, id, visited, component)
              components << component
            end
            components
          end

          def relax_edges(locations, u, dist, prev, queue)
            loc = locations[u]
            return unless loc

            loc.neighbors.each do |v, weight|
              alt = dist[u] + weight
              next unless alt < dist[v]

              dist[v] = alt
              prev[v] = u
              queue << [alt, v]
            end
          end

          def build_path_result(_locations, prev, from, to, cost)
            return { found: false, reason: :no_path } if cost == Float::INFINITY

            path = reconstruct_path(prev, from, to)
            path.empty? ? { found: false, reason: :no_path } : { found: true, path: path, distance: cost.round(4) }
          end

          def reconstruct_path(prev, from, to)
            path = []
            current = to
            while current
              path.unshift(current)
              current = prev[current]
            end
            path.first == from ? path : []
          end

          def expand_neighbors(locations, current, dist, max_distance, visited, queue)
            loc = locations[current]
            return unless loc

            loc.neighbors.each do |nid, edge_dist|
              new_dist = dist + edge_dist
              next if new_dist > max_distance
              next if visited.key?(nid) && visited[nid] <= new_dist

              visited[nid] = new_dist
              queue << [new_dist, nid]
            end
          end

          def bfs_component(locations, start, visited, component)
            queue = [start]
            while (current = queue.shift)
              next if visited[current]

              visited[current] = true
              component << current
              loc = locations[current]
              next unless loc

              loc.neighbors.each_key { |nid| queue << nid unless visited[nid] }
            end
          end
        end
      end
    end
  end
end
