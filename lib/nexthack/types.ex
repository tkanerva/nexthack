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

  # Item lifecycle messages (the item system, see lib/nexthack/object.ex)
  defmodule ItemSpawned do
    @type t :: %__MODULE__{
      type: :item_spawned,
      item_pid: pid() | nil,
      otype: atom(),
      pos: Nexthack.Position.t(),
      source: Nexthack.EntityID.t()
    }
    defstruct type: :item_spawned, item_pid: nil, otype: nil, pos: {0, 0}, source: ""
  end

  defmodule ItemPickedUp do
    @type t :: %__MODULE__{
      type: :item_picked_up,
      item_pid: pid() | nil,
      carrier: Nexthack.EntityID.t(),
      pos: Nexthack.Position.t()
    }
    defstruct type: :item_picked_up, item_pid: nil, carrier: "", pos: {0, 0}
  end

  defmodule ItemDropped do
    @type t :: %__MODULE__{
      type: :item_dropped,
      item_pid: pid() | nil,
      pos: Nexthack.Position.t(),
      source: Nexthack.EntityID.t()
    }
    defstruct type: :item_dropped, item_pid: nil, pos: {0, 0}, source: ""
  end

  defmodule ItemConsumed do
    @type t :: %__MODULE__{
      type: :item_consumed,
      item_id: Nexthack.EntityID.t(),
      carrier: Nexthack.EntityID.t()
    }
    defstruct type: :item_consumed, item_id: "", carrier: ""
  end

  defmodule ItemEquipped do
    @type t :: %__MODULE__{
      type: :item_equipped,
      item_pid: pid() | nil,
      slot: atom(),
      carrier: Nexthack.EntityID.t()
    }
    defstruct type: :item_equipped, item_pid: nil, slot: :weapon, carrier: ""
  end

  defmodule ItemUnequipped do
    @type t :: %__MODULE__{
      type: :item_unequipped,
      item_pid: pid() | nil,
      slot: atom() | nil,
      carrier: Nexthack.EntityID.t()
    }
    defstruct type: :item_unequipped, item_pid: nil, slot: nil, carrier: ""
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

  @doc """
  Send a broadcast log message to the world actor. This is the
  message-bus primitive the actors use for player-visible events.
  """
  def broadcast(%Broadcast{} = msg, world_pid) when is_pid(world_pid) do
    send(world_pid, {:broadcast, msg.message, msg.source})
  end

  def broadcast(%Broadcast{} = _msg, _world_pid), do: :ok
end
