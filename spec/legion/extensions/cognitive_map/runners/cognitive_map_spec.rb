# frozen_string_literal: true

require 'legion/extensions/cognitive_map/client'

RSpec.describe Legion::Extensions::CognitiveMap::Runners::CognitiveMap do
  let(:client) { Legion::Extensions::CognitiveMap::Client.new }

  def setup_two_locations
    client.add_location(id: 'a', domain: :test)
    client.add_location(id: 'b', domain: :test)
    client.connect_locations(from: 'a', to: 'b', distance: 1.0)
  end

  describe '#add_location' do
    it 'returns success: true for new location' do
      result = client.add_location(id: 'concept:ruby')
      expect(result[:success]).to be true
      expect(result[:id]).to eq('concept:ruby')
    end

    it 'returns success: true for duplicate (idempotent)' do
      client.add_location(id: 'concept:ruby')
      result = client.add_location(id: 'concept:ruby')
      expect(result[:success]).to be true
    end

    it 'passes domain through' do
      result = client.add_location(id: 'loc1', domain: :science)
      expect(result[:domain]).to eq(:science)
    end
  end

  describe '#connect_locations' do
    before { setup_two_locations }

    it 'returns success: true' do
      client.add_location(id: 'c')
      result = client.connect_locations(from: 'a', to: 'c')
      expect(result[:success]).to be true
    end

    it 'returns success: false for missing location' do
      result = client.connect_locations(from: 'a', to: 'ghost')
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:missing_location)
    end

    it 'passes distance through' do
      client.add_location(id: 'c')
      result = client.connect_locations(from: 'a', to: 'c', distance: 2.5)
      expect(result[:distance]).to eq(2.5)
    end
  end

  describe '#visit_location' do
    it 'returns success: true for existing location' do
      client.add_location(id: 'loc1')
      result = client.visit_location(id: 'loc1')
      expect(result[:success]).to be true
      expect(result[:visit_count]).to eq(1)
    end

    it 'returns success: false for missing location' do
      result = client.visit_location(id: 'ghost')
      expect(result[:success]).to be false
    end

    it 'increments visit count on repeated visits' do
      client.add_location(id: 'loc1')
      3.times { client.visit_location(id: 'loc1') }
      result = client.visit_location(id: 'loc1')
      expect(result[:visit_count]).to eq(4)
    end
  end

  describe '#find_path' do
    before { setup_two_locations }

    it 'finds path between connected locations' do
      result = client.find_path(from: 'a', to: 'b')
      expect(result[:success]).to be true
      expect(result[:path]).to eq(%w[a b])
    end

    it 'returns success: false for disconnected locations' do
      client.add_location(id: 'island')
      result = client.find_path(from: 'a', to: 'island')
      expect(result[:success]).to be false
    end

    it 'returns trivial path for same start and end' do
      result = client.find_path(from: 'a', to: 'a')
      expect(result[:success]).to be true
      expect(result[:distance]).to eq(0.0)
    end
  end

  describe '#explore_neighborhood' do
    before { setup_two_locations }

    it 'returns reachable locations' do
      result = client.explore_neighborhood(id: 'a', max_distance: 2.0)
      expect(result[:success]).to be true
      expect(result[:count]).to be >= 1
    end

    it 'respects max_distance' do
      result = client.explore_neighborhood(id: 'a', max_distance: 0.5)
      expect(result[:count]).to eq(0)
    end

    it 'returns success: true even for isolated location' do
      client.add_location(id: 'island')
      result = client.explore_neighborhood(id: 'island', max_distance: 5.0)
      expect(result[:success]).to be true
      expect(result[:count]).to eq(0)
    end
  end

  describe '#map_clusters' do
    it 'returns cluster information' do
      client.add_location(id: 'a')
      client.add_location(id: 'b')
      client.connect_locations(from: 'a', to: 'b')
      result = client.map_clusters
      expect(result[:success]).to be true
      expect(result[:count]).to eq(1)
    end

    it 'returns zero clusters for empty map' do
      result = client.map_clusters
      expect(result[:count]).to eq(0)
    end
  end

  describe '#familiar_locations' do
    it 'returns locations sorted by familiarity' do
      3.times { |i| client.add_location(id: "loc_#{i}") }
      5.times { client.visit_location(id: 'loc_0') }
      result = client.familiar_locations(limit: 3)
      expect(result[:success]).to be true
      expect(result[:locations].first[:id]).to eq('loc_0')
    end

    it 'respects limit' do
      5.times { |i| client.add_location(id: "loc_#{i}") }
      result = client.familiar_locations(limit: 2)
      expect(result[:count]).to be <= 2
    end
  end

  describe '#switch_context' do
    it 'switches to a new context' do
      result = client.switch_context(context_id: :work)
      expect(result[:success]).to be true
    end

    it 'new context has empty map' do
      client.add_location(id: 'loc1')
      client.switch_context(context_id: :empty_context)
      stats = client.cognitive_map_stats
      expect(stats[:location_count]).to eq(0)
    end
  end

  describe '#update_cognitive_map' do
    it 'runs decay cycle and returns counts' do
      client.add_location(id: 'a')
      client.visit_location(id: 'a')
      result = client.update_cognitive_map
      expect(result[:success]).to be true
      expect(result).to include(:decayed, :pruned)
    end
  end

  describe '#cognitive_map_stats' do
    it 'returns stats with success: true' do
      result = client.cognitive_map_stats
      expect(result[:success]).to be true
      expect(result).to include(:context, :location_count, :edge_count)
    end

    it 'reflects added locations' do
      client.add_location(id: 'a')
      client.add_location(id: 'b')
      result = client.cognitive_map_stats
      expect(result[:location_count]).to eq(2)
    end
  end
end
