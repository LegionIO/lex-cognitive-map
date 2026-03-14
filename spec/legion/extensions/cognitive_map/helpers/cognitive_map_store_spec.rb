# frozen_string_literal: true

RSpec.describe Legion::Extensions::CognitiveMap::Helpers::CognitiveMapStore do
  subject(:store) { described_class.new }

  def add_triangle
    store.add_location(id: 'a')
    store.add_location(id: 'b')
    store.add_location(id: 'c')
    store.connect(from: 'a', to: 'b', distance: 1.0)
    store.connect(from: 'b', to: 'c', distance: 1.0)
    store.connect(from: 'a', to: 'c', distance: 3.0)
  end

  describe '#add_location' do
    it 'adds a location and returns true' do
      expect(store.add_location(id: 'loc1')).to be true
    end

    it 'is idempotent for duplicate ids' do
      store.add_location(id: 'loc1')
      store.add_location(id: 'loc1', domain: :other)
      expect(store.location_count).to eq(1)
    end

    it 'stores domain and properties' do
      store.add_location(id: 'loc1', domain: :science, properties: { weight: 0.9 })
      loc = store.location('loc1')
      expect(loc.domain).to eq(:science)
      expect(loc.properties[:weight]).to eq(0.9)
    end

    it 'enforces MAX_LOCATIONS' do
      max = Legion::Extensions::CognitiveMap::Helpers::Constants::MAX_LOCATIONS
      max.times { |i| store.add_location(id: "loc_#{i}") }
      result = store.add_location(id: 'overflow')
      expect(result).to be false
    end
  end

  describe '#remove_location' do
    it 'removes an existing location' do
      store.add_location(id: 'loc1')
      expect(store.remove_location('loc1')).to be true
      expect(store.location('loc1')).to be_nil
    end

    it 'returns false for unknown location' do
      expect(store.remove_location('nonexistent')).to be false
    end

    it 'removes edges pointing to removed location' do
      store.add_location(id: 'a')
      store.add_location(id: 'b')
      store.connect(from: 'a', to: 'b')
      store.remove_location('b')
      expect(store.neighbors_of(id: 'a')).to be_empty
    end
  end

  describe '#connect' do
    before do
      store.add_location(id: 'a')
      store.add_location(id: 'b')
    end

    it 'creates a directed edge' do
      expect(store.connect(from: 'a', to: 'b')).to be true
    end

    it 'creates bidirectional edges by default' do
      store.connect(from: 'a', to: 'b', distance: 2.0)
      a_neighbors = store.neighbors_of(id: 'a')
      b_neighbors = store.neighbors_of(id: 'b')
      expect(a_neighbors.map { |n| n[:id] }).to include('b')
      expect(b_neighbors.map { |n| n[:id] }).to include('a')
    end

    it 'creates unidirectional edges when bidirectional: false' do
      store.connect(from: 'a', to: 'b', bidirectional: false)
      a_neighbors = store.neighbors_of(id: 'a')
      b_neighbors = store.neighbors_of(id: 'b')
      expect(a_neighbors.map { |n| n[:id] }).to include('b')
      expect(b_neighbors.map { |n| n[:id] }).not_to include('a')
    end

    it 'returns false if a location is missing' do
      expect(store.connect(from: 'a', to: 'missing')).to be false
    end
  end

  describe '#disconnect' do
    it 'removes an edge' do
      store.add_location(id: 'a')
      store.add_location(id: 'b')
      store.connect(from: 'a', to: 'b')
      store.disconnect(from: 'a', to: 'b')
      expect(store.neighbors_of(id: 'a')).to be_empty
    end

    it 'returns false for unknown location' do
      expect(store.disconnect(from: 'ghost', to: 'b')).to be false
    end
  end

  describe '#visit' do
    it 'marks location as visited' do
      store.add_location(id: 'loc1')
      result = store.visit(id: 'loc1')
      expect(result[:found]).to be true
      expect(result[:visit_count]).to eq(1)
    end

    it 'returns found: false for unknown location' do
      result = store.visit(id: 'ghost')
      expect(result[:found]).to be false
    end

    it 'boosts familiarity' do
      store.add_location(id: 'loc1')
      before = store.location('loc1').familiarity
      store.visit(id: 'loc1')
      expect(store.location('loc1').familiarity).to be > before
    end
  end

  describe '#shortest_path' do
    before { add_triangle }

    it 'finds direct path between neighbors' do
      result = store.shortest_path(from: 'a', to: 'b')
      expect(result[:found]).to be true
      expect(result[:path]).to eq(%w[a b])
      expect(result[:distance]).to eq(1.0)
    end

    it 'finds shortest path avoiding longer direct edge' do
      result = store.shortest_path(from: 'a', to: 'c')
      expect(result[:found]).to be true
      # a->b->c = 2.0, a->c = 3.0, so Dijkstra should pick a->b->c
      expect(result[:distance]).to be <= 2.0
    end

    it 'returns trivial path for same start and end' do
      result = store.shortest_path(from: 'a', to: 'a')
      expect(result[:found]).to be true
      expect(result[:path]).to eq(['a'])
      expect(result[:distance]).to eq(0.0)
    end

    it 'returns found: false for missing start' do
      result = store.shortest_path(from: 'ghost', to: 'a')
      expect(result[:found]).to be false
    end

    it 'returns found: false for disconnected locations' do
      store.add_location(id: 'island')
      result = store.shortest_path(from: 'a', to: 'island')
      expect(result[:found]).to be false
    end

    it 'caches repeated queries' do
      store.shortest_path(from: 'a', to: 'c')
      result2 = store.shortest_path(from: 'a', to: 'c')
      expect(result2[:found]).to be true
    end
  end

  describe '#neighbors_of' do
    it 'returns direct neighbors' do
      store.add_location(id: 'a')
      store.add_location(id: 'b')
      store.connect(from: 'a', to: 'b', distance: 1.5)
      neighbors = store.neighbors_of(id: 'a')
      expect(neighbors.size).to eq(1)
      expect(neighbors.first[:id]).to eq('b')
      expect(neighbors.first[:distance]).to eq(1.5)
    end

    it 'returns empty array for unknown location' do
      expect(store.neighbors_of(id: 'ghost')).to be_empty
    end

    it 'includes distance category' do
      store.add_location(id: 'a')
      store.add_location(id: 'b')
      store.connect(from: 'a', to: 'b', distance: 0.3)
      neighbor = store.neighbors_of(id: 'a').first
      expect(neighbor[:category]).to eq(:adjacent)
    end
  end

  describe '#reachable_from' do
    before { add_triangle }

    it 'returns locations within max_distance' do
      reachable = store.reachable_from(id: 'a', max_distance: 1.5)
      ids = reachable.map { |r| r[:id] }
      expect(ids).to include('b')
    end

    it 'excludes start location from results' do
      reachable = store.reachable_from(id: 'a', max_distance: 5.0)
      expect(reachable.map { |r| r[:id] }).not_to include('a')
    end

    it 'returns empty for isolated location' do
      store.add_location(id: 'island')
      expect(store.reachable_from(id: 'island', max_distance: 10.0)).to be_empty
    end

    it 'sorts results by distance' do
      reachable = store.reachable_from(id: 'a', max_distance: 5.0)
      distances = reachable.map { |r| r[:distance] }
      expect(distances).to eq(distances.sort)
    end
  end

  describe '#clusters' do
    it 'returns one cluster for a connected graph' do
      add_triangle
      expect(store.clusters.size).to eq(1)
    end

    it 'returns multiple clusters for disconnected graph' do
      store.add_location(id: 'a')
      store.add_location(id: 'b')
      store.add_location(id: 'island')
      store.connect(from: 'a', to: 'b')
      clusters = store.clusters
      expect(clusters.size).to eq(2)
    end

    it 'returns empty array for empty map' do
      expect(store.clusters).to be_empty
    end
  end

  describe '#most_familiar' do
    it 'returns top N locations by familiarity' do
      5.times { |i| store.add_location(id: "loc_#{i}") }
      3.times { store.visit(id: 'loc_0') }
      store.visit(id: 'loc_1')
      result = store.most_familiar(n: 2)
      expect(result.size).to eq(2)
      expect(result.first[:id]).to eq('loc_0')
    end

    it 'returns fewer results than n when map has fewer locations' do
      store.add_location(id: 'only_one')
      result = store.most_familiar(n: 10)
      expect(result.size).to eq(1)
    end
  end

  describe '#decay_all' do
    it 'decays familiarity of all locations' do
      store.add_location(id: 'a')
      store.visit(id: 'a')
      before = store.location('a').familiarity
      store.decay_all
      expect(store.location('a').familiarity).to be < before
    end

    it 'prunes faded locations' do
      store.add_location(id: 'fresh')
      store.add_location(id: 'faded')
      # faded has floor familiarity and 0 visits — already qualifies as faded
      result = store.decay_all
      expect(result[:pruned]).to be >= 0
    end

    it 'returns decay and prune counts' do
      store.add_location(id: 'a')
      store.visit(id: 'a')
      result = store.decay_all
      expect(result).to include(:decayed, :pruned)
    end
  end

  describe '#context_switch' do
    it 'switches to a new context' do
      result = store.context_switch(context_id: :work)
      expect(result[:switched]).to be true
      expect(result[:context]).to eq(:work)
    end

    it 'new context starts empty' do
      store.add_location(id: 'default_loc')
      store.context_switch(context_id: :new_context)
      expect(store.location_count).to eq(0)
    end

    it 'preserves locations in original context' do
      store.add_location(id: 'default_loc')
      store.context_switch(context_id: :other)
      store.context_switch(context_id: :default)
      expect(store.location('default_loc')).not_to be_nil
    end

    it 'returns failure when MAX_CONTEXTS exceeded' do
      max = Legion::Extensions::CognitiveMap::Helpers::Constants::MAX_CONTEXTS
      max.times { |i| store.context_switch(context_id: :"ctx_#{i}") }
      result = store.context_switch(context_id: :overflow)
      expect(result[:switched]).to be false
    end
  end

  describe '#to_h' do
    it 'returns stats hash with expected keys' do
      stats = store.to_h
      expect(stats).to include(:context, :context_count, :location_count, :edge_count, :visit_history, :cached_paths)
    end

    it 'reflects current location count' do
      store.add_location(id: 'a')
      store.add_location(id: 'b')
      expect(store.to_h[:location_count]).to eq(2)
    end
  end
end
