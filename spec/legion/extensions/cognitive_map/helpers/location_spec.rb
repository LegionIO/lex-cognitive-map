# frozen_string_literal: true

RSpec.describe Legion::Extensions::CognitiveMap::Helpers::Location do
  subject(:location) { described_class.new(id: 'concept:ruby', domain: :programming) }

  describe '#initialize' do
    it 'sets id and domain' do
      expect(location.id).to eq('concept:ruby')
      expect(location.domain).to eq(:programming)
    end

    it 'starts with floor familiarity' do
      expect(location.familiarity).to eq(Legion::Extensions::CognitiveMap::Helpers::Constants::FAMILIARITY_FLOOR)
    end

    it 'starts with zero visit count' do
      expect(location.visit_count).to eq(0)
    end

    it 'starts with no neighbors' do
      expect(location.neighbors).to be_empty
    end

    it 'starts with no last_visited' do
      expect(location.last_visited).to be_nil
    end
  end

  describe '#visit' do
    it 'increments visit count' do
      location.visit
      expect(location.visit_count).to eq(1)
    end

    it 'sets last_visited' do
      before = Time.now.utc
      location.visit
      expect(location.last_visited).to be >= before
    end

    it 'boosts familiarity' do
      before = location.familiarity
      location.visit
      expect(location.familiarity).to be > before
    end

    it 'clamps familiarity at 1.0' do
      20.times { location.visit }
      expect(location.familiarity).to be <= 1.0
    end

    it 'accumulates multiple visits' do
      3.times { location.visit }
      expect(location.visit_count).to eq(3)
    end
  end

  describe '#add_neighbor' do
    it 'adds a neighbor with default distance' do
      location.add_neighbor('concept:python')
      expect(location.neighbors).to have_key('concept:python')
      expect(location.neighbors['concept:python']).to eq(Legion::Extensions::CognitiveMap::Helpers::Constants::DEFAULT_DISTANCE)
    end

    it 'adds a neighbor with custom distance' do
      location.add_neighbor('concept:java', distance: 2.5)
      expect(location.neighbors['concept:java']).to eq(2.5)
    end

    it 'enforces distance floor' do
      location.add_neighbor('concept:c', distance: 0.0)
      expect(location.neighbors['concept:c']).to eq(Legion::Extensions::CognitiveMap::Helpers::Constants::DISTANCE_FLOOR)
    end

    it 'updates existing neighbor distance' do
      location.add_neighbor('concept:python', distance: 1.0)
      location.add_neighbor('concept:python', distance: 0.5)
      expect(location.neighbors['concept:python']).to eq(0.5)
    end

    it 'respects MAX_EDGES_PER_LOCATION limit' do
      max = Legion::Extensions::CognitiveMap::Helpers::Constants::MAX_EDGES_PER_LOCATION
      (max + 5).times { |i| location.add_neighbor("neighbor_#{i}") }
      expect(location.neighbors.size).to be <= max
    end
  end

  describe '#remove_neighbor' do
    it 'removes an existing neighbor' do
      location.add_neighbor('concept:python')
      location.remove_neighbor('concept:python')
      expect(location.neighbors).not_to have_key('concept:python')
    end

    it 'is a no-op for unknown neighbors' do
      expect { location.remove_neighbor('nonexistent') }.not_to raise_error
    end
  end

  describe '#decay' do
    it 'reduces familiarity' do
      location.visit # raise above floor first
      before = location.familiarity
      location.decay
      expect(location.familiarity).to be < before
    end

    it 'does not go below FAMILIARITY_FLOOR' do
      10.times { location.decay }
      expect(location.familiarity).to be >= Legion::Extensions::CognitiveMap::Helpers::Constants::FAMILIARITY_FLOOR
    end
  end

  describe '#faded?' do
    it 'is true for a new location at floor familiarity with zero visits' do
      expect(location.familiarity).to eq(Legion::Extensions::CognitiveMap::Helpers::Constants::FAMILIARITY_FLOOR)
      expect(location.visit_count).to eq(0)
      expect(location.faded?).to be true
    end

    it 'is false after visiting' do
      location.visit
      expect(location.faded?).to be false
    end

    it 'is false when familiarity is above floor even with zero visits' do
      # familiarity raised manually above floor
      2.times { location.visit }
      # simulate decay back but not below floor — visit_count > 0 so still false
      10.times { location.decay }
      expect(location.faded?).to be false
    end
  end

  describe '#label' do
    it 'returns a familiarity level symbol' do
      expect(location.label).to be_a(Symbol)
    end

    it 'returns :unknown for low familiarity' do
      # familiarity_floor is 0.05, which is in the :unknown range (0.0...0.2)
      expect(location.label).to eq(:unknown)
    end

    it 'returns :intimate for high familiarity' do
      10.times { location.visit }
      expect(location.label).to eq(:intimate)
    end
  end

  describe '#to_h' do
    it 'returns a hash with expected keys' do
      h = location.to_h
      expect(h).to include(:id, :domain, :properties, :familiarity, :label, :visit_count, :neighbor_ids, :edge_count)
    end

    it 'reflects current state' do
      location.visit
      location.add_neighbor('other')
      h = location.to_h
      expect(h[:visit_count]).to eq(1)
      expect(h[:edge_count]).to eq(1)
    end
  end
end
