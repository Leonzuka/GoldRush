# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GoldRush is a 2D mining game inspired by Turmoil, developed in Godot 4.4 with mobile optimization. Players dig underground, collect gold, and upgrade their equipment in an addictive progression loop.

## Project Configuration

- **Engine Version**: Godot 4.4
- **Target Platform**: Mobile (Steam and PlayStore planned)
- **Main Scene**: `Main.tscn`
- **Rendering**: Mobile-optimized

## Game Architecture

### Core Systems
- **TerrainManager.gd**: Procedural terrain generation using TileMapLayer (Godot 4.4+)
- **Player.gd**: Movement, jumping, and digging mechanics
- **GameManager.gd**: Central game state, inventory, money, and upgrade management
- **UI.gd**: HUD and shop interface management

### Key Game Mechanics
- **Digging**: Point and click with mouse to excavate blocks (max 2 tiles distance)
- **Gold Collection**: Random gold spawns in blocks, higher probability in deeper layers
- **Upgrade System**: Pickaxe speed, bag capacity, and lantern vision improvements
- **Economy**: Sell gold for money, buy upgrades to improve efficiency

## Controls
- **Arrow Keys**: Movement (left/right), jumping (up or space)
- **Left Mouse Button**: Dig at cursor position (hold to dig)
- **E**: Sell gold (at surface)  
- **T**: Open/close shop (at surface)

## Development Commands

- **Run Game**: F5 in Godot Editor
- **Edit Scenes**: Open .tscn files in Godot Editor
- **Debug**: Use Godot's built-in debugger and remote inspector

## File Structure

### Scenes
- `Main.tscn` - Main game scene with world, UI, and managers
- `Player.tscn` - Player character with collision and visual components

### Scripts
- `GameManager.gd` - Central game logic and state management
- `TerrainManager.gd` - World generation and block management
- `Player.gd` - Player controls and digging mechanics
- `UI.gd` - Interface management and shop system

### Configuration
- `project.godot` - Project settings with custom input actions
- `CONTROLES.md` - Player control reference

### Documentation
- `docs/GODOT_TILEMAPLAYER.md` - TileMapLayer migration guide and API reference

## Game Balance

### Upgrade Costs (Exponential Growth)
- **Pickaxe**: Base $50, multiplier 1.5x
- **Bag**: Base $75, multiplier 1.5x  
- **Lantern**: Base $100, multiplier 1.5x

### Gold Probability by Layer
- **Surface (Layer 0)**: 0% (grass layer)
- **Dirt (Layers 1-5)**: 10%-30% increasing with depth
- **Stone (Layer 6+)**: 35% (harder to dig, more valuable)

### Dig Times
- **Dirt**: 1.0 second base time
- **Stone**: 2.0 seconds base time
- Modified by pickaxe upgrade multiplier

## Technical Notes

- **TileMapLayer**: Uses modern Godot 4.4+ TileMapLayer instead of deprecated TileMap
- **Terrain Generation**: Programmatic tileset creation with colored rectangles
- **World Size**: 80x50 tiles (2560x1600 pixels)
- **Tile Size**: 32x32 pixels
- **Gold Value**: $10 per nugget
- **Physics**: Standard Godot 2D with gravity
- **Camera**: Follows player automatically

## Important Migration Notes

The project uses the new TileMapLayer system introduced in Godot 4.3+. Key differences:
- Single TileMapLayer node instead of TileMap with multiple layers
- Simplified API: `set_cell(pos, source, atlas)` instead of `set_cell(layer, pos, source, atlas)`
- Use `erase_cell(pos)` instead of `set_cell(layer, pos, -1)`
- Each layer is a separate node for better organization