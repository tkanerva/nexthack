defmodule Nexthack.Trap do
  @moduledoc """
  Trap actor implementation.
  Each trap runs as a separate GenServer process and sends damage messages
  to entities that trigger it.
  """
  
  use GenServer
  alias Nexthack.Message
  alias Nexthack.DamageType

  # Trap state
  defstruct [
    id: "",
    trap_type: :pit,
    pos: {0, 0},
    triggered: false,
    disarmed: false,
    seen: false,
    world_pid: nil,
    # ObjectProtocol fields
    otype: :tool,
    charges: 0,
    blessed: false,
    cursed: false,
    container: nil,
    carrier: nil
  ]

  # Trap types
  @type trap_type :: 
    :pit | :spiked_pit | :trapdoor | :arrow_trap | :dart_trap | :fire_trap |
    :sleeping_gas | :teleportation | :anti_magic | :web | :rolling_boulder |
    :magic_portal | :level_teleporter | :stairs_down | :stairs_up

  # Public API

  @doc """
  Start a trap process
  """
  def start_link(name, initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  @doc """
  Trigger the trap for an entity
  """
  def trigger(pid, entity_pid) do
    GenServer.cast(pid, {:trigger, entity_pid, self()})
  end

  @doc """
  Disarm the trap
  """
  def disarm(pid, source_pid) do
    GenServer.cast(pid, {:disarm, source_pid, self()})
  end

  @doc """
  Check if trap is triggered
  """
  def triggered?(pid) do
    GenServer.call(pid, :triggered?)
  end

  @doc """
  Check if trap is disarmed
  """
  def disarmed?(pid) do
    GenServer.call(pid, :disarmed?)
  end

  @doc """
  Get trap position
  """
  def get_position(pid) do
    GenServer.call(pid, :get_position)
  end

  @doc """
  Get trap type
  """
  def get_trap_type(pid) do
    GenServer.call(pid, :get_trap_type)
  end

  # GenServer callbacks

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:trigger, entity_pid, caller}, state) do
    if not state.triggered and not state.disarmed and state.world_pid do
      new_state = apply_trap_effect(state, entity_pid)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:disarm, source_pid, caller}, state) do
    if not state.disarmed and not state.triggered do
      new_state = %{state | disarmed: true}
      
      # Broadcast disarm
      if new_state.world_pid do
        send(new_state.world_pid, {:broadcast, 
          "#{source_pid} disarms #{state.id}", state.id})
      end
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:triggered?, _from, state) do
    {:reply, state.triggered, state}
  end

  @impl true
  def handle_call(:disarmed?, _from, state) do
    {:reply, state.disarmed, state}
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.pos, state}
  end

  @impl true
  def handle_call(:get_trap_type, _from, state) do
    {:reply, state.trap_type, state}
  end

  # Internal functions

  defp apply_trap_effect(state, entity_pid) do
    if state.triggered or state.disarmed do
      state
    else
      new_state = %{state | triggered: true}
      
      # Determine effect based on trap type
      effect_result = case state.trap_type do
        :pit -> apply_pit_trap(new_state, entity_pid)
        :spiked_pit -> apply_spiked_pit_trap(new_state, entity_pid)
        :arrow_trap -> apply_ranged_trap(new_state, entity_pid, :arrow)
        :dart_trap -> apply_ranged_trap(new_state, entity_pid, :dart)
        :fire_trap -> apply_fire_trap(new_state, entity_pid)
        :sleeping_gas -> apply_sleeping_gas_trap(new_state, entity_pid)
        :teleportation -> apply_teleportation_trap(new_state, entity_pid)
        :anti_magic -> apply_anti_magic_trap(new_state, entity_pid)
        :web -> apply_web_trap(new_state, entity_pid)
        :rolling_boulder -> apply_rolling_boulder_trap(new_state, entity_pid)
        :magic_portal -> apply_magic_portal_trap(new_state, entity_pid)
        :trapdoor -> apply_trapdoor_trap(new_state, entity_pid)
        :stairs_down -> apply_stairs_down_trap(new_state, entity_pid)
        :level_teleporter -> apply_level_teleporter_trap(new_state, entity_pid)
        :stairs_up -> apply_stairs_up_trap(new_state, entity_pid)
      end
      
      # Broadcast trap trigger
      if new_state.world_pid do
        send(new_state.world_pid, {:broadcast, 
          "#{state.id} triggers at #{inspect(state.pos)} - #{effect_result[:message]}", 
          state.id})
      end
      
      effect_result[:state]
    end
  end

  defp apply_pit_trap(state, entity_pid) do
    damage = :rand.uniform(6)
    
    # Send damage message to entity
    if state.world_pid do
      send(entity_pid, {
        :attack,
        %{
          type: :attack,
          damage_type: :acid,
          power: damage,
          source: state.id,
          reflect: false
        }
      })
    end
    
    # Apply stuck effect
    send(entity_pid, {
      :status_effect,
      %{
        type: :status,
        effect: :stuck,
        duration: 10,
        target_pid: entity_pid
      }
    })
    
    message = "falls into a pit and takes #{damage} damage!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, damage)
  end

  defp apply_spiked_pit_trap(state, entity_pid) do
    damage = :rand.uniform(12)
    
    # Send damage message to entity
    if state.world_pid do
      send(entity_pid, {
        :attack,
        %{
          type: :attack,
          damage_type: :acid,
          power: damage,
          source: state.id,
          reflect: false
        }
      })
    end
    
    # Apply stuck effect
    send(entity_pid, {
      :status_effect,
      %{
        type: :status,
        effect: :stuck,
        duration: 15,
        target_pid: entity_pid
      }
    })
    
    message = "falls into a spiked pit and takes #{damage} damage!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, damage)
  end

  defp apply_ranged_trap(state, entity_pid, proj_type) do
    # Simplified accuracy: hit chance based on random roll
    hit_chance = 70  # 70% hit chance
    if :rand.uniform(100) <= hit_chance do
      damage = if proj_type == :arrow, do: :rand.uniform(6), else: :rand.uniform(4)
      
      # Send damage message to entity
      if state.world_pid do
        send(entity_pid, {
          :attack,
          %{
            type: :attack,
            damage_type: :acid,
            power: damage,
            source: state.id,
            reflect: false
          }
        })
      end
      
      message = "is hit by #{proj_type} for #{damage} damage!"
      %{state | triggered: true}
      |> Map.put(:trigger_message, message)
      |> Map.put(:damage, damage)
    else
      message = "avoids the #{proj_type} trap!"
      %{state | triggered: true}
      |> Map.put(:trigger_message, message)
      |> Map.put(:damage, 0)
    end
  end

  defp apply_fire_trap(state, entity_pid) do
    damage = :rand.uniform(6)
    
    # Send damage message to entity
    if state.world_pid do
      send(entity_pid, {
        :attack,
        %{
          type: :attack,
          damage_type: :fire,
          power: damage,
          source: state.id,
          reflect: false
        }
      })
    end
    
    message = "is burned by fire trap for #{damage} damage!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, damage)
  end

  defp apply_sleeping_gas_trap(state, entity_pid) do
    # Send status effect message to entity
    if state.world_pid do
      send(entity_pid, {
        :status_effect,
        %{
          type: :status,
          effect: :sleep,
          duration: 25,
          target_pid: entity_pid
        }
      })
    end
    
    message = "is put to sleep by gas trap!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
  end

  defp apply_teleportation_trap(state, entity_pid) do
    # Generate random position
    new_pos = {:rand.uniform(79), :rand.uniform(23)}
    
    # Send position update message
    if state.world_pid do
      send(entity_pid, {
        :teleport,
        %{
          type: :teleport,
          new_pos: new_pos,
          source: state.id
        }
      })
    end
    
    message = "is teleported away!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
    |> Map.put(:teleported, new_pos)
  end

  defp apply_anti_magic_trap(state, entity_pid) do
    # Send cancellation message
    if state.world_pid do
      send(entity_pid, {
        :cancel,
        %{
          type: :cancel,
          source: state.id
        }
      })
    end
    
    message = "is affected by anti-magic trap!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
  end

  defp apply_web_trap(state, entity_pid) do
    # Apply stuck effect
    send(entity_pid, {
      :status_effect,
      %{
        type: :status,
        effect: :stuck,
        duration: 15,
        target_pid: entity_pid
      }
    })
    
    # Apply slowed effect
    send(entity_pid, {
      :status_effect,
      %{
        type: :status,
        effect: :slow,
        duration: 20,
        target_pid: entity_pid
      }
    })
    
    message = "is caught in a web!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
  end

  defp apply_rolling_boulder_trap(state, entity_pid) do
    damage = :rand.uniform(16) + 4
    
    # Send damage message to entity
    if state.world_pid do
      send(entity_pid, {
        :attack,
        %{
          type: :attack,
          damage_type: :acid,
          power: damage,
          source: state.id,
          reflect: false
        }
      })
    end
    
    message = "is crushed by a rolling boulder for #{damage} damage!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, damage)
  end

  defp apply_magic_portal_trap(state, entity_pid) do
    # Generate random position
    new_pos = {:rand.uniform(79), :rand.uniform(23)}
    
    # Send position update message
    if state.world_pid do
      send(entity_pid, {
        :teleport,
        %{
          type: :teleport,
          new_pos: new_pos,
          source: state.id
        }
      })
    end
    
    message = "is teleported through a magic portal!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
    |> Map.put(:teleported, new_pos)
  end

  defp apply_trapdoor_trap(state, entity_pid) do
    # Generate random position on same level
    new_pos = {:rand.uniform(79), :rand.uniform(23)}
    
    # Send position update message
    if state.world_pid do
      send(entity_pid, {
        :teleport,
        %{
          type: :teleport,
          new_pos: new_pos,
          source: state.id
        }
      })
    end
    
    message = "falls through a trapdoor!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
    |> Map.put(:teleported, new_pos)
  end

  defp apply_stairs_down_trap(state, entity_pid) do
    # Generate random position on "lower" level (simulated)
    new_pos = {:rand.uniform(79), :rand.uniform(23)}
    
    # Send position update message
    if state.world_pid do
      send(entity_pid, {
        :teleport,
        %{
          type: :teleport,
          new_pos: new_pos,
          source: state.id
        }
      })
    end
    
    message = "descends stairs!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
    |> Map.put(:teleported, new_pos)
  end

  defp apply_level_teleporter_trap(state, entity_pid) do
    # Generate random position
    new_pos = {:rand.uniform(79), :rand.uniform(23)}
    
    # Send position update message
    if state.world_pid do
      send(entity_pid, {
        :teleport,
        %{
          type: :teleport,
          new_pos: new_pos,
          source: state.id
        }
      })
    end
    
    message = "is teleported to another level!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
    |> Map.put(:teleported, new_pos)
  end

  defp apply_stairs_up_trap(state, entity_pid) do
    # Generate random position on "upper" level (simulated)
    new_pos = {:rand.uniform(79), :rand.uniform(23)}
    
    # Send position update message
    if state.world_pid do
      send(entity_pid, {
        :teleport,
        %{
          type: :teleport,
          new_pos: new_pos,
          source: state.id
        }
      })
    end
    
    message = "ascends stairs!"
    %{state | triggered: true}
    |> Map.put(:trigger_message, message)
    |> Map.put(:damage, 0)
    |> Map.put(:teleported, new_pos)
  end

  # Factory functions for different trap types

  defmodule TrapFactory do
    @moduledoc """
    Factory for creating different types of traps
    """
    
    @doc """
    Create a pit trap
    """
    def create_pit_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "pit_#{:rand.uniform(1000)}",
        trap_type: :pit,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a spiked pit trap
    """
    def create_spiked_pit_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "spiked_pit_#{:rand.uniform(1000)}",
        trap_type: :spiked_pit,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create an arrow trap
    """
    def create_arrow_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "arrow_trap_#{:rand.uniform(1000)}",
        trap_type: :arrow_trap,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a dart trap
    """
    def create_dart_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "dart_trap_#{:rand.uniform(1000)}",
        trap_type: :dart_trap,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a fire trap
    """
    def create_fire_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "fire_trap_#{:rand.uniform(1000)}",
        trap_type: :fire_trap,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a sleeping gas trap
    """
    def create_sleeping_gas_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "sleeping_gas_#{:rand.uniform(1000)}",
        trap_type: :sleeping_gas,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a teleportation trap
    """
    def create_teleportation_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "teleportation_#{:rand.uniform(1000)}",
        trap_type: :teleportation,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create an anti-magic trap
    """
    def create_anti_magic_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "anti_magic_#{:rand.uniform(1000)}",
        trap_type: :anti_magic,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a web trap
    """
    def create_web_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "web_#{:rand.uniform(1000)}",
        trap_type: :web,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a rolling boulder trap
    """
    def create_rolling_boulder_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "boulder_#{:rand.uniform(1000)}",
        trap_type: :rolling_boulder,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a magic portal trap
    """
    def create_magic_portal_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "magic_portal_#{:rand.uniform(1000)}",
        trap_type: :magic_portal,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a trapdoor trap
    """
    def create_trapdoor_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "trapdoor_#{:rand.uniform(1000)}",
        trap_type: :trapdoor,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create stairs down trap
    """
    def create_stairs_down_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "stairs_down_#{:rand.uniform(1000)}",
        trap_type: :stairs_down,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create level teleporter trap
    """
    def create_level_teleporter_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "level_teleporter_#{:rand.uniform(1000)}",
        trap_type: :level_teleporter,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create stairs up trap
    """
    def create_stairs_up_trap(pos, world_pid) do
      initial_state = %Nexthack.Trap{
        id: "stairs_up_#{:rand.uniform(1000)}",
        trap_type: :stairs_up,
        pos: pos,
        world_pid: world_pid
      }
      
      Nexthack.Trap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a random trap at the given position
    """
    def create_random_trap(pos, world_pid) do
      trap_types = [
        :pit, :spiked_pit, :arrow_trap, :dart_trap, :fire_trap,
        :sleeping_gas, :teleportation, :anti_magic, :web, :rolling_boulder,
        :magic_portal, :trapdoor, :stairs_down, :level_teleporter, :stairs_up
      ]
      
      trap_type = Enum.random(trap_types)
      create_trap(trap_type, pos, world_pid)
    end
    
    defp create_trap(:pit, pos, world_pid), do: create_pit_trap(pos, world_pid)
    defp create_trap(:spiked_pit, pos, world_pid), do: create_spiked_pit_trap(pos, world_pid)
    defp create_trap(:arrow_trap, pos, world_pid), do: create_arrow_trap(pos, world_pid)
    defp create_trap(:dart_trap, pos, world_pid), do: create_dart_trap(pos, world_pid)
    defp create_trap(:fire_trap, pos, world_pid), do: create_fire_trap(pos, world_pid)
    defp create_trap(:sleeping_gas, pos, world_pid), do: create_sleeping_gas_trap(pos, world_pid)
    defp create_trap(:teleportation, pos, world_pid), do: create_teleportation_trap(pos, world_pid)
    defp create_trap(:anti_magic, pos, world_pid), do: create_anti_magic_trap(pos, world_pid)
    defp create_trap(:web, pos, world_pid), do: create_web_trap(pos, world_pid)
    defp create_trap(:rolling_boulder, pos, world_pid), do: create_rolling_boulder_trap(pos, world_pid)
    defp create_trap(:magic_portal, pos, world_pid), do: create_magic_portal_trap(pos, world_pid)
    defp create_trap(:trapdoor, pos, world_pid), do: create_trapdoor_trap(pos, world_pid)
    defp create_trap(:stairs_down, pos, world_pid), do: create_stairs_down_trap(pos, world_pid)
    defp create_trap(:level_teleporter, pos, world_pid), do: create_level_teleporter_trap(pos, world_pid)
    defp create_trap(:stairs_up, pos, world_pid), do: create_stairs_up_trap(pos, world_pid)
  end
end