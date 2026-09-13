defmodule Nexthack.Zap do
  @moduledoc """
  Zap/spell system with moving bolt actors.
  Each zap creates bolt actors that traverse the map in a given direction,
  checking for collisions with entities.
  """
  
  use GenServer
  alias Nexthack.Message
  alias Nexthack.DamageType

  # Zap state
  defstruct [
    id: "",
    zap_type: :fire_bolt,
    damage_type: :fire,
    power: 6,
    duration: 0,
    direction: {1, 0},  # Default: east
    start_pos: {0, 0},
    current_pos: {0, 0},
    world_pid: nil,
    source_pid: nil,
    range: 8,
    distance_travelled: 0,
    effected_entities: [],
    effect_name: ""
  ]

  # Zap types
  @type zap_type :: 
    :force_bolt | :cancellation | :teleport | :invisibility | :polymorph |
    :sleep | :slow | :haste | :undead_turning | :opening | :locking | :probe |
    :fire_bolt | :cone_of_cold | :lightning_bolt | :death_ray | :dig | :null

  # Damage types for zaps
  @type damage_type :: 
    :magic_missile | :fire | :cold | :sleep | :death | :lightning | :poison | :acid | :cancellation

  # Public API

  @doc """
  Start a bolt process
  """
  def start_link(name, initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  @doc """
  Fire the zap in the given direction
  """
  def fire(pid) do
    GenServer.cast(pid, {:fire, self()})
  end

  @doc """
  Get bolt position
  """
  def get_position(pid) do
    GenServer.call(pid, :get_position)
  end

  @doc """
  Get zap type
  """
  def get_zap_type(pid) do
    GenServer.call(pid, :get_zap_type)
  end

  @doc """
  Get effected entities
  """
  def get_effected_entities(pid) do
    GenServer.call(pid, :get_effected_entities)
  end

  # GenServer callbacks

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:fire, caller}, state) do
    if state.world_pid do
      new_state = move_bolt(state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.current_pos, state}
  end

  @impl true
  def handle_call(:get_zap_type, _from, state) do
    {:reply, state.zap_type, state}
  end

  @impl true
  def handle_call(:get_effected_entities, _from, state) do
    {:reply, state.effected_entities, state}
  end

  @impl true
  def handle_info({:move_tick}, state) do
    if state.distance_travelled < state.range do
      new_state = move_bolt(state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # Internal functions

  defp move_bolt(state) do
    if state.distance_travelled >= state.range do
      state
    else
      # Calculate next position using pattern matching
      {current_x, current_y} = state.current_pos
      {dx, dy} = state.direction
      new_x = current_x + dx
      new_y = current_y + dy
      new_pos = {new_x, new_y}
      
      new_distance = state.distance_travelled + 1
      new_state = %{state | current_pos: new_pos, distance_travelled: new_distance}
      
      # Check for collisions with entities in world
      if new_state.world_pid do
        entities_at_pos = check_entities_at_position(new_state.world_pid, new_pos)
        
        if length(entities_at_pos) > 0 do
          # Apply zap effect to entities
          new_state = apply_zap_effects(new_state, entities_at_pos)
          
          # Broadcast zap completion
          if new_state.world_pid do
            send(new_state.world_pid, {:broadcast, 
              "#{state.zap_type} completes at #{inspect(new_pos)}, hit #{length(new_state.effected_entities)} entities", 
              state.id})
          end
        end
      end
      
      # Schedule next move if not at range limit
      if new_distance < state.range do
        Process.send_after(self(), {:move_tick}, 100)
      end
      
      new_state
    end
  end

  defp check_entities_at_position(world_pid, pos) do
    # Query world for entities at position
    # In a real implementation, this would be a proper query to the world
    # For now, we'll return empty list
    []
  end

  defp apply_zap_effects(state, entities) do
    new_effected = state.effected_entities
    
    Enum.each(entities, fn entity_pid ->
      # Apply the appropriate effect based on zap type
      case state.zap_type do
        :fire_bolt -> apply_damage_zap(state, entity_pid)
        :lightning_bolt -> apply_damage_zap(state, entity_pid)
        :cone_of_cold -> apply_damage_zap(state, entity_pid)
        :death_ray -> apply_damage_zap(state, entity_pid)
        :force_bolt -> apply_damage_zap(state, entity_pid)
        :sleep -> apply_status_zap(state, entity_pid, :sleep)
        :cancellation -> apply_cancellation_zap(state, entity_pid)
        :teleport -> apply_teleport_zap(state, entity_pid)
        :invisibility -> apply_status_zap(state, entity_pid, :invisibility)
        :polymorph -> apply_polymorph_zap(state, entity_pid)
        :slow -> apply_status_zap(state, entity_pid, :slow)
        :haste -> apply_status_zap(state, entity_pid, :haste)
        :undead_turning -> apply_undead_turning_zap(state, entity_pid)
        _ -> :ok
      end
      
      new_effected = [entity_pid | new_effected]
    end)
    
    %{state | effected_entities: new_effected}
  end

  defp apply_damage_zap(state, entity_pid) do
    # Send damage message to entity
    send(entity_pid, {
      :attack,
      %{
        type: :attack,
        damage_type: state.damage_type,
        power: state.power,
        source: state.id,
        reflect: false
      }
    })
    
    # Broadcast zap effect
    if state.world_pid do
      send(state.world_pid, {:broadcast, 
        "#{state.zap_type} hits #{inspect(entity_pid)} for #{state.power} damage", 
        state.id})
    end
  end

  defp apply_status_zap(state, entity_pid, effect) do
    # Send status effect message to entity
    send(entity_pid, {
      :status_effect,
      %{
        type: :status,
        effect: effect,
        duration: if state.duration > 0, do: state.duration, else: 10,
        target_pid: entity_pid
      }
    })
    
    # Broadcast zap effect
    if state.world_pid do
      send(state.world_pid, {:broadcast, 
        "#{state.zap_type} affects #{inspect(entity_pid)} with #{effect}", 
        state.id})
    end
  end

  defp apply_cancellation_zap(state, entity_pid) do
    # Send cancellation message to entity
    send(entity_pid, {
      :cancel,
      %{
        type: :cancel,
        source: state.id
      }
    })
    
    # Broadcast zap effect
    if state.world_pid do
      send(state.world_pid, {:broadcast, 
        "#{state.zap_type} cancels effects on #{inspect(entity_pid)}", 
        state.id})
    end
  end

  defp apply_teleport_zap(state, entity_pid) do
    # Generate random position
    new_pos = {:rand.uniform(79), :rand.uniform(23)}
    
    # Send teleport message to entity
    send(entity_pid, {
      :teleport,
      %{
        type: :teleport,
        new_pos: new_pos,
        source: state.id
      }
    })
    
    # Broadcast zap effect
    if state.world_pid do
      send(state.world_pid, {:broadcast, 
        "#{state.zap_type} teleports #{inspect(entity_pid)} to #{inspect(new_pos)}", 
        state.id})
    end
  end

  defp apply_polymorph_zap(state, entity_pid) do
    # Check if entity can be polymorphed
    can_polymorph = case entity_pid do
      pid when is_pid(pid) ->
        # In a real implementation, we'd query the entity
        # For now, assume most entities can be polymorphed
        true
      _ -> true
    end
    
    if can_polymorph do
      # Send status effect message
      send(entity_pid, {
        :status_effect,
        %{
          type: :status,
          effect: :polymorph,
          duration: 1,
          target_pid: entity_pid
        }
      })
      
      # Broadcast zap effect
      if state.world_pid do
        send(state.world_pid, {:broadcast, 
          "#{state.zap_type} polymorphs #{inspect(entity_pid)}!", 
          state.id})
      end
    else
      # Broadcast resistance
      if state.world_pid do
        send(state.world_pid, {:broadcast, 
          "#{inspect(entity_pid)} resists polymorph!", 
          state.id})
      end
    end
  end

  defp apply_undead_turning_zap(state, entity_pid) do
    # Check if entity is undead
    is_undead = case entity_pid do
      pid when is_pid(pid) ->
        # In a real implementation, we'd query the entity
        # For now, simulate undead check
        :rand.uniform(100) < 30  # 30% chance of being undead
      _ -> false
    end
    
    if is_undead do
      # Send status effect to make undead flee
      send(entity_pid, {
        :status_effect,
        %{
          type: :status,
          effect: :undead_turning,
          duration: 5,
          target_pid: entity_pid
        }
      })
      
      # Also apply damage
      apply_damage_zap(state, entity_pid)
      
      # Broadcast zap effect
      if state.world_pid do
        send(state.world_pid, {:broadcast, 
          "#{state.zap_type} turns #{inspect(entity_pid)} and deals damage!", 
          state.id})
      end
    else
      # Broadcast no effect
      if state.world_pid do
        send(state.world_pid, {:broadcast, 
          "#{state.zap_type} has no effect on #{inspect(entity_pid)}", 
          state.id})
      end
    end
  end

  # Factory for creating different zap types

  defmodule ZapFactory do
    @moduledoc """
    Factory for creating different types of zaps
    """
    
    @doc """
    Create a fire bolt zap
    """
    def create_fire_bolt(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "fire_bolt_#{:rand.uniform(1000)}",
        zap_type: :fire_bolt,
        damage_type: :fire,
        power: 6,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "fire bolt"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a lightning bolt zap
    """
    def create_lightning_bolt(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "lightning_bolt_#{:rand.uniform(1000)}",
        zap_type: :lightning_bolt,
        damage_type: :lightning,
        power: 8,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 6,
        distance_travelled: 0,
        effect_name: "lightning bolt"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a cold cone zap
    """
    def create_cold_cone(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "cold_cone_#{:rand.uniform(1000)}",
        zap_type: :cone_of_cold,
        damage_type: :cold,
        power: 5,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 10,
        distance_travelled: 0,
        effect_name: "cone of cold"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a death ray zap
    """
    def create_death_ray(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "death_ray_#{:rand.uniform(1000)}",
        zap_type: :death_ray,
        damage_type: :death,
        power: 12,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "death ray"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a force bolt zap
    """
    def create_force_bolt(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "force_bolt_#{:rand.uniform(1000)}",
        zap_type: :force_bolt,
        damage_type: :magic_missile,
        power: 4,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 12,
        distance_travelled: 0,
        effect_name: "force bolt"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a sleep zap
    """
    def create_sleep_zap(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "sleep_zap_#{:rand.uniform(1000)}",
        zap_type: :sleep,
        damage_type: :sleep,
        power: 0,
        duration: 25,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "sleep"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a cancellation zap
    """
    def create_cancellation_zap(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "cancellation_zap_#{:rand.uniform(1000)}",
        zap_type: :cancellation,
        damage_type: :cancellation,
        power: 0,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "cancellation"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a teleport zap
    """
    def create_teleport_zap(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "teleport_zap_#{:rand.uniform(1000)}",
        zap_type: :teleport,
        damage_type: :none,
        power: 0,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 1,
        distance_travelled: 0,
        effect_name: "teleport"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create an invisibility zap
    """
    def create_invisibility_zap(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "invisibility_zap_#{:rand.uniform(1000)}",
        zap_type: :invisibility,
        damage_type: :none,
        power: 0,
        duration: 60,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "invisibility"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a polymorph zap
    """
    def create_polymorph_zap(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "polymorph_zap_#{:rand.uniform(1000)}",
        zap_type: :polymorph,
        damage_type: :none,
        power: 0,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "polymorph"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a slow zap
    """
    def create_slow_zap(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "slow_zap_#{:rand.uniform(1000)}",
        zap_type: :slow,
        damage_type: :none,
        power: 0,
        duration: 20,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "slow"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a haste zap
    """
    def create_haste_zap(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "haste_zap_#{:rand.uniform(1000)}",
        zap_type: :haste,
        damage_type: :none,
        power: 0,
        duration: 20,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "haste"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create an undead turning zap
    """
    def create_undead_turning_zap(source_pos, direction, world_pid, source_pid) do
      initial_state = %Nexthack.Zap{
        id: "undead_turning_#{:rand.uniform(1000)}",
        zap_type: :undead_turning,
        damage_type: :sleep,
        power: 6,
        duration: 5,
        direction: direction,
        start_pos: source_pos,
        current_pos: source_pos,
        world_pid: world_pid,
        source_pid: source_pid,
        range: 8,
        distance_travelled: 0,
        effect_name: "undead turning"
      }
      
      Nexthack.Zap.start_link(initial_state.id, initial_state)
    end
    
    @doc """
    Create a random zap
    """
    def create_random_zap(source_pos, direction, world_pid, source_pid) do
      zap_types = [
        :fire_bolt, :lightning_bolt, :cone_of_cold, :death_ray, :force_bolt,
        :sleep, :cancellation, :teleport, :invisibility, :polymorph,
        :slow, :haste, :undead_turning
      ]
      
      zap_type = Enum.random(zap_types)
      create_zap(zap_type, source_pos, direction, world_pid, source_pid)
    end
    
    defp create_zap(:fire_bolt, source_pos, direction, world_pid, source_pid), 
         do: create_fire_bolt(source_pos, direction, world_pid, source_pid)
    defp create_zap(:lightning_bolt, source_pos, direction, world_pid, source_pid), 
         do: create_lightning_bolt(source_pos, direction, world_pid, source_pid)
    defp create_zap(:cone_of_cold, source_pos, direction, world_pid, source_pid), 
         do: create_cold_cone(source_pos, direction, world_pid, source_pid)
    defp create_zap(:death_ray, source_pos, direction, world_pid, source_pid), 
         do: create_death_ray(source_pos, direction, world_pid, source_pid)
    defp create_zap(:force_bolt, source_pos, direction, world_pid, source_pid), 
         do: create_force_bolt(source_pos, direction, world_pid, source_pid)
    defp create_zap(:sleep, source_pos, direction, world_pid, source_pid), 
         do: create_sleep_zap(source_pos, direction, world_pid, source_pid)
    defp create_zap(:cancellation, source_pos, direction, world_pid, source_pid), 
         do: create_cancellation_zap(source_pos, direction, world_pid, source_pid)
    defp create_zap(:teleport, source_pos, direction, world_pid, source_pid), 
         do: create_teleport_zap(source_pos, direction, world_pid, source_pid)
    defp create_zap(:invisibility, source_pos, direction, world_pid, source_pid), 
         do: create_invisibility_zap(source_pos, direction, world_pid, source_pid)
    defp create_zap(:polymorph, source_pos, direction, world_pid, source_pid), 
         do: create_polymorph_zap(source_pos, direction, world_pid, source_pid)
    defp create_zap(:slow, source_pos, direction, world_pid, source_pid), 
         do: create_slow_zap(source_pos, direction, world_pid, source_pid)
    defp create_zap(:haste, source_pos, direction, world_pid, source_pid), 
         do: create_haste_zap(source_pos, direction, world_pid, source_pid)
    defp create_zap(:undead_turning, source_pos, direction, world_pid, source_pid), 
         do: create_undead_turning_zap(source_pos, direction, world_pid, source_pid)
  end
end