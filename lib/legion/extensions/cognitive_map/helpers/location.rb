# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveMap
      module Helpers
        class Location
          attr_reader :id, :domain, :properties, :visit_count, :last_visited, :neighbors, :familiarity

          def initialize(id:, domain: :general, properties: {})
            @id           = id
            @domain       = domain
            @properties   = properties
            @familiarity  = Constants::FAMILIARITY_FLOOR
            @visit_count  = 0
            @last_visited = nil
            @neighbors    = {} # neighbor_id => distance
          end

          def visit
            @visit_count  += 1
            @last_visited  = Time.now.utc
            @familiarity   = [@familiarity + Constants::VISIT_BOOST, 1.0].min
          end

          def add_neighbor(neighbor_id, distance: Constants::DEFAULT_DISTANCE)
            distance = [distance, Constants::DISTANCE_FLOOR].max
            return if @neighbors.size >= Constants::MAX_EDGES_PER_LOCATION && !@neighbors.key?(neighbor_id)

            @neighbors[neighbor_id] = distance
          end

          def remove_neighbor(neighbor_id)
            @neighbors.delete(neighbor_id)
          end

          def decay
            new_val = @familiarity - Constants::FAMILIARITY_DECAY
            @familiarity = [new_val, Constants::FAMILIARITY_FLOOR].max
          end

          def faded?
            @familiarity <= Constants::FAMILIARITY_FLOOR && @visit_count.zero?
          end

          def label
            Constants.familiarity_level(@familiarity)
          end

          def to_h
            {
              id:           @id,
              domain:       @domain,
              properties:   @properties,
              familiarity:  @familiarity.round(4),
              label:        label,
              visit_count:  @visit_count,
              last_visited: @last_visited,
              neighbor_ids: @neighbors.keys,
              edge_count:   @neighbors.size
            }
          end
        end
      end
    end
  end
end
