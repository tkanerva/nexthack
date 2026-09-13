defmodule Nexthack.Player do
  @moduledoc """
  Player actor implementation.
  Extends the monster base with player-specific functionality.
  """
  
  use GenServer
  alias Nexthack.Message
  alias Nexthack.DamageType

  # Player state
  defstruct [
    id: "player",
    name: "Hero",
    hp: 25,
    max_hp: 25,
    ac: 5,
    pos: {20, 10},
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
    last_messages: [],
    # Player-specific states
    confused: false,
    poisoned: false,
    poison_duration: 0,
    stuck: false,
    slowed: false
  ]

  # Public API

  @doc """
  Start the player process
  """
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: :player)
  end

  @doc """
  Move the player in a direction
  """
  def move(pid, dx, dy) do
    GenServer.cast(pid, {:move, dx, dy, self()})
  end

  @doc """
  Make the player attack a target
  """
  def attack(pid, target_pid) do
    GenServer.cast(pid, {:attack, target_pid, self()})
  end

  @doc """
  Apply damage to the player
  """
  def take_damage(pid, damage_type, power) do
    GenServer.cast(pid, {:take_damage, damage_type, power, self()})
  end

  @doc """
  Apply status effect to the player
  """
  def apply_status(pid, effect, duration) do
    GenServer.cast(pid, {:apply_status, effect, duration, self()})
  end

  @doc """
  Get player position
  """
  def get_position(pid) do
    GenServer.call(pid, :get_position)
  end

  @doc """
  Get player HP
  """
  def get_hp(pid) do
    GenServer.call(pid, :get_hp)
  end

  @doc """
  Check if player is alive
  """
  def alive?(pid) do
    GenServer.call(pid, :alive?)
  end

  @doc """
  Get player name
  """
  def get_name(pid) do
    GenServer.call(pid, :get_name)
  end

  @doc """
  Check and trigger traps at player's position
  """
  def check_and_trigger_traps(pid) do
    GenServer.cast(pid, {:check_and_trigger_traps, self()})
  end

  # Monster protocol functions (like Python's MonsterProtocol)

  @doc """
  Check if player resists a damage type
  """
  def resists(%{is_undead: true}, :fire), do: true
  def resists(%{is_undead: true}, :cold), do: true
  def resists(_player, _damage_type), do: false

  @doc """
  Check if player is vulnerable to damage type
  """
  def is_vulnerable_to(player, damage_type) do
    not resists(player, damage_type)
  end

  @doc """
  Check if player can polymorph
  """
  def can_polymorph(%{is_golem: true}), do: false
  def can_polymorph(_player), do: true

  # GenServer callbacks

  @impl true
  def init(initial_state) do
    Process.send_after(self(), {:wake_up_check}, 100)
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:move, dx, dy, caller}, state) do
    new_state = move_player(state, dx, dy)
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
  def handle_cast({:check_and_trigger_traps, caller}, state) do
    # In a real implementation, this would interact with trap actors
    # For now, we'll just simulate trap checking
    if state.world_pid do
      # This would be replaced with actual trap interaction logic
      Message.Broadcast.broadcast(%{
        type: :broadcast,
        message: "#{state.name} checks for traps at #{inspect(state.pos)}",
        source: state.id
      }, state.world_pid)
    end
    {:noreply, state}
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
        # Broadcast that player woke up
        if new_state.world_pid do
          Message.Broadcast.broadcast(%{
            type: :broadcast,
            message: "#{state.name} wakes up!",
            source: state.id
          }, new_state.world_pid)
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
      Message.Broadcast.broadcast(%{
        type: :broadcast,
        message: "#{state.name} is teleported to #{inspect(new_pos)}",
        source: state.id
      }, new_state.world_pid)
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:cancel, cancel_msg}, state) do
    # Handle cancellation messages from anti-magic traps
    # For now, just broadcast the effect
    if state.world_pid do
      Message.Broadcast.broadcast(%{
        type: :broadcast,
        message: "#{state.name} feels magic resistance!",
        source: state.id
      }, state.world_pid)
    end
    
    {:noreply, state}
  end

  # Internal functions

  defp move_player(state, dx, dy) do
    if state.is_sleeping or not state.alive do
      state
    else
      {x, y} = state.pos
      {new_x, new_y} = {x + dx, y + dy}
      
      # Simple validation - in future would check world map
      if new_x >= 0 and new_x < 80 and new_y >= 0 and new_y < 24 do
        new_pos = {new_x, new_y}
        new_state = %{state | pos: new_pos}
        
        # Broadcast move
        if new_state.world_pid do
          Message.Broadcast.broadcast(%{
            type: :broadcast,
            message: "#{state.name} moves to #{inspect(new_pos)}",
            source: state.id
          }, new_state.world_pid)
        end
        
        new_state
      else
        state
      end
    end
  end

  defp attack_target(state, target_pid) do
    if state.is_sleeping or not state.alive do
      state
    else
      # In a real implementation, we'd send a message to the target
      # For now, just simulate the attack
      damage = if :rand.uniform(20) <= 20 - state.ac do
        :rand.uniform(3)  # Player does 1-3 damage
      else
        0
      end
      
      if damage > 0 do
        # Broadcast attack
        if state.world_pid do
          Message.Broadcast.broadcast(%{
            type: :broadcast,
            message: "#{state.name} hits #{target_pid} for #{damage} damage!",
            source: state.id
          }, state.world_pid)
        end
      else
        # Broadcast miss
        if state.world_pid do
          Message.Broadcast.broadcast(%{
            type: :broadcast,
            message: "#{state.name} misses #{target_pid}.",
            source: state.id
          }, state.world_pid)
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
        Message.Broadcast.broadcast(%{
          type: :broadcast,
          message: message,
          source: state.id
        }, new_state.world_pid)
      end
      
      if not new_state.alive do
        # Broadcast death
        if new_state.world_pid do
          Message.Broadcast.broadcast(%{
            type: :broadcast,
            message: "#{state.name} dies!",
            source: state.id
          }, new_state.world_pid)
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
            Message.Broadcast.broadcast(%{
              type: :broadcast,
              message: "#{state.name} falls asleep!",
              source: state.id
            }, new_state.world_pid)
          end
          
          new_state
          
        :poison ->
          new_state = %{state | poisoned: true, poison_duration: duration}
          
          # Broadcast poison
          if new_state.world_pid do
            Message.Broadcast.broadcast(%{
              type: :broadcast,
              message: "#{state.name} is poisoned!",
              source: state.id
            }, new_state.world_pid)
          end
          
          new_state
          
        :confused ->
          %{state | confused: true}
          
        :slow ->
          %{state | slowed: true}
          
        :stuck ->
          new_state = %{state | stuck: true}
          
          # Broadcast stuck
          if new_state.world_pid do
            Message.Broadcast.broadcast(%{
              type: :broadcast,
              message: "#{state.name} is stuck!",
              source: state.id
            }, new_state.world_pid)
          end
          
          new_state
          
        :invisibility ->
          %{state | is_invisible: true}
          
        _ -> state
      end
    end
  end

  # Factory function

  @doc """
  Create a new player
  """
  def create(pos, world_pid) do
    initial_state = %Nexthack.Player{
      pos: pos,
      world_pid: world_pid
    }
    
    start_link(initial_state)
  end
end