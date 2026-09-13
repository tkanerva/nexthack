# NextHack - Actor-Based Roguelike Game

An Elixir/Phoenix implementation of a roguelike game with a true actor model architecture.

## Overview

NextHack is a conversion of the Python-based pyhack game to Elixir, leveraging Elixir's built-in actor model (GenServer) to create a more scalable and concurrent architecture.

### Key Features

- **True Actor Model**: Every monster, player, and game entity runs as a separate Erlang process
- **Message Passing**: All communication happens via Elixir's message passing
- **Concurrent Game Loop**: Monsters move asynchronously
- **Fault Tolerance**: Built on OTP principles for robustness
- **Scalable Architecture**: Easy to add more entity types and game mechanics

## Architecture

### Python vs Elixir Comparison

**Python Architecture (Original)**:
- Single "world" object holding references to all entities
- Sequential game loop where monsters move one after another
- Tight coupling between entities and world state
- Limited concurrency

**Elixir Architecture (NextHack)**:
- **Supervision Tree**: Manages all game actors
- **Player Actor**: Single GenServer for player state and behavior
- **Monster Actors**: Each monster is a separate GenServer process
- **Trap Actors**: Each trap is a separate GenServer process
- **World Coordinator**: Manages game state and coordination
- **Message Bus**: All communication via structured messages

### Component Breakdown

1. **`Nexthack.Monster`**: Base monster actor with concrete types (Goblin, Orc, Bat)
2. **`Nexthack.Player`**: Player actor extending monster functionality
3. **`Nexthack.Trap`**: Trap actor with 15 different trap types
4. **`Nexthack.World`**: Game coordination and supervision tree
5. **`Nexthack.CLI`**: Simple terminal-based interface
6. **`Nexthack.Message`**: Message structures for inter-actor communication

## Current Features

✅ **Actor-Based Architecture** - Every entity (player, monsters, traps) is a separate GenServer process

✅ **Monster Actors** - Goblin, Orc, and Bat monsters with independent behavior:
  - Random movement
  - Combat with AC-based hit chance
  - Damage resistance/weakness (e.g., undead resist fire)
  - Status effects (sleep, slow, haste)
  - Asynchronous movement

✅ **Trap System** - 15 different trap types that send messages to entities:
  - **Pit & Spiked Pit**: Fall damage with stuck effect
  - **Arrow & Dart Traps**: Ranged attacks with accuracy checks
  - **Fire Trap**: Burns entities for damage
  - **Sleeping Gas**: Puts entities to sleep
  - **Teleportation**: Randomly teleports entities
  - **Anti-Magic**: Cancels magic effects
  - **Web**: Sticks and slows entities
  - **Rolling Boulder**: Heavy damage trap
  - **Magic Portal**: Teleports through dimensional gateway
  - **Trapdoor**: Falls to lower level
  - **Stairs Down/Up**: Ascend/descend levels
  - **Level Teleporter**: Random level change

✅ **Message Passing** - All communication via Elixir's built-in messaging:
  - Attack messages with damage types
  - Status effect messages
  - Teleportation messages
  - Cancellation messages
  - Broadcast messages for logging

✅ **Game Loop** - Concurrent monster movement and game state management

## Installation

```bash
# Clone the repository
git clone https://github.com/tkanerva/nexthack.git
cd nexthack

# Install dependencies
mix deps.get

# Start the game
mix run -e "Nexthack.start"
```

## Gameplay

- **Movement**: Use WASD or arrow keys to move
- **Traps**: Step on traps to trigger their effects
- **Objective**: Survive by defeating all monsters
- **Game Over**: When player HP reaches 0 or all monsters are defeated

## How Traps Work

1. **Trap Placement**: Traps are placed randomly on the map at game start
2. **Triggering**: When an entity moves to a trap's position, the world checks for traps
3. **Message Sending**: The trap sends appropriate messages to the entity:
   - Attack messages for damage
   - Status effect messages for effects like sleep, stuck, slow
   - Teleport messages for position changes
   - Cancel messages for anti-magic effects
4. **Entity Reaction**: The entity receives the messages and reacts appropriately:
   - Takes damage and updates HP
   - Applies status effects with durations
   - Updates position for teleportation
   - Handles cancellation effects

## Development

### Running Tests

```bash
mix test
```

### Running in Watch Mode

```bash
mix test.watch
```

### Starting Interactive Shell

```bash
iex -S mix
```

Then in the shell:
```elixir
Nexthack.start
```

## Architecture Benefits

1. **Concurrency**: Monsters and traps operate independently
2. **Fault Isolation**: One actor crashing doesn't affect others
3. **Scalability**: Easy to add more entities without performance impact
4. **Maintainability**: Clear separation of concerns
5. **Testability**: Each actor can be tested in isolation

## Performance Characteristics

- **Process Lightweight**: Erlang processes are very lightweight (memory efficient)
- **Message Passing**: Fast inter-process communication
- **Scheduling**: Erlang's scheduler handles process concurrency
- **Scaling**: Can easily handle hundreds of monster and trap processes

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Original Python implementation: tkanerva/pyhack
- Elixir/Erlang community for excellent tools and documentation
- NetHack community for inspiration and game design patterns

## Future Enhancements

1. **Items**: Add potions, weapons, and armor as separate actors
2. **Spells**: Magic system with cooldowns and effects
3. **Prayer**: Divine intervention system (from the original pray.py)
4. **Better Rendering**: Full-screen terminal rendering with NCurses
5. **Persistent State**: Save/load game functionality
6. **Multiplayer**: Networked gameplay using Elixir's distributed features
7. **More Monsters**: Expand monster variety and behaviors
8. **Trap Disarmament**: Player can attempt to disarm traps
9. **Trap Visibility**: Traps can be seen/revealed
10. **Advanced AI**: Smarter monster behavior and tactics