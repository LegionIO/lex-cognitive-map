# lex-cognitive-map

Spatial and conceptual navigation map for LegionIO cognitive agents. Tracks familiarity with locations via EMA, finds shortest paths using Dijkstra's algorithm, and identifies knowledge clusters via BFS connected components. Supports up to 10 named contexts for parallel problem spaces.

## What It Does

- Add locations with labels and types to a directed weighted graph
- Visit locations to boost familiarity (EMA + direct boost)
- Familiarity decays over time via a periodic actor (every 60s)
- Find shortest paths between locations (Dijkstra, cached)
- Explore neighborhoods (direct neighbors)
- Identify connected clusters (BFS connected components)
- Surface most-familiar locations for memory-guided navigation
- Switch between up to 10 named map contexts

## Usage

```ruby
# Add locations
home   = runner.add_location(label: 'problem_domain', location_type: :concept)
middle = runner.add_location(label: 'solution_space',  location_type: :concept)
goal   = runner.add_location(label: 'resolved_state',  location_type: :outcome)

# Connect them
runner.connect_locations(from_id: home[:location][:id],
                          to_id: middle[:location][:id], weight: 1.0)
runner.connect_locations(from_id: middle[:location][:id],
                          to_id: goal[:location][:id], weight: 0.5)

# Visit
runner.visit_location(location_id: home[:location][:id])

# Find path
runner.find_path(from_id: home[:location][:id], to_id: goal[:location][:id])
# => { success: true, path: [...], total_distance: 1.5 }

# Switch context
runner.switch_context(context_name: 'alternate_approach')

# Stats
runner.cognitive_map_stats
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
