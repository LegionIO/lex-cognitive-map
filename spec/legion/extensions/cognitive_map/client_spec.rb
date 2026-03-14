# frozen_string_literal: true

require 'legion/extensions/cognitive_map/client'

RSpec.describe Legion::Extensions::CognitiveMap::Client do
  subject(:client) { described_class.new }

  it 'responds to all runner methods' do
    expect(client).to respond_to(:add_location)
    expect(client).to respond_to(:connect_locations)
    expect(client).to respond_to(:visit_location)
    expect(client).to respond_to(:find_path)
    expect(client).to respond_to(:explore_neighborhood)
    expect(client).to respond_to(:map_clusters)
    expect(client).to respond_to(:familiar_locations)
    expect(client).to respond_to(:switch_context)
    expect(client).to respond_to(:update_cognitive_map)
    expect(client).to respond_to(:cognitive_map_stats)
  end

  it 'accepts an injected map_store' do
    custom_store = Legion::Extensions::CognitiveMap::Helpers::CognitiveMapStore.new
    custom_store.add_location(id: 'pre_existing')
    client2 = described_class.new(map_store: custom_store)
    result = client2.cognitive_map_stats
    expect(result[:location_count]).to eq(1)
  end

  describe 'integration: add and navigate' do
    it 'adds locations, connects them, and finds a path' do
      client.add_location(id: 'start', domain: :space)
      client.add_location(id: 'mid', domain: :space)
      client.add_location(id: 'end', domain: :space)
      client.connect_locations(from: 'start', to: 'mid', distance: 1.0)
      client.connect_locations(from: 'mid', to: 'end', distance: 1.0)

      result = client.find_path(from: 'start', to: 'end')
      expect(result[:success]).to be true
      expect(result[:path]).to eq(%w[start mid end])
      expect(result[:distance]).to eq(2.0)
    end

    it 'builds familiarity through visits' do
      client.add_location(id: 'hub')
      5.times { client.visit_location(id: 'hub') }
      familiar = client.familiar_locations(limit: 1)
      expect(familiar[:locations].first[:id]).to eq('hub')
      expect(familiar[:locations].first[:visit_count]).to eq(5)
    end

    it 'explores neighborhood up to a distance threshold' do
      client.add_location(id: 'center')
      client.add_location(id: 'near')
      client.add_location(id: 'far')
      client.connect_locations(from: 'center', to: 'near', distance: 1.0)
      client.connect_locations(from: 'near', to: 'far', distance: 5.0)

      result = client.explore_neighborhood(id: 'center', max_distance: 2.0)
      ids = result[:reachable].map { |r| r[:id] }
      expect(ids).to include('near')
      expect(ids).not_to include('far')
    end

    it 'detects disconnected clusters' do
      client.add_location(id: 'a')
      client.add_location(id: 'b')
      client.connect_locations(from: 'a', to: 'b')
      client.add_location(id: 'island1')
      client.add_location(id: 'island2')
      client.connect_locations(from: 'island1', to: 'island2')

      result = client.map_clusters
      expect(result[:count]).to eq(2)
    end

    it 'isolates context maps from each other' do
      client.add_location(id: 'shared_name', domain: :ctx_a)
      client.switch_context(context_id: :ctx_b)
      client.add_location(id: 'shared_name', domain: :ctx_b)

      result_b = client.cognitive_map_stats
      expect(result_b[:location_count]).to eq(1)

      client.switch_context(context_id: :default)
      result_default = client.cognitive_map_stats
      expect(result_default[:location_count]).to eq(1)
    end
  end
end
