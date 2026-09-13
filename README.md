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
- **World Coordinator**: Manages game state and coordination
- **Message Bus**: All communication via structured messages

### Component Breakdown

1. **`Nexthack.Monster`**: Base monster actor with concrete types (Goblin, Orc, Bat)
2. **`Nexthack.Player`**: Player actor extending monster functionality
3. **`Nexthack.World`**: Game coordination and supervision tree
4. **`Nexthack.CLI`**: Simple terminal-based interface
5. **`Nexthack.Message`**: Message structures for inter-actor communication

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
- **Objective**: Survive by defeating all monsters
- **Game Over**: When player HP reaches 0 or all monsters are defeated

## Future Enhancements

1. **Traps**: Implement trap actors with async triggering
2. **Items**: Add potions, weapons, and armor as separate actors
3. **Spells**: Magic system with cooldowns and effects
4. **Prayer**: Divine intervention system (from the original pray.py)
5. **Better Rendering**: Full-screen terminal rendering with NCurses
6. **Persistent State**: Save/load game functionality
7. **Multiplayer**: Networked gameplay using Elixir's distributed features
8. **More Monsters**: Expand monster variety and behaviors

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

1. **Concurrency**: Monsters can move independently
2. **Fault Isolation**: One monster crashing doesn't affect others
3. **Scalability**: Easy to add more entities without performance impact
4. **Maintainability**: Clear separation of concerns
5. **Testability**: Each actor can be tested in isolation

## Performance Characteristics

- **Process Lightweight**: Erlang processes are very lightweight (memory efficient)
- **Message Passing**: Fast inter-process communication
- **Scheduling**: Erlang's scheduler handles process concurrency
- **Scaling**: Can easily handle hundreds of monster processes

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Original Python implementation: tkanerva/pyhack
- Elixir/Erlang community for excellent tools and documentation
- NetHack community for inspiration and game design patterns
