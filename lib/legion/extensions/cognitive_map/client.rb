# frozen_string_literal: true

require 'legion/extensions/cognitive_map/helpers/constants'
require 'legion/extensions/cognitive_map/helpers/location'
require 'legion/extensions/cognitive_map/helpers/graph_traversal'
require 'legion/extensions/cognitive_map/helpers/cognitive_map_store'
require 'legion/extensions/cognitive_map/runners/cognitive_map'

module Legion
  module Extensions
    module CognitiveMap
      class Client
        include Runners::CognitiveMap

        def initialize(map_store: nil, **)
          @map_store = map_store || Helpers::CognitiveMapStore.new
        end

        private

        attr_reader :map_store
      end
    end
  end
end
