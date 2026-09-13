defmodule Nexthack.Monster do
  @moduledoc """
  Base monster actor implementation.
  Each monster runs as a separate GenServer process.
  """
  
  use GenServer
  alias Nexthack.Message
  alias Nexthack.DamageType

  # Monster state
  defstruct [
    id: "",
    name: "Monster",
    hp: 10,
    max_hp: 10,
    ac: 10,
    pos: {0, 0},
    damage: 2,
    speed: 1,
    alive: true,
    is_sleeping: false,
    sleep_duration: 0,
    is_invisible: false,
    is_undead: false,
    is_demon: false,
    is_golem: false,
    is_nonliving: false,
    inventory: [],
    world_pid: nil,
    last_messages: []
  ]

  # Public API

  @doc """
  Start a monster process
  """
  def start_link(name, initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  @doc """
  Move the monster randomly
  """
  def move(pid) do
    GenServer.cast(pid, {:move, self()})
  end

  @doc """
  Make the monster attack a target
  """
  def attack(pid, target_pid) do
    GenServer.cast(pid, {:attack, target_pid, self()})
  end

  @doc """
  Apply damage to the monster
  """
  def take_damage(pid, damage_type, power) do
    GenServer.cast(pid, {:take_damage, damage_type, power, self()})
  end

  @doc """
  Apply status effect to the monster
  """
  def apply_status(pid, effect, duration) do
    GenServer.cast(pid, {:apply_status, effect, duration, self()})
  end

  @doc """
  Get monster position
  """
  def get_position(pid) do
    GenServer.call(pid, :get_position)
  end

  @doc """
  Get monster HP
  """
  def get_hp(pid) do
    GenServer.call(pid, :get_hp)
  end

  @doc """
  Check if monster is alive
  """
  def alive?(pid) do
    GenServer.call(pid, :alive?)
  end

  @doc """
  Get monster name
  """
  def get_name(pid) do
    GenServer.call(pid, :get_name)
  end

  # Monster protocols (like Python's MonsterProtocol)

  @doc """
  Check if monster resists a damage type
  """
  def resists(%{is_undead: true}, :fire), do: true
  def resists(%{is_undead: true}, :cold), do: true
  def resists(_monster, _damage_type), do: false

  @doc """
  Check if monster is vulnerable to damage type
  """
  def is_vulnerable_to(monster, damage_type) do
    not resists(monster, damage_type)
  end

  @doc """
  Check if monster can polymorph
  """
  def can_polymorph(%{is_golem: true}), do: false
  def can_polymorph(_monster), do: true

  # GenServer callbacks

  @impl true
  def init(initial_state) do
    Process.send_after(self(), {:wake_up_check}, 100)
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:move, caller}, state) do
    new_state = move_monster(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:attack, target_pid, caller}, state) do
    result = attack_target(state, target_pid)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:take_damage, damage_type, power, caller}, state) do
    new_state = react_to_damage(state, damage_type, power)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:apply_status, effect, duration, caller}, state) do
    new_state = apply_status_effect(state, effect, duration)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.pos, state}
  end

  @impl true
  def handle_call(:get_hp, _from, state) do
    {:reply, {state.hp, state.max_hp}, state}
  end

  @impl true
  def handle_call(:alive?, _from, state) do
    {:reply, state.alive, state}
  end

  @impl true
  def handle_call(:get_name, _from, state) do
    {:reply, state.name, state}
  end

  @impl true
  def handle_info({:wake_up_check}, state) do
    if state.is_sleeping and state.sleep_duration > 0 do
      new_duration = state.sleep_duration - 1
      new_state = %{state | sleep_duration: new_duration}
      if new_duration <= 0 do
        new_state = %{new_state | is_sleeping: false}
        # Broadcast that monster woke up
        if new_state.world_pid do
          send(new_state.world_pid, {:broadcast, 
            "#{state.name} wakes up!", state.id})
        end
      end
      {:noreply, new_state}
    else
      # Schedule next check
      Process.send_after(self(), {:wake_up_check}, 100)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:attack, attack_msg}, state) do
    # Handle attack messages from traps
    damage_type = attack_msg.damage_type
    power = attack_msg.power
    
    new_state = react_to_damage(state, damage_type, power)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:status_effect, status_msg}, state) do
    # Handle status effect messages from traps
    effect = status_msg.effect
    duration = status_msg.duration
    
    new_state = apply_status_effect(state, effect, duration)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:teleport, teleport_msg}, state) do
    # Handle teleportation messages from traps
    new_pos = teleport_msg.new_pos
    
    new_state = %{state | pos: new_pos}
    
    # Broadcast teleport
    if new_state.world_pid do
      send(new_state.world_pid, {:broadcast, 
        "#{state.name} is teleported to #{inspect(new_pos)}", state.id})
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:cancel, cancel_msg}, state) do
    # Handle cancellation messages from anti-magic traps
    # For now, just broadcast the effect
    if state.world_pid do
      send(state.world_pid, {:broadcast, 
        "#{state.name} feels magic resistance!", state.id})
    end
    
    {:noreply, state}
  end

  # Internal functions

  defp move_monster(state) do
    if state.is_sleeping or not state.alive do
      state
    else
      # Try to move in a random direction
      directions = [{1, 0}, {-1, 0}, {0, 1}, {0, -1}]
      Enum.shuffle(directions)
      |> Enum.find(fn {dx, dy} -> 
        valid_move?(state, dx, dy) 
      end)
      |> case do
        {dx, dy} -> 
          new_pos = {(state.pos |> elem(0) + dx), (state.pos |> elem(1) + dy)}
          new_state = %{state | pos: new_pos}
          
          # Broadcast move
          if new_state.world_pid do
            send(new_state.world_pid, {:broadcast, 
              "#{state.name} moves to #{inspect(new_pos)}", state.id})
          end
          
          new_state
        _ -> state
      end
    end
  end

  defp valid_move?(state, dx, dy) do
    new_x = state.pos |> elem(0) + dx
    new_y = state.pos |> elem(1) + dy
    
    # Simple validation - in future would check world map
    new_x >= 0 and new_x < 80 and new_y >= 0 and new_y < 24
  end

  defp attack_target(state, target_pid) do
    if state.is_sleeping or not state.alive do
      state
    else
      # In a real implementation, we'd send a message to the target
      # For now, just simulate the attack
      damage = if :rand.uniform(20) <= 20 - state.ac do
        :rand.uniform(state.damage) 
      else
        0
      end
      
      if damage > 0 do
        # Broadcast attack
        if state.world_pid do
          send(state.world_pid, {:broadcast, 
            "#{state.name} hits #{target_pid} for #{damage} damage!", state.id})
        end
      else
        # Broadcast miss
        if state.world_pid do
          send(state.world_pid, {:broadcast, 
            "#{state.name} misses #{target_pid}.", state.id})
        end
      end
      
      state
    end
  end

  defp react_to_damage(state, damage_type, power) do
    if not state.alive do
      state
    else
      damage_dealt = if resists(state, damage_type) do
        max(0, power - 2)  # Reduced damage if resistant
      else
        power
      end
      
      new_hp = state.hp - damage_dealt
      new_alive = new_hp > 0
      
      # Add to last messages
      message = "#{state.name} takes #{damage_dealt} #{damage_type} damage!"
      new_messages = [message | state.last_messages]
      new_messages = if length(new_messages) > 5, do: Enum.take(new_messages, 5), else: new_messages
      
      new_state = %{
        state |
        hp: new_hp,
        alive: new_alive,
        last_messages: new_messages
      }
      
      # Broadcast damage
      if new_state.world_pid do
        send(new_state.world_pid, {:broadcast, message, state.id})
      end
      
      if not new_state.alive do
        # Broadcast death
        if new_state.world_pid do
          send(new_state.world_pid, {:broadcast, 
            "#{state.name} dies!", state.id})
        end
      end
      
      new_state
    end
  end

  defp apply_status_effect(state, effect, duration) do
    if not state.alive do
      state
    else
      case effect do
        :sleep ->
          new_state = %{state | is_sleeping: true, sleep_duration: duration}
          
          # Broadcast sleep
          if new_state.world_pid do
            send(new_state.world_pid, {:broadcast, 
              "#{state.name} falls asleep!", state.id})
          end
          
          new_state
          
        :slow ->
          %{state | speed: max(1, state.speed - 1)}
          
        :haste ->
          %{state | speed: state.speed + 1}
          
        :invisibility ->
          %{state | is_invisible: true}
          
        :stuck ->
          new_state = %{state | stuck: true}
          
          # Broadcast stuck
          if new_state.world_pid do
            send(new_state.world_pid, {:broadcast, 
              "#{state.name} is stuck!", state.id})
          end
          
          new_state
          
        _ -> state
      end
    end
  end

  # Concrete monster types

  defmodule Goblin do
    @moduledoc "Goblin monster type"
    
    def create(pos, world_pid) do
      initial_state = %Nexthack.Monster{
        id: "goblin_#{:rand.uniform(1000)}",
        name: "Goblin",
        hp: 8,
        max_hp: 8,
        ac: 7,
        pos: pos,
        damage: 2,
        speed: 1,
        is_undead: false,
        is_demon: false,
        is_golem: false,
        is_nonliving: false,
        world_pid: world_pid
      }
      
      Nexthack.Monster.start_link(initial_state.id, initial_state)
    end
  end

  defmodule Orc do
    @moduledoc "Orc monster type"
    
    def create(pos, world_pid) do
      initial_state = %Nexthack.Monster{
        id: "orc_#{:rand.uniform(1000)}",
        name: "Orc",
        hp: 15,
        max_hp: 15,
        ac: 5,
        pos: pos,
        damage: 4,
        speed: 1,
        is_undead: false,
        is_demon: false,
        is_golem: false,
        is_nonliving: false,
        world_pid: world_pid
      }
      
      Nexthack.Monster.start_link(initial_state.id, initial_state)
    end
  end

  defmodule Bat do
    @moduledoc "Bat monster type"
    
    def create(pos, world_pid) do
      initial_state = %Nexthack.Monster{
        id: "bat_#{:rand.uniform(1000)}",
        name: "Bat",
        hp: 4,
        max_hp: 4,
        ac: 3,
        pos: pos,
        damage: 1,
        speed: 2,  # Bats are faster
        is_undead: false,
        is_demon: false,
        is_golem: false,
        is_nonliving: false,
        is_flying: true,
        world_pid: world_pid
      }
      
      Nexthack.Monster.start_link(initial_state.id, initial_state)
    end
  end
end