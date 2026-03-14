# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveMap
      module Helpers
        module Constants
          # Graph size limits
          MAX_LOCATIONS          = 500
          MAX_EDGES_PER_LOCATION = 20
          MAX_PATHS_CACHED       = 100

          # Edge weights
          DEFAULT_DISTANCE = 1.0
          DISTANCE_FLOOR   = 0.01

          # Familiarity EMA
          FAMILIARITY_ALPHA = 0.12
          FAMILIARITY_DECAY = 0.005
          FAMILIARITY_FLOOR = 0.05
          VISIT_BOOST       = 0.1

          # Visit history ring buffer
          MAX_VISIT_HISTORY = 300

          # Context remapping
          REMAP_THRESHOLD = 0.5
          MAX_CONTEXTS    = 10

          # Familiarity level labels (ascending thresholds)
          FAMILIARITY_LEVELS = {
            (0.0...0.2) => :unknown,
            (0.2...0.4) => :sparse,
            (0.4...0.6) => :moderate,
            (0.6...0.8) => :familiar,
            (0.8..1.0)  => :intimate
          }.freeze

          # Distance category labels (ascending thresholds)
          DISTANCE_CATEGORIES = {
            (0.0...0.5) => :adjacent,
            (0.5...1.5) => :near,
            (1.5...3.0) => :moderate,
            (3.0...6.0) => :distant,
            (6.0..)     => :remote
          }.freeze

          module_function

          def familiarity_level(value)
            FAMILIARITY_LEVELS.each do |range, label|
              return label if range.cover?(value)
            end
            :intimate
          end

          def distance_category(value)
            DISTANCE_CATEGORIES.each do |range, label|
              return label if range.cover?(value)
            end
            :remote
          end
        end
      end
    end
  end
end
