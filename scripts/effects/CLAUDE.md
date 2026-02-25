# Effects — CLAUDE.md

## scan_effect.gd

**Node type:** `Node2D` (created in code, not a scene)
**Spawned by:** `ScannerComponent.perform_scan()`

```gdscript
var scan_effect := Node2D.new()
scan_effect.set_script(preload("res://scripts/effects/scan_effect.gd"))
scan_effect.max_radius = scan_radius       # 80px by default
scan_effect.global_position = player.global_position
get_tree().current_scene.add_child(scan_effect)
```

The effect self-destructs after playing (should call `queue_free()` internally).

---

## CPUParticles2D pattern (used in drill_component.gd)

Preferred approach for one-shot effects — no scene file needed:

```gdscript
var particles := CPUParticles2D.new()
particles.emitting = true
particles.one_shot = true
particles.finished.connect(particles.queue_free)  # Auto-cleanup
get_tree().root.add_child(particles)
```

### Dig dust params
```gdscript
amount = 12, lifetime = 0.6, explosiveness = 0.9
direction = Vector2(0, -1), spread = 60.0
initial_velocity = (20.0, 50.0)
gravity = Vector2(0, 40)
scale_amount = (2.0, 4.0)
color = Color(0.65, 0.5, 0.3, 0.8)  # Brown
```

### Gold sparks params
```gdscript
amount = 16, lifetime = 0.8, explosiveness = 0.95
direction = Vector2(0, -1), spread = 180.0
initial_velocity = (40.0, 90.0)
gravity = Vector2(0, 60)
scale_amount = (1.0, 2.5)
color_ramp = Gradient(gold → transparent orange)
```

---

## Adding new effects

Two options:

**Option A — Script on Node2D (for animated effects)**
Use when the effect needs `_process` or `_draw` logic (like scan_effect expanding ring).

**Option B — CPUParticles2D in code (for particle bursts)**
Use when it's a simple spray of particles. No scene file, no extra assets.

**Do not** use `GPUParticles2D` — project targets modest desktop hardware, CPUParticles2D is sufficient and more predictable.
