# Collectibles — CLAUDE.md

## gold_nugget.gd

**Node type:** `Area2D`
**Scene:** `scenes/mining/gold_nugget.tscn`
**Spawned by:** `DrillComponent.spawn_gold_nugget()`

### Lifecycle
```
DrillComponent.spawn_gold_nugget(tile_pos, amount)
    → instantiate gold_nugget.tscn
    → set nugget.gold_value = amount
    → add to "nugget_container" group node (or scene root as fallback)
        ↓
_ready(): start pulsating scale tween (loops forever)
        ↓
_process(): move toward player (200px/s, normalized direction)
        ↓
_on_body_entered(player): collect()
        ↓
collect():
    EventBus.gold_collected.emit(gold_value)
    shrink tween → queue_free
```

### Movement
Uses `normalized()` direction vector + `global_position += direction * speed * delta`. Not lerp — constant speed, doesn't slow down near player. This means nuggets do pass through terrain tiles (Area2D, no collision with terrain).

### Visual
`_draw()` is called every frame (via `queue_redraw()` in `_process`):
```gdscript
draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.85, 0.2, 0.3))  # Outer glow
draw_circle(Vector2.ZERO,  6.0, Color(1.0, 0.90, 0.4, 0.4))  # Inner glow
```
The actual sprite/shape is defined in the `.tscn` scene. `_draw()` adds the soft glow on top.

### `is_collected` guard
Set to `true` in `collect()` before emitting the signal. Prevents double-collection if two collision events fire in the same frame.

### `gold_value`
Set externally by `DrillComponent` before adding to scene:
```gdscript
nugget.gold_value = amount  # from terrain_manager.dig_tile() result
```
Default value is `10` but should always be overridden.

### Container lookup
```gdscript
var container = get_tree().get_first_node_in_group("nugget_container")
if container:
    container.add_child(nugget)
else:
    get_tree().root.add_child(nugget)  # Fallback
```
If nuggets aren't appearing, check that a node in `mining_scene.tscn` is in the `"nugget_container"` group.
