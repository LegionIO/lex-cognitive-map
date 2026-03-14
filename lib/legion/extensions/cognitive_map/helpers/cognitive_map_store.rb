# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveMap
      module Helpers
        class CognitiveMapStore
          attr_reader :current_context

          def initialize
            @contexts = {}
            @current_context = :default
            @path_cache = {}
            @visit_history = []
            ensure_context(@current_context)
          end

          def add_location(id:, domain: :general, properties: {})
            return false if locations.size >= Constants::MAX_LOCATIONS && !locations.key?(id)

            locations[id] ||= Location.new(id: id, domain: domain, properties: properties)
            true
          end

          def location(id)
            locations[id]
          end

          def remove_location(id)
            loc = locations.delete(id)
            return false unless loc

            locations.each_value { |l| l.remove_neighbor(id) }
            invalidate_path_cache
            true
          end

          def connect(from:, to:, distance: Constants::DEFAULT_DISTANCE, bidirectional: true)
            return false unless locations.key?(from) && locations.key?(to)

            locations[from].add_neighbor(to, distance: distance)
            locations[to].add_neighbor(from, distance: distance) if bidirectional
            invalidate_path_cache
            true
          end

          def disconnect(from:, to:)
            return false unless locations.key?(from)

            locations[from].remove_neighbor(to)
            invalidate_path_cache
            true
          end

          def visit(id:)
            loc = locations[id]
            return { found: false } unless loc

            loc.visit
            record_visit(id)
            { found: true, id: id, visit_count: loc.visit_count, familiarity: loc.familiarity.round(4) }
          end

          def shortest_path(from:, to:)
            return { found: false, reason: :missing_start } unless locations.key?(from)
            return { found: false, reason: :missing_end } unless locations.key?(to)
            return { found: true, path: [from], distance: 0.0 } if from == to

            fetch_or_compute_path(from, to)
          end

          def neighbors_of(id:)
            loc = locations[id]
            return [] unless loc

            loc.neighbors.map { |nid, dist| { id: nid, distance: dist, category: Constants.distance_category(dist) } }
          end

          def reachable_from(id:, max_distance: 3.0)
            return [] unless locations.key?(id)

            GraphTraversal.bfs_reachable(locations, id, max_distance)
          end

          def clusters
            GraphTraversal.connected_components(locations)
          end

          def most_familiar(n: 10)
            locations.values.sort_by { |l| -l.familiarity }.first(n).map(&:to_h)
          end

          def decay_all
            faded_ids = collect_faded
            faded_ids.each { |id| remove_location(id) }
            invalidate_path_cache if faded_ids.any?
            { decayed: locations.size, pruned: faded_ids.size }
          end

          def context_switch(context_id:)
            return { switched: false, reason: :max_contexts } if over_context_limit?(context_id)

            ensure_context(context_id)
            @current_context = context_id
            invalidate_path_cache
            { switched: true, context: context_id, location_count: locations.size }
          end

          def to_h
            {
              context:        @current_context,
              context_count:  @contexts.size,
              location_count: locations.size,
              edge_count:     total_edges,
              visit_history:  @visit_history.size,
              cached_paths:   @path_cache.size
            }
          end

          def location_count
            locations.size
          end

          private

          def locations
            @contexts[@current_context]
          end

          def ensure_context(context_id)
            @contexts[context_id] ||= {}
          end

          def over_context_limit?(context_id)
            @contexts.size >= Constants::MAX_CONTEXTS && !@contexts.key?(context_id)
          end

          def record_visit(id)
            @visit_history << { id: id, at: Time.now.utc }
            @visit_history.shift if @visit_history.size > Constants::MAX_VISIT_HISTORY
          end

          def invalidate_path_cache
            @path_cache.clear
          end

          def total_edges
            locations.values.sum { |l| l.neighbors.size }
          end

          def collect_faded
            faded = []
            locations.each_value do |loc|
              loc.decay
              faded << loc.id if loc.faded?
            end
            faded
          end

          def fetch_or_compute_path(from, to)
            cache_key = "#{@current_context}:#{from}->#{to}"
            return @path_cache[cache_key] if @path_cache[cache_key]

            result = GraphTraversal.dijkstra(locations, from, to)
            if result[:found]
              @path_cache[cache_key] = result
              @path_cache.shift if @path_cache.size > Constants::MAX_PATHS_CACHED
            end
            result
          end
        end
      end
    end
  end
end
