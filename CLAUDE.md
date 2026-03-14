# lex-cognitive-map

**Level 3 Leaf Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`

## Purpose

Spatial and conceptual map for cognitive navigation. Locations in the map have familiarity scores tracked via EMA that boost on visit and decay over time. Weighted directed edges connect locations. Dijkstra's algorithm finds shortest paths; BFS identifies reachable subgraphs and connected components. Supports up to 10 simultaneous named contexts (switching clears the active map). A periodic decay actor maintains freshness automatically.

## Gem Info

- **Gem name**: `lex-cognitive-map`
- **Module**: `Legion::Extensions::CognitiveMap`
- **Version**: `0.1.0`
- **Ruby**: `>= 3.4`
- **License**: MIT

## File Structure

```
lib/legion/extensions/cognitive_map/
  version.rb
  client.rb
  helpers/
    constants.rb
    location.rb
    graph_traversal.rb
    cognitive_map_store.rb
  runners/
    cognitive_map.rb
  actors/
    decay.rb
```

## Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `MAX_LOCATIONS` | `500` | Per-context location capacity |
| `MAX_EDGES_PER_LOCATION` | `20` | Max outgoing edges per location |
| `MAX_PATHS_CACHED` | `100` | LRU path cache capacity |
| `FAMILIARITY_ALPHA` | `0.12` | EMA smoothing for familiarity on visit |
| `FAMILIARITY_DECAY` | `0.005` | Per-cycle familiarity decay toward floor |
| `VISIT_BOOST` | `0.1` | Direct familiarity boost per visit |
| `MAX_VISIT_HISTORY` | `300` | Ring buffer for visit history |
| `REMAP_THRESHOLD` | `0.5` | Familiarity below which location is considered unfamiliar |
| `MAX_CONTEXTS` | `10` | Maximum simultaneous named map contexts |
| `FAMILIARITY_LEVELS` | range hash | From `:unknown` to `:intimate` |
| `DISTANCE_CATEGORIES` | range hash | From `:adjacent` to `:remote` |

## Helpers

### `Helpers::Location`
Individual node in the map graph. Has `id`, `label`, `location_type`, `familiarity`, `neighbors` (hash of `neighbor_id => weight`), `visit_count`, and `floor` (minimum familiarity).

- `visit` — boosts familiarity via EMA and `VISIT_BOOST`
- `add_neighbor(location_id, weight)` — adds directed edge
- `remove_neighbor(location_id)` — removes edge
- `decay` — familiarity decays toward floor by `FAMILIARITY_DECAY`
- `faded?` — familiarity below `REMAP_THRESHOLD` (candidate for pruning)
- `label` (attribute) / `familiarity_label` (computed)

### `Helpers::GraphTraversal`
Pure module of graph algorithms (no state).

- `dijkstra(locations, start_id, end_id)` → path result hash including node list and total distance
- `bfs_reachable(locations, start_id)` → set of reachable location IDs
- `connected_components(locations)` → array of component arrays (ignoring edge direction)
- Private: `relax_edges`, `build_path_result`, `reconstruct_path`, `expand_neighbors`, `bfs_component`

### `Helpers::CognitiveMapStore`
Multi-context map manager. One active context at a time.

- `add_location(label:, location_type:)` → location in current context
- `connect(from_id:, to_id:, weight:)` → adds edge
- `disconnect(from_id:, to_id:)` → removes edge
- `visit(location_id)` → familiarity boost
- `shortest_path(from_id:, to_id:)` → Dijkstra result (cached)
- `neighbors_of(location_id)` → neighbor list
- `reachable_from(location_id)` → BFS reachable set
- `clusters` → connected components
- `most_familiar(limit:)` → top N by familiarity
- `decay_all` — applies decay to all locations, prunes fully-faded ones, clears affected path cache entries
- `context_switch(context_name)` → switches active context (creates new empty map if name is new)

## Runners

Module: `Runners::CognitiveMap`

| Runner Method | Description |
|---|---|
| `add_location(label:, location_type:)` | Add a location |
| `connect_locations(from_id:, to_id:, weight:)` | Add an edge |
| `visit_location(location_id:)` | Visit and boost familiarity |
| `find_path(from_id:, to_id:)` | Dijkstra shortest path |
| `explore_neighborhood(location_id:)` | Neighbors list |
| `map_clusters` | Connected components |
| `familiar_locations(limit:)` | Most familiar locations |
| `switch_context(context_name:)` | Switch active map context |
| `update_cognitive_map` | Trigger decay cycle |
| `cognitive_map_stats` | Aggregate statistics |

All runners return `{success: true/false, ...}` hashes.

## Actors

### `Actors::Decay`
- Subclass of `Legion::Extensions::Actors::Every`
- Interval: `60` seconds
- Calls `Runners::CognitiveMap#update_cognitive_map` (decay_all)
- `run_now? = false`, `use_runner? = false`

## Integration Points

- `lex-tick` `memory_retrieval` phase: use `find_path` / `familiar_locations` to surface relevant context
- `lex-memory`: semantic traces can be represented as map locations; Hebbian links become edges
- `lex-dream` association walks can traverse the cognitive map directly
- `switch_context` enables multi-domain reasoning (one context per active problem space)

## Development Notes

- `Client` instantiates `@cognitive_map_store = Helpers::CognitiveMapStore.new`
- Path cache is LRU-capped at `MAX_PATHS_CACHED` entries; affected entries are cleared on `decay_all` prune
- `FAMILIARITY_DECAY = 0.005` is slow by design — locations persist for many cycles before becoming candidates for pruning
- `MAX_CONTEXTS = 10` — context switch to a new name creates an empty map; old contexts persist in memory
- Dijkstra uses inverse-familiarity as edge weight (high familiarity = low cost = preferred path)
