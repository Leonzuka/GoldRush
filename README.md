# GoldRush

A 2D mining game inspired by *Turmoil*, built with Godot 4.5.

## Game Overview

**GoldRush** puts you in the boots of a 19th-century prospector competing for valuable mining plots in the California Gold Rush. Bid for land in auctions, prospect for hidden gold deposits, drill through layers of earth, and race against time to extract maximum riches before the round ends.

## Core Gameplay

1. **Auction Phase** - Bid against NPCs for promising land plots
2. **Prospecting** - Use your scanner to detect hidden gold deposits
3. **Extraction** - Drill through terrain to collect gold nuggets
4. **Collection** - Gather gold before time runs out or storage fills
5. **Progression** - Maintain profits to continue bidding in future rounds

## Controls

### Movement
- **W/A/S/D** or **Arrow Keys** - Move character
- **Mouse** - Aim drill direction

### Actions
- **Left Click (Hold)** - Drill terrain
- **Spacebar** - Scan for gold deposits (3s cooldown)

### Debug (Development Build Only)
- **F12** - Toggle debug overlay (show all gold positions)
- **F1** - Add $1,000

## System Requirements

### Minimum
- **OS:** Windows 7/8/10/11, macOS 10.12+, Linux (Ubuntu 18.04+)
- **CPU:** Intel Core i3 or equivalent
- **RAM:** 4 GB
- **Graphics:** Integrated graphics with OpenGL 3.3 support
- **Storage:** 100 MB

### Recommended
- **OS:** Windows 10/11, macOS 11+, Linux (recent distro)
- **CPU:** Intel Core i5 or equivalent
- **RAM:** 8 GB
- **Graphics:** Dedicated GPU with OpenGL 4.5 support
- **Storage:** 200 MB

## Project Structure

```
GoldRush/
├── scenes/          # Godot scene files (.tscn)
│   ├── main/        # Main menu and entry point
│   ├── auction/     # Auction interface
│   ├── mining/      # Core gameplay scenes
│   └── ui/          # UI components
│
├── scripts/         # GDScript source files
│   ├── autoload/    # Singleton systems
│   ├── systems/     # Core game systems
│   ├── player/      # Player components
│   ├── ui/          # UI controllers
│   └── collectibles/# Collectible items
│
├── resources/       # Godot resources (.tres, .gd)
├── assets/          # Sprites, audio, fonts
└── shaders/         # Custom shaders (.gdshader)
```

## Development Status

**Current Version:** 0.1.0 MVP (In Development)

### Implemented Features
- ✅ Land auction system with NPC bidding AI
- ✅ Procedural terrain generation
- ✅ Tile-based drilling mechanics
- ✅ Gold detection scanner
- ✅ Resource collection system
- ✅ Session timer and storage limits
- ✅ Round progression loop

### Planned Features (Post-MVP)
- 🔲 Market system with dynamic gold pricing
- 🔲 Upgrade shop (drill speed, storage, scanner)
- 🔲 Save/load game functionality
- 🔲 Shader-based smooth terrain digging
- 🔲 Particle effects and polish
- 🔲 Sound effects and music
- 🔲 Hand-painted art assets
- 🔲 Gamepad support

## Building from Source

### Prerequisites
- [Godot 4.5](https://godotengine.org/download) or later
- Git (for cloning repository)

### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/goldrush.git
   cd goldrush
   ```

2. Open the project in Godot:
   - Launch Godot Engine
   - Click "Import"
   - Navigate to the project folder
   - Select `project.godot`

3. Run the project:
   - Press **F5** or click "Run Project"
   - Or press **F6** to run current scene

### Exporting
1. Open **Project → Export**
2. Select platform (Windows, macOS, Linux)
3. Configure export settings
4. Click "Export Project"

## Game Balance

### Starting Conditions
- **Money:** $1,000
- **Round Time:** 2 minutes
- **Storage:** 100 gold units
- **Drill Speed:** 3 tiles/second
- **Scan Radius:** 5 tiles (~80 pixels)

### Plot Types
| Type | Richness | Deposits | Price Range |
|------|----------|----------|-------------|
| Poor | 0.5-0.7x | 11-16 | $100-$200 |
| Average | 0.8-1.2x | 18-27 | $200-$350 |
| Rich | 1.3-1.5x | 29-34 | $350-$500 |

### Difficulty Scaling
- **Round 1:** 20% NPC bid chance (Tutorial)
- **Round 4:** 40% NPC bid chance (Competitive)
- **Round 7+:** 60% NPC bid chance (Expert)

## Architecture

### Design Patterns
- **Signal-Driven Communication** - EventBus singleton for loose coupling
- **State Machine** - GameManager handles game flow states
- **Component Pattern** - Player has modular drill/scanner components
- **Resource Pattern** - PlotData for auction plot properties

### Core Systems
- **GameManager** - Game state, session data, scene transitions
- **EventBus** - Global signal hub for inter-system communication
- **TerrainManager** - Procedural generation, tile manipulation
- **AuctionSystem** - Plot generation, NPC AI
- **MiningSession** - Timer, storage limits, round end logic

### Performance Targets
- **60 FPS** on modest desktop hardware
- **100x50 tile** terrain with minimal overhead
- **30+ gold deposits** detected instantly by scanner
- **20+ collectibles** on screen without frame drops

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow code style (see `claude.md` for conventions)
4. Test your changes thoroughly
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style
- **Variables/Functions:** snake_case (`gold_deposits`, `dig_tile()`)
- **Classes:** PascalCase (`TerrainManager`, `PlotData`)
- **Constants:** UPPER_SNAKE_CASE (`STARTING_MONEY`)
- **Documentation:** GDScript doc comments (`##` for public APIs)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

### Development
- **Game Design:** [Your Name]
- **Programming:** [Your Name]
- **Art:** Placeholder assets (Godot primitives)

### Inspiration
- **Turmoil** by Gamious - Original inspiration for auction/mining gameplay

### Tools
- **Engine:** [Godot Engine 4.5](https://godotengine.org/)
- **IDE:** Godot built-in editor
- **Version Control:** Git

## Contact

- **Project Repository:** https://github.com/yourusername/goldrush
- **Issue Tracker:** https://github.com/yourusername/goldrush/issues
- **Email:** your.email@example.com

## Acknowledgments

Special thanks to:
- The Godot Engine community for excellent documentation
- The Turmoil developers for the original gameplay inspiration
- All playtesters and contributors

---

**Status:** 🚧 In Development | **Version:** 0.1.0 MVP | **Last Updated:** 2025-12-21
