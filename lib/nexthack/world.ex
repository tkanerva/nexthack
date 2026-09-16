defmodule Nexthack.World do
  @moduledoc """
  World supervision tree and coordinator.
  Manages all actors in the game and provides coordination services.

  The world also keeps the floor item piles: for each map position
  the list of item actors lying there (NetHack's `nexthere` lists).
  Items are spawned on the floor by the world and move between the
  floor, inventories and containers by messages only.
  """
  
  use GenServer
  alias Nexthack.Message
  alias Nexthack.Trap
  alias Nexthack.Object
  alias Nexthack.ObjectDB
  alias Nexthack.ObjectFactory

  # World state
  defstruct [
    map: nil,
    monsters: [],
    player_pid: nil,
    trap_actors: [],
    floor_items: %{},
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
  Place traps in the world
  """
  def place_traps(pid, count) do
    GenServer.cast(pid, {:place_traps, count, self()})
  end

  @doc """
  Check for traps at a position
  """
  def check_traps_at_position(pid, pos, entity_pid) do
    GenServer.cast(pid, {:check_traps_at_position, pos, entity_pid, self()})
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

  # --- item API (floor piles) --------------------------------------------

  @doc """
  Spawn an item of type `otype` on the floor at `pos` (mkobj +
  putobj). Returns `{:ok, item_pid}`.
  """
  def spawn_item(pid, otype, pos, opts \\ []) do
    GenServer.call(pid, {:spawn_item, otype, pos, opts})
  end

  @doc "Spawn a random item (weighted by the object database) on the floor."
  def spawn_random_item(pid, pos, opts \\ []) do
    GenServer.call(pid, {:spawn_random_item, pos, opts})
  end

  @doc "The list of item pids lying on the floor at `pos` (top first)."
  def items_at(pid, pos) do
    GenServer.call(pid, {:items_at, pos})
  end

  @doc "How many items are on the floor."
  def floor_item_count(pid) do
    GenServer.call(pid, :floor_item_count)
  end

  @doc """
  Remove the top item of the floor pile at `pos` and hand it over to
  `carrier_pid` (the first step of pick_obj()). Returns
  `{:ok, item_pid}` or `:nothing`.
  """
  def take_top_item_at(pid, pos, carrier_pid) do
    GenServer.call(pid, {:take_top_item_at, pos, carrier_pid})
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
      monsters_goblins =
        goblins
        |> Enum.map(fn _i ->
          pos = find_empty_position(state.map)
          {:ok, pid} = Nexthack.Monster.Goblin.create(pos, self())
          pid
        end)
      
      # Spawn orcs
      orcs = count_by_type[:orcs] || 2
      monsters_orcs =
        orcs
        |> Enum.map(fn _i ->
          pos = find_empty_position(state.map)
          {:ok, pid} = Nexthack.Monster.Orc.create(pos, self())
          pid
        end)
      
      # Spawn bats
      bats = count_by_type[:bats] || 3
      monsters_bats =
        bats
        |> Enum.map(fn _i ->
          pos = find_empty_position(state.map)
          {:ok, pid} = Nexthack.Monster.Bat.create(pos, self())
          pid
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
  def handle_cast({:place_traps, count, caller}, state) do
    if state.map do
      # Find empty floor positions for traps
      floor_positions = for y <- 0..23, x <- 0..79, into: [], do: {x, y}
      |> Enum.filter(fn {x, y} ->
        tile = state.map |> Enum.at(y) |> Enum.at(x)
        tile == 0  # Empty floor
      end)
      
      # Place random traps
      trap_count = min(count, length(floor_positions))
      traps_placed = []
      
      Enum.take_random(floor_positions, trap_count)
      |> Enum.each(fn pos ->
        trap_pid = Trap.TrapFactory.create_random_trap(pos, self())
        traps_placed = [trap_pid | traps_placed]
      end)
      
      new_state = %{state | trap_actors: traps_placed}
      
      # Broadcast trap placement
      Message.Broadcast.broadcast(%{
        type: :broadcast,
        message: "Placed #{trap_count} traps",
        source: "world"
      }, self())
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:check_traps_at_position, pos, entity_pid, caller}, state) do
    # Check if there are any traps at this position
    Enum.each(state.trap_actors, fn trap_pid ->
      trap_pos = Trap.get_position(trap_pid)
      if trap_pos == pos and not Trap.triggered?(trap_pid) and not Trap.disarmed?(trap_pid) do
        # Trigger the trap
        Trap.trigger(trap_pid, entity_pid)
      end
    end)
    
    {:noreply, state}
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

  # --- item handling --------------------------------------------------------

  @impl true
  def handle_call({:spawn_item, otype, pos, opts}, _from, state) do
    opts = Keyword.put(opts, :where, :floor)
    opts = Keyword.put(opts, :pos, pos)
    opts = Keyword.put(opts, :world_pid, self())

    case ObjectFactory.new(otype, opts) do
      {:ok, item} ->
        floor_items = Map.update(state.floor_items, pos, [item], fn list -> [item | list] end)
        new_state = %{state | floor_items: floor_items}

        Message.Broadcast.broadcast(%{
          type: :broadcast,
          message: "A #{Object.base_name(Object.state(item))} lies here.",
          source: "world"
        }, self())

        {:reply, {:ok, item}, new_state}
    end
  end

  @impl true
  def handle_call({:spawn_random_item, pos, opts}, _from, state) do
    otype = ObjectDB.random_type()
    handle_call({:spawn_item, otype, pos, opts}, nil, state)
  end

  @impl true
  def handle_call({:items_at, pos}, _from, state) do
    {:reply, Map.get(state.floor_items, pos, []), state}
  end

  @impl true
  def handle_call(:floor_item_count, _from, state) do
    count = state.floor_items |> Map.values() |> List.flatten() |> length()
    {:reply, count, state}
  end

  @impl true
  def handle_call({:take_top_item_at, pos, carrier_pid}, _from, state) do
    case Map.get(state.floor_items, pos, []) do
      [top | rest] ->
        Object.set_carrier(top, carrier_pid)
        Object.set_where(top, :invent)

        floor_items =
          if rest == [] do
            Map.delete(state.floor_items, pos)
          else
            Map.put(state.floor_items, pos, rest)
          end

        {:reply, {:ok, top}, %{state | floor_items: floor_items}}
      [] ->
        {:reply, :nothing, state}
    end
  end

  # --- queries -----------------------------------------------------------------

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

  # --- info ----------------------------------------------------------------------

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

  # An inventory (or a dying monster) puts an item on a floor pile
  @impl true
  def handle_info({:drop_floor_item, pos, item, _carrier}, state) do
    floor_items = Map.update(state.floor_items, pos, [item], fn list -> [item | list] end)
    {:noreply, %{state | floor_items: floor_items}}
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
      {:ok, player_pid} = Nexthack.Player.create({20, 10}, world_pid)
      
      # Register player with world
      GenServer.cast(world_pid, {:register_player, player_pid})
      
      # Initialize world
      Nexthack.World.initialize(world_pid)
      
      # Spawn monsters
      Nexthack.World.spawn_monsters(world_pid, goblins: 4, orcs: 2, bats: 3)
      
      # Place traps
      Nexthack.World.place_traps(world_pid, 10)

      # Starting equipment: a dagger, some rations and gold in the purse
      {:ok, dagger} = Nexthack.ObjectFactory.new(:dagger, world_pid: world_pid)
      Nexthack.Player.give_item(player_pid, dagger)
      {:ok, rations} = Nexthack.ObjectFactory.new(:rations, world_pid: world_pid)
      Nexthack.Player.give_item(player_pid, rations)
      Nexthack.Player.add_gold(player_pid, 100)

      # Scatter some loot on the floor
      1..6
      |> Enum.each(fn _i ->
        pos = {Enum.random(1..78), Enum.random(1..22)}
        Nexthack.World.spawn_random_item(world_pid, pos, [])
      end)
      
      {world_pid, player_pid}
    end
  end
end
