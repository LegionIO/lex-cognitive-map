# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveMap
      module Runners
        module CognitiveMap
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def add_location(id:, domain: :general, properties: {}, **)
            result = map_store.add_location(id: id, domain: domain, properties: properties)
            if result
              Legion::Logging.debug "[cognitive_map] add_location id=#{id} domain=#{domain}"
              { success: true, id: id, domain: domain }
            else
              Legion::Logging.warn "[cognitive_map] add_location failed: capacity or duplicate id=#{id}"
              { success: false, id: id, reason: :capacity_or_duplicate }
            end
          end

          def connect_locations(from:, to:, distance: Helpers::Constants::DEFAULT_DISTANCE,
                                bidirectional: true, **)
            result = map_store.connect(from: from, to: to, distance: distance, bidirectional: bidirectional)
            if result
              Legion::Logging.debug "[cognitive_map] connect from=#{from} to=#{to} distance=#{distance}"
              { success: true, from: from, to: to, distance: distance, bidirectional: bidirectional }
            else
              Legion::Logging.warn "[cognitive_map] connect failed: missing location from=#{from} to=#{to}"
              { success: false, from: from, to: to, reason: :missing_location }
            end
          end

          def visit_location(id:, **)
            result = map_store.visit(id: id)
            Legion::Logging.debug "[cognitive_map] visit id=#{id} found=#{result[:found]}"
            result.merge(success: result[:found])
          end

          def find_path(from:, to:, **)
            result = map_store.shortest_path(from: from, to: to)
            Legion::Logging.debug "[cognitive_map] find_path from=#{from} to=#{to} found=#{result[:found]}"
            result.merge(success: result[:found])
          end

          def explore_neighborhood(id:, max_distance: 3.0, **)
            reachable = map_store.reachable_from(id: id, max_distance: max_distance)
            Legion::Logging.debug "[cognitive_map] explore id=#{id} max_distance=#{max_distance} found=#{reachable.size}"
            { success: true, id: id, reachable: reachable, count: reachable.size }
          end

          def map_clusters(**)
            components = map_store.clusters
            Legion::Logging.debug "[cognitive_map] clusters count=#{components.size}"
            { success: true, clusters: components, count: components.size }
          end

          def familiar_locations(limit: 10, **)
            locations = map_store.most_familiar(n: limit)
            Legion::Logging.debug "[cognitive_map] familiar_locations count=#{locations.size}"
            { success: true, locations: locations, count: locations.size }
          end

          def switch_context(context_id:, **)
            result = map_store.context_switch(context_id: context_id)
            Legion::Logging.info "[cognitive_map] context_switch context_id=#{context_id} switched=#{result[:switched]}"
            result.merge(success: result[:switched])
          end

          def update_cognitive_map(**)
            result = map_store.decay_all
            Legion::Logging.debug "[cognitive_map] decay_cycle decayed=#{result[:decayed]} pruned=#{result[:pruned]}"
            { success: true, decayed: result[:decayed], pruned: result[:pruned] }
          end

          def cognitive_map_stats(**)
            stats = map_store.to_h
            Legion::Logging.debug "[cognitive_map] stats context=#{stats[:context]} locations=#{stats[:location_count]}"
            { success: true }.merge(stats)
          end

          private

          def map_store
            @map_store ||= Helpers::CognitiveMapStore.new
          end
        end
      end
    end
  end
end
