# Types and enums for the game

# Damage types
defmodule Nexthack.DamageType do
  @type t :: :magic_missile | :fire | :cold | :sleep | :death | :lightning | :poison | :acid | :cancellation
end

# Trap types
defmodule Nexthack.TrapType do
  @type t :: :pit | :spiked_pit | :trapdoor | :arrow_trap | :dart_trap | :fire_trap |
                  :sleeping_gas | :teleportation | :anti_magic | :web | :rolling_boulder |
                  :magic_portal | :level_teleporter | :stairs_down | :stairs_up
end

# Object types
defmodule Nexthack.ObjectType do
  @type t :: :wand | :scroll | :potion | :weapon | :armor | :tool | :food | :corpse |
                  :egg | :statue | :ring | :amulet | :gem | :boulder | :book
end

# Position type
defmodule Nexthack.Position do
  @type t :: {integer(), integer()}
end

# Entity IDs
defmodule Nexthack.EntityID do
  @type t :: String.t()
end

# Message types

defmodule Nexthack.Message do
  # Attack message
  defmodule Attack do
    @type t :: %__MODULE__{ 
      type: :attack,
      damage_type: Nexthack.DamageType.t(),
      power: integer(),
      source: Nexthack.EntityID.t(),
      reflect: boolean()
    }
    defstruct type: :attack, damage_type: :fire, power: 1, source: "", reflect: false
  end

  # Status effect message
  defmodule StatusEffect do
    @type t :: %__MODULE__{ 
      type: :status,
      effect: :sleep | :slow | :haste | :teleport | :polymorph | :cancel | :invisibility,
      duration: integer(),
      target_pid: Nexthack.EntityID.t()
    }
    defstruct type: :status, effect: :sleep, duration: 10, target_pid: ""
  end

  # Terrain interaction message
  defmodule TerrainInteraction do
    @type t :: %__MODULE__{ 
      type: :terrain,
      action: :melt | :freeze | :evaporate | :break_door | :open_door | :reveal_secret,
      pos: Nexthack.Position.t(),
      source: Nexthack.EntityID.t()
    }
    defstruct type: :terrain, action: :reveal_secret, pos: {0, 0}, source: ""
  end

  # Inventory update message
  defmodule InventoryUpdate do
    @type t :: %__MODULE__{ 
      type: :inventory,
      action: :add | :remove | :equip | :unequip | :drop | :pickup | :merge,
      item_id: Nexthack.EntityID.t(),
      to: Nexthack.EntityID.t() | nil,
      from: Nexthack.EntityID.t() | nil
    }
    defstruct type: :inventory, action: :add, item_id: "", to: nil, from: nil
  end

  # Query message
  defmodule Query do
    @type t :: %__MODULE__{ 
      type: :query,
      query: :get_hp | :get_pos | :get_status | :list_inventory | :check_resistance,
      target_pid: Nexthack.EntityID.t()
    }
    defstruct type: :query, query: :get_hp, target_pid: ""
  end

  # Trap specific messages
  defmodule TrapPlaced do
    @type t :: %__MODULE__{ 
      type: :trap_placed,
      trap_id: Nexthack.EntityID.t(),
      pos: Nexthack.Position.t(),
      trap_type: Nexthack.TrapType.t()
    }
    defstruct type: :trap_placed, trap_id: "", pos: {0, 0}, trap_type: :pit
  end

  defmodule TrapTriggered do
    @type t :: %__MODULE__{ 
      type: :trap_triggered,
      trap_id: Nexthack.EntityID.t(),
      entity_pid: Nexthack.EntityID.t(),
      effect_type: atom(),
      damage: integer()
    }
    defstruct type: :trap_triggered, trap_id: "", entity_pid: "", effect_type: :pit, damage: 0
  end

  defmodule TrapDisarmed do
    @type t :: %__MODULE__{ 
      type: :trap_disarmed,
      trap_id: Nexthack.EntityID.t(),
      source: Nexthack.EntityID.t()
    }
    defstruct type: :trap_disarmed, trap_id: "", source: ""
  end

  # Broadcast message (for logging)
  defmodule Broadcast do
    @type t :: %__MODULE__{ 
      type: :broadcast,
      message: String.t(),
      source: Nexthack.EntityID.t()
    }
    defstruct type: :broadcast, message: "", source: ""
  end
end