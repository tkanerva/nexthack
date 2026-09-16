# NextHack - Actor-Based Roguelike Game

An Elixir/Phoenix implementation of a roguelike game with a true actor model architecture.

## Overview

NextHack is a conversion of the Python-based pyhack game to Elixir, leveraging Elixir's built-in actor model (GenServer) to create a more scalable and concurrent architecture.

### Key Features

- **True Actor Model**: Every monster, player, trap, spell and **item** runs as a separate Erlang process
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
- **Bolt Actors**: Each spell/attack is a separate GenServer process that moves across the map
- **Item Actors**: Each object (potion, sword, boulder, ...) is a separate GenServer process
- **Inventory Actors**: Each carrier (player, monster) owns an inventory actor
- **World Coordinator**: Manages game state and coordination (including floor item piles)
- **Message Bus**: All communication via structured messages

### Component Breakdown

1. **`Nexthack.Monster`**: Base monster actor with concrete types (Goblin, Orc, Bat)
2. **`Nexthack.Player`**: Player actor extending monster functionality, owns an inventory
3. **`Nexthack.Trap`**: Trap actor with 15 different trap types
4. **`Nexthack.Zap`**: Spell/attack actor with moving bolt actors
5. **`Nexthack.World`**: Game coordination and supervision tree
6. **`Nexthack.CLI`**: Simple terminal-based interface
7. **`Nexthack.Message`**: Message structures for inter-actor communication
8. **`Nexthack.Object`**: Item actor (the `struct obj` from NetHack)
9. **`Nexthack.ObjectClass`**: Object classes (`enum obj_class_types`)
10. **`Nexthack.ObjectDB`**: Object database (`objects[]` / `obj_descr[]`)
11. **`Nexthack.ObjectFactory`**: Item creation (`newobj()` / `mkobj()`)
12. **`Nexthack.Inventory`**: Per-carrier inventory (the `invent.c` core)
13. **`Nexthack.ItemAction`**: Item actions menu (the `iactions.c` core)

## The Item System (NetHack conversion)

The item system converts NetHack's `invent.c` and `iactions.c` to the
actor model: instead of one global object list linked with `nobj` /
`nexthere` / `cobj` pointers, **every item is an Erlang process** and
every carrier (hero, monster) owns an **inventory actor**.

### NetHack -> NextHack mapping

| NetHack (C)                                | NextHack (Elixir)                                   |
| ------------------------------------------ | --------------------------------------------------- |
| `struct obj` (include/obj.h)               | `Nexthack.Object` (one GenServer per item)          |
| `enum obj_class_types` (include/defsym.h)  | `Nexthack.ObjectClass`                              |
| `objects[]` / `obj_descr[]` (objdata.c)    | `Nexthack.ObjectDB`                                 |
| `newobj()` / `mkobj()` (mkobj.c)           | `Nexthack.ObjectFactory`                            |
| `gi.invent` list + `invlet`                | `Nexthack.Inventory` (per carrier, letters = map keys) |
| `addinv()` (stack merging, letter assign)  | `Inventory.add_item/2` (`:gold` / `{:merged, let}` / `{:ok, let}`) |
| `pick_obj()` (weight check)                | `Inventory.pick_up/2` (`{:error, :too_heavy}`)      |
| `dropobj()`                                | `Inventory.drop/3` (+ `{:drop_floor_item, ...}` to the world) |
| `invent()` (display)                       | `Inventory.list/1` (NetHack-style lines)            |
| `doorganize()` / `#organize`               | `Inventory.organize/1` (reassigns letters)          |
| `#altadjust` (adjust_split)                | `Inventory.split_stack/3`                           |
| `owornmask` (wield.c / do.c)               | `Object.equip/2`, `Inventory.equip/3`, slots        |
| `mergable()` (object.c)                    | `Object.mergable?/2` (BUC + spe + name rules)       |
| `xname()` / `simpleonames()`               | `Object.describe/1` (`"3 potions of healing (blessed)"`) |
| `itemactions()` (iactions.c)               | `ItemAction.actions_for/2` (`%Action{letter, action, text}`) |
| `itemactions_pushkeys()`                   | `ItemAction.execute/4` (skeleton dispatcher)        |
| `mon->minvent`                             | `Nexthack.Monster.inventory/1` (drops loot on death)|
| `nexthere` floor piles                     | `World.spawn_item/4`, `World.items_at/2`, `World.take_top_item_at/3` |

### How it works

1. **Items are actors.** A potion on the floor, in the pack, or inside a
   bag of holding is always the *same* process; only its `:where`
   (`:free | :floor | :contained | :invent | :minvent | :buried`),
   `:pos`, `:carrier` and `:container` fields change. When a stack runs
   out of quantity (or wand charges) the process terminates -- the
   Elixir equivalent of `obfree()`.
2. **The inventory owns the letters.** `invlet` is a map key inside the
   inventory actor (`?$` is reserved for gold, then `?a..?z`, `?A..?Z`),
   which makes `#organize` a pure state update and keeps items reusable
   between floor, containers and inventories.
3. **Stacking follows NetHack's rules** (`mergable()`): same type, same
   blessed/cursed state, same enchantment when both are known, and
   compatible personal names. Coins always merge into `$`.
4. **Item actions are data.** `ItemAction.actions_for/2` mirrors the
   `itemactions()` if-chain (quaff, dip, read, wield, wear, tip, invoke,
   zap, sacrifice, ...) and returns the menu entries; `execute/4`
   performs the actions the skeleton already supports and reports the
   rest as `:not_implemented`.
5. **The world keeps the floor piles** (`nexthere`): dropping sends
   `{:drop_floor_item, pos, item, carrier}` to the world, picking up
   takes the top item of the pile (`take_top_item_at/3`) and hands it to
   the inventory.

### Playing with items in the CLI

- `i` - show your inventory (NetHack-style, class-sorted, gold on top)
- `x` - show the item actions menu for one item, then pick an action
  (drop `d`, quaff `q`, eat `e`, read `r`, wield `w`, wear `W`, ...)
- `p` - pick up the top item at your position

The player starts with a dagger, rations and 100 gold pieces, and the
world scatters a few random items on the floor at game start.

### Current features

✅ **Actor-Based Architecture** - Every entity (player, monsters, traps, spells, items) is a separate GenServer process

✅ **Monster Actors** - Goblin, Orc, and Bat monsters with independent behavior:
  - Random movement
  - Combat with AC-based hit chance
  - Damage resistance/weakness (e.g., undead resist fire)
  - Status effects (sleep, slow, haste)
  - Asynchronous movement
  - Carried inventory (minvent); belongings are dropped when the monster dies

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

✅ **Zap/Spell System** - 14 different spell types with moving bolt actors:
  - **Fire Bolt**: Travels 8 squares, deals fire damage
  - **Lightning Bolt**: Travels 6 squares, deals lightning damage
  - **Cone of Cold**: Travels 10 squares, deals cold damage
  - **Death Ray**: Travels 8 squares, deals heavy death damage
  - **Force Bolt**: Travels 12 squares, deals magic missile damage
  - **Sleep**: Travels 8 squares, puts entities to sleep
  - **Cancellation**: Travels 8 squares, cancels magic effects
  - **Teleport**: Instantly teleports target entity
  - **Invisibility**: Travels 8 squares, makes entity invisible
  - **Polymorph**: Travels 8 squares, transforms entity
  - **Slow**: Travels 8 squares, slows entity
  - **Haste**: Travels 8 squares, hastes entity
  - **Undead Turning**: Travels 8 squares, turns undead and deals damage

✅ **Moving Bolt Actors** - Spells traverse the map:
  - Bolts move in specified direction (N, S, E, W, diagonals)
  - Check for collisions with entities at each step
  - Apply effects when hitting entities
  - Stop after reaching maximum range
  - Multiple bolts can travel simultaneously

✅ **Item System (skeleton)** - Items as actors, inventories per carrier:
  - Object database covering all 16 object classes (~260 objects)
  - Item actors with quantity, enchantment/charges, BUC, discovery
    state, contents (containers), worn slots and personal names
  - Inventories with letter assignment, stack merging, weight limit,
    gold purse, class-sorted display, #organize and #altadjust
  - Equipment slots (weapon, armor, rings, amulet, ...) with automatic
    swapping (wielding a new sword unwields the old one)
  - Item actions menu converted from iactions.c (27 actions) with a
    working dispatcher for drop/quaff/eat/read/wield/wear/takeoff/tip
  - Floor item piles in the world; pick up / drop from the CLI
  - Monsters carry loot and drop it on death

✅ **Message Passing** - All communication via Elixir's built-in messaging:
  - Attack messages with damage types
  - Status effect messages
  - Teleportation messages
  - Cancellation messages
  - Floor item messages (`{:drop_floor_item, pos, item, carrier}`)
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

- **Movement**: Use WASD to move
- **Inventory**: `i` shows your items (gold first, then NetHack class order)
- **Item actions**: `x` shows everything you can do with an item, then performs it
- **Pickup**: `p` picks up the top item at your position
- **Traps**: Step on traps to trigger their effects
- **Spells**: Cast spells that create moving bolt actors
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

## How Zaps/Spells Work

1. **Spell Creation**: Player casts a spell, creating a bolt actor
2. **Bolt Initialization**: Bolt starts at caster's position with direction
3. **Movement**: Bolt moves one square in specified direction
4. **Collision Check**: At each position, bolt checks for entities
5. **Effect Application**: If entities found, bolt applies appropriate effects:
   - Damage messages for damaging spells
   - Status effect messages for buff/debuff spells
   - Teleport messages for teleport spells
   - Cancel messages for cancellation spells
6. **Range Limit**: Bolt stops after reaching maximum range
7. **Completion**: Bolt terminates after reaching range or hitting target

## How Items Work

1. **Item Creation**: `ObjectFactory.new(:potion_of_healing, quantity: 3)`
   starts a GenServer holding the item's state (the C `struct obj`)
2. **Floor Piles**: The world keeps a pile per position; `spawn_item/4`
   adds to it, `take_top_item_at/3` pops the top item for a carrier
3. **Picking Up**: `Player.pick_up_here/1` asks the world for the top
   item at the player's position, then the inventory checks the carry
   weight limit (`pick_up/2`) before assigning a letter (or merging
   into an existing stack, or collecting gold into `$`)
4. **Using Items**: item actions route through `ItemAction.execute/4`;
   consuming items (quaff/eat/read) remove them from the pack and
   `Object.consume/2` decrements the quantity -- at zero the item
   process stops, exactly like `obfree()` in NetHack
5. **Dropping**: `Inventory.drop/3` marks the items `:floor` and tells
   the world to put them on the floor pile
6. **Equipment**: `Object.equip/2` sets the worn slots (owornmask); the
   inventory swaps out whatever was in the slot before

## Development

### Running Tests

```bash
mix test
```

The item system is covered by:
- `test/nexthack/object_test.exs` - item actors, xname-style display,
  charges, containers, merging rules
- `test/nexthack/inventory_test.exs` - letters, stacking, gold, weight
  limit, drop/pick, class-sorted display, #organize, #altadjust, equip
- `test/nexthack/item_action_test.exs` - the iactions.c action catalog
  and the execute dispatcher
- `test/nexthack/object_db_test.exs` - object database invariants

### Running in Watch Mode

```bash
mix test.watch
```

### Starting Interactive Shell

```
iex -S mix
```

Then in the shell:
```elixir
Nexthack.start
```

## Architecture Benefits

1. **Concurrency**: Monsters, traps, spells and items operate independently
2. **Fault Isolation**: One actor crashing doesn't affect others
3. **Scalability**: Easy to add more entities without performance impact
4. **Maintainability**: Clear separation of concerns
5. **Testability**: Each actor can be tested in isolation

## Performance Characteristics

- **Process Lightweight**: Erlang processes are very lightweight (memory efficient)
- **Message Passing**: Fast inter-process communication
- **Scheduling**: Erlang's scheduler handles process concurrency
- **Scaling**: Can easily handle hundreds of monster, trap, spell and item processes simultaneously

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Original Python implementation: tkanerva/pyhack
- Elixir/Erlang community for excellent tools and documentation
- NetHack community for inspiration and game design patterns (and for
  `invent.c` / `iactions.c` / `obj.h`, which the item system converts)

## Future Enhancements

1. **Item Effects**: Implement the actual potion/scroll/wand effects
   (the `execute/4` dispatcher already knows where they go)
2. **Throwing**: Wire `:throw` / `:fire` actions to the existing bolt
   (zap) actors so items fly across the map
3. **Container Interaction**: Open/tip containers from the CLI
   (the `tip_container` action already empties them)
4. **Better Rendering**: Full-screen terminal rendering with NCurses
5. **Persistent State**: Save/load game functionality
6. **Multiplayer**: Networked gameplay using Elixir's distributed features
7. **More Monsters**: Expand monster variety and behaviors
8. **Monster AI with Loot**: Monsters that pick up, carry and drop
   items (the minvent plumbing is already in place)
9. **Trap Disarmament**: Player can attempt to disarm traps
10. **Trap Visibility**: Traps can be seen/revealed
11. **Advanced AI**: Smarter monster behavior and tactics
12. **Shops**: The `:buy` item action is stubbed and ready for a
    shopkeeper actor
