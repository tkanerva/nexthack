defmodule Nexthack.World do
  @moduledoc """
  World supervision tree and coordinator.
  Manages all actors in the game and provides coordination services.
  """
  
  use GenServer
  alias Nexthack.Message

  # World state
  defstruct [
    map: nil,
    monsters: [],
    player_pid: nil,
    trap_actors: [],
    broadcast_messages: [],
    running: false
  ]

  # Public API

  @doc """
  Start the world supervision tree
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: :world)
  end

  @doc """
  Initialize the world with map and entities
  """
  def initialize(pid) do
    GenServer.cast(pid, {:initialize, self()})
  end

  @doc """
  Spawn monsters in the world
  """
  def spawn_monsters(pid, count_by_type) do
    GenServer.cast(pid, {:spawn_monsters, count_by_type, self()})
  end

  @doc """
  Start the game loop
  """
  def start_game(pid) do
    GenServer.cast(pid, {:start_game, self()})
  end

  @doc """
  Stop the game
  """
  def stop_game(pid) do
    GenServer.cast(pid, {:stop_game, self()})
  end

  @doc """
  Get all broadcast messages
  """
  def get_broadcast_messages(pid) do
    GenServer.call(pid, :get_broadcast_messages)
  end

  @doc """
  Get player HP
  """
  def get_player_hp(pid) do
    GenServer.call(pid, :get_player_hp)
  end

  @doc """
  Check if player is alive
  """
  def player_alive?(pid) do
    GenServer.call(pid, :player_alive?)
  end

  @doc """
  Check if any monsters are alive
  """
  def any_monsters_alive?(pid) do
    GenServer.call(pid, :any_monsters_alive?)
  end

  @doc """
  Trigger a monster turn
  """
  def monster_turn(pid, monster_pid) do
    GenServer.cast(pid, {:monster_turn, monster_pid, self()})
  end

  # GenServer callbacks

  @impl true
  def init(:ok) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:initialize, caller}, state) do
    # Initialize map (80x24 grid for simplicity)
    map = generate_map()
    new_state = %{state | map: map}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:register_player, player_pid}, state) do
    new_state = %{state | player_pid: player_pid}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:spawn_monsters, count_by_type, caller}, state) do
    if state.player_pid do
      # Spawn monsters of different types
      monsters = []
      
      # Spawn goblins
      goblins = count_by_type[:goblins] || 4
      monsters_goblins = Enum.map(1..goblins, fn i -> 
        pos = find_empty_position(state.map)
        Nexthack.Monster.Goblin.create(pos, self())
      end)
      
      # Spawn orcs
      orcs = count_by_type[:orcs] || 2
      monsters_orcs = Enum.map(1..orcs, fn i -> 
        pos = find_empty_position(state.map)
        Nexthack.Monster.Orc.create(pos, self())
      end)
      
      # Spawn bats
      bats = count_by_type[:bats] || 3
      monsters_bats = Enum.map(1..bats, fn i -> 
        pos = find_empty_position(state.map)
        Nexthack.Monster.Bat.create(pos, self())
      end)
      
      all_monsters = monsters_goblins ++ monsters_orcs ++ monsters_bats
      new_state = %{state | monsters: all_monsters}
      
      # Broadcast monster spawn
      Message.Broadcast.broadcast(%{
        type: :broadcast,
        message: "Spawned #{length(all_monsters)} monsters",
        source: "world"
      }, self())
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:start_game, caller}, state) do
    if not state.running and state.player_pid do
      new_state = %{state | running: true}
      
      # Start game loop timer
      Process.send_after(self(), {:game_tick}, 500)
      
      # Broadcast game start
      Message.Broadcast.broadcast(%{
        type: :broadcast,
        message: "Game started!",
        source: "world"
      }, self())
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:stop_game, caller}, state) do
    new_state = %{state | running: false}
    
    # Broadcast game stop
    Message.Broadcast.broadcast(%{
      type: :broadcast,
      message: "Game stopped!",
      source: "world"
    }, self())
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:monster_turn, monster_pid, caller}, state) do
    # Trigger monster to move
    Nexthack.Monster.move(monster_pid)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_broadcast_messages, _from, state) do
    messages = Enum.reverse(state.broadcast_messages)
    {:reply, messages, state}
  end

  @impl true
  def handle_call(:get_player_hp, _from, state) do
    if state.player_pid do
      Nexthack.Player.get_hp(state.player_pid)
    else
      {0, 0}
    end
  end

  @impl true
  def handle_call(:player_alive?, _from, state) do
    if state.player_pid do
      Nexthack.Player.alive?(state.player_pid)
    else
      false
    end
  end

  @impl true
  def handle_call(:any_monsters_alive?, _from, state) do
    Enum.any?(state.monsters, fn monster_pid ->
      Nexthack.Monster.alive?(monster_pid)
    end)
  end

  @impl true
  def handle_info({:game_tick}, state) do
    if state.running and state.player_pid do
      # Process monster turns
      Enum.each(state.monsters, fn monster_pid ->
        if Nexthack.Monster.alive?(monster_pid) do
          Nexthack.Monster.move(monster_pid)
        end
      end)
      
      # Schedule next tick
      Process.send_after(self(), {:game_tick}, 500)
    end
    
    {:noreply, state}
  end

  @impl true
  def handle_info({:broadcast, message, source}, state) do
    # Add to broadcast messages (keep last 20)
    new_messages = [message | state.broadcast_messages]
    new_messages = if length(new_messages) > 20, 
                   do: Enum.take(new_messages, 20), 
                   else: new_messages
    
    new_state = %{state | broadcast_messages: new_messages}
    {:noreply, new_state}
  end

  # Internal functions

  defp generate_map() do
    # Create a simple 80x24 map with borders
    # 1 = wall, 0 = floor
    map = for y <- 0..23, into: [] do
      for x <- 0..79, into: [] do
        if y == 0 or y == 23 or x == 0 or x == 79 do
          1  # Wall
        else
          0  # Floor
        end
      end
    end
    
    map
  end

  defp find_empty_position(map) do
    # Find a random empty position (not a wall)
    all_positions = for y <- 0..23, x <- 0..79, into: [], do: {x, y}
    
    Enum.shuffle(all_positions)
    |> Enum.find(fn {x, y} ->
      tile = map |> Enum.at(y) |> Enum.at(x)
      tile == 0  # Empty floor
    end)
    || {20, 10}  # Fallback position
  end

  # Factory function to create a complete world with supervision

  defmodule Supervisor do
    @moduledoc """
    World supervision tree
    """
    
    use Supervisor

    def start_link(args) do
      Supervisor.start_link(__MODULE__, args, name: :world_supervisor)
    end

    @impl true
    def init(_init_arg) do
      children = [
        # Start the world coordinator
        {Nexthack.World, []},
        
        # We'll add player and monsters dynamically
      ]
      
      Supervisor.init(children, strategy: :one_for_one)
    end

    @doc """
    Create a complete game world with player and monsters
    """
    def create_world do
      world_pid = :world
      
      # Create player
      player_pid = Nexthack.Player.create({20, 10}, world_pid)
      
      # Register player with world
      GenServer.cast(world_pid, {:register_player, player_pid})
      
      # Initialize world
      Nexthack.World.initialize(world_pid)
      
      # Spawn monsters
      Nexthack.World.spawn_monsters(world_pid, goblins: 4, orcs: 2, bats: 3)
      
      {world_pid, player_pid}
    end
  end
end