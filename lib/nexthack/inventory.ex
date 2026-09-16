defmodule Nexthack.Inventory do
  @moduledoc """
  Per-carrier inventory actor.

  The Elixir counterpart of the hero's `gi.invent` object list and
  the functions around it in `invent.c`. One Inventory process is
  started for every carrier (the player now, monsters later -- the
  same module plays the role of `minvent`):

      Inventory function        invent.c counterpart
      ------------------------  -----------------------------
      add_item/2                addinv()           (stack merging, letter)
      remove_item/2             freeinv() / extract_nobj()
      drop/3                    dropobj()
      pick_up/2                 pick_obj()         (weight check)
      list/1                    invent()           (display, sorted)
      organize/1                doorganize()       (#organize)
      split_stack/3             #altadjust (adjust_split)
      equip/3, unequip/2        wield.c / do.c     (owornmask slots)
      gold/0, add_gold/2        your_gold / $ slot

  Inventory letters live in the inventory, not in the item: the
  `invlet` of a C `struct obj` is modelled as the map key
  (`?$` is reserved for gold, then `?a..?z`, `?A..?Z`), which keeps
  items reusable between floor, containers and inventories -- exactly
  like the `where` field of `struct obj` -- and makes `#organize`
  (reassigning letters) a pure state update.
  """

  use GenServer
  alias Nexthack.Object
  alias Nexthack.ObjectDB
  alias Nexthack.ObjectClass

  # ----------------------------------------------------------------- state

  defstruct [
    carrier: nil,
    carrier_id: nil,
    world_pid: nil,
    gold: 0,
    items: %{},
    order: [],
    max_items: 52
  ]

  # NetHack: 1 cn = 0.1 lb; the hero's carry limit is 999 cn
  @carry_limit 999

  @lower_letters Enum.map(?a..?z, & &1)
  @upper_letters Enum.map(?A..?Z, & &1)
  @letters @lower_letters ++ @upper_letters

  # ------------------------------------------------------------ public API

  def start_link(carrier, opts \\ []) do
    GenServer.start_link(__MODULE__, {carrier, opts})
  end

  @doc """
  Add an item to the inventory (addinv). Returns:
    * `:gold`                 - the item was coins, merged into `$`
    * `{:merged, invlet}`     - merged into an existing stack
    * `{:ok, invlet}`         - a fresh letter was assigned
    * `{:error, :pack_full}`  - no free letter left
  """
  def add_item(inv, item), do: GenServer.call(inv, {:add_item, item})

  def remove_item(inv, invlet), do: GenServer.call(inv, {:remove_item, invlet})

  @doc """
  Drop items onto the floor at `pos` (dropobj). `invlets` is a list
  of letters or `:all`. The world (if known) is told to put the
  items on its floor pile. Returns `{:ok, [[invlet, item], ...]}`.
  """
  def drop(inv, invlets, pos), do: GenServer.call(inv, {:drop, invlets, pos})

  @doc "Pick an item up (pick_obj), enforcing the carry weight limit."
  def pick_up(inv, item), do: GenServer.call(inv, {:pick_up, item})

  def item_at(inv, invlet), do: GenServer.call(inv, {:item_at, invlet})

  @doc "All items as `[{invlet, item_pid}, ...]` in insertion order."
  def items(inv), do: GenServer.call(inv, :items)

  @doc "The letter assigned to a given item, or nil."
  def invlet_of(inv, item), do: GenServer.call(inv, {:invlet_of, item})

  @doc """
  The inventory as display lines (the display part of invent()):

      ["$) 100 gold pieces", "a) 2 maces (+1)", "b) a dagger"]
  """
  def list(inv), do: GenServer.call(inv, :list)

  @doc "Reassign letters in sort order (doorganize / #organize)."
  def organize(inv), do: GenServer.call(inv, :organize)

  @doc """
  Split a stack: move `count` of the item into a new stack
  (#altadjust / adjust_split). Returns `{:ok, from_let, to_let}`.
  """
  def split_stack(inv, invlet, count),
    do: GenServer.call(inv, {:split_stack, invlet, count})

  @doc "Wield/wear an item in `slot`; returns `{:ok, previous_item}`."
  def equip(inv, item, slot), do: GenServer.call(inv, {:equip, item, slot})

  @doc "Remove the item worn in `slot`; returns `{:ok, item}`."
  def unequip(inv, slot), do: GenServer.call(inv, {:unequip, slot})

  @doc "All worn items as `%{slot => item_pid}`."
  def worn(inv), do: GenServer.call(inv, :worn)

  def worn_at(inv, slot), do: GenServer.call(inv, {:worn_at, slot})

  def total_weight(inv), do: GenServer.call(inv, :total_weight)

  def gold(inv), do: GenServer.call(inv, :gold)
  def add_gold(inv, amount), do: GenServer.call(inv, {:add_gold, amount})
  def remove_gold(inv, amount), do: GenServer.call(inv, {:remove_gold, amount})

  def count(inv), do: GenServer.call(inv, :count)
  def empty?(inv), do: GenServer.call(inv, :empty?)

  # ---------------------------------------------------------- GenServer impl

  @impl true
  def init({carrier, opts}) do
    state = %__MODULE__{
      carrier: carrier,
      carrier_id: opts[:carrier_id] || "carrier",
      world_pid: opts[:world_pid],
      max_items: opts[:max_items] || 52
    }

    {:ok, state}
  end

  # --- add / remove ---------------------------------------------------------

  @impl true
  def handle_call({:add_item, item}, _from, state) do
    item_state = Object.state(item)

    cond do
      item_state.oclass == :coin ->
        # coins always merge into the '$' slot; the coin object itself
        # is freed once its value has been collected
        Object.consume(item, item_state.quantity)
        {:reply, :gold, %{state | gold: state.gold + item_state.quantity}}

      merge_target = find_merge_target(state, item_state) ->
        Object.add_quantity(merge_target, item_state.quantity)
        Object.consume(item, item_state.quantity)
        invlet = Map.key(state.items, merge_target)
        {:reply, {:merged, invlet}, state}

      true ->
        case free_invlet(state) do
          :full ->
            {:reply, {:error, :pack_full}, state}

          invlet ->
            Object.set_carrier(item, state.carrier)
            Object.set_where(item, :invent)
            items = Map.put(state.items, invlet, item)
            {:reply, {:ok, invlet}, %{state | items: items, order: [invlet | state.order]}}
        end
    end
  end

  @impl true
  def handle_call({:remove_item, invlet}, _from, state) do
    case Map.fetch(state.items, invlet) do
      {:ok, item} ->
        Object.clear_holder(item)
        Object.set_where(item, :free)
        items = Map.delete(state.items, invlet)
        {:reply, {:ok, item}, %{state | items: items, order: List.delete(state.order, invlet)}}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  # --- drop / pick ------------------------------------------------------------

  @impl true
  def handle_call({:drop, invlets, pos}, _from, state) do
    to_drop =
      if invlets == :all do
        Map.keys(state.items)
      else
        invlets
      end

    {dropped, new_state} =
      Enum.reduce(to_drop, {[], state}, fn invlet, {acc, st} ->
        case Map.fetch(st.items, invlet) do
          {:ok, item} ->
            Object.set_pos(item, pos)
            Object.set_where(item, :floor)
            Object.clear_holder(item)

            if st.world_pid do
              send(st.world_pid, {:drop_floor_item, pos, item, st.carrier})
            end

            items = Map.delete(st.items, invlet)
            {[invlet, item | acc], %{st | items: items, order: List.delete(st.order, invlet)}}

          :error ->
            {acc, st}
        end
      end)

    {:reply, {:ok, dropped}, new_state}
  end

  @impl true
  def handle_call({:pick_up, item}, _from, state) do
    item_state = Object.state(item)
    weight = ObjectDB.get(item_state.otype).weight * item_state.quantity

    if weight_of(state) + weight > @carry_limit do
      {:reply, {:error, :too_heavy}, state}
    else
      handle_call({:add_item, item}, nil, state)
    end
  end

  # --- queries -----------------------------------------------------------------

  @impl true
  def handle_call(:items, _from, state) do
    {:reply, state.order |> Enum.map(fn let -> {let, Map.get(state.items, let)} end), state}
  end

  @impl true
  def handle_call({:item_at, invlet}, _from, state) do
    {:reply, Map.get(state.items, invlet), state}
  end

  @impl true
  def handle_call({:invlet_of, item}, _from, state) do
    {:reply, Map.key(state.items, item), state}
  end

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, count_of(state), state}
  end

  @impl true
  def handle_call(:empty?, _from, state) do
    {:reply, count_of(state) == 0, state}
  end

  @impl true
  def handle_call(:total_weight, _from, state) do
    {:reply, weight_of(state), state}
  end

  # --- display (invent) ----------------------------------------------------------

  @impl true
  def handle_call(:list, _from, state) do
    item_lines =
      sorted_items(state)
      |> Enum.map(fn {invlet, item} ->
        invlet_char(invlet) <> ") " <> Object.describe(Object.state(item))
      end)

    gold_line =
      if state.gold > 0 do
        ["$) #{state.gold} gold pieces"]
      else
        []
      end

    {:reply, gold_line ++ item_lines, state}
  end

  @impl true
  def handle_call(:organize, _from, state) do
    sorted = sorted_items(state)
    letters = Enum.take(@letters, state.max_items)

    {new_items, new_order} =
      Enum.reduce(sorted, {%{}, []}, fn {_, item}, {items, order} ->
        case Enum.find(letters, fn l -> not Map.has_key?(items, l) end) do
          nil -> {items, order}
          let -> {Map.put(items, let, item), [let | order]}
        end
      end)

    {:reply, :ok, %{state | items: new_items, order: new_order}}
  end

  # --- split (#altadjust) ------------------------------------------------------------

  @impl true
  def handle_call({:split_stack, invlet, count}, _from, state) do
    case Map.fetch(state.items, invlet) do
      {:ok, item} ->
        st = Object.state(item)

        if st.oclass == :coin or count <= 0 or count >= st.quantity do
          {:reply, {:error, :cannot_split}, state}
        else
          {:ok, new_item} =
            Object.create(st.otype,
              quantity: count,
              blessed: st.blessed,
              cursed: st.cursed,
              spe: if(st.bknown, do: st.spe, else: 0),
              bknown: st.bknown,
              known: st.known,
              world_pid: state.world_pid
            )

          Object.add_quantity(item, -count)

          case free_invlet(state) do
            :full ->
              # the split cannot be represented; roll it back
              Object.add_quantity(item, count)
              Object.consume(new_item, count)
              {:reply, {:error, :pack_full}, state}

            invlet2 ->
              Object.set_carrier(new_item, state.carrier)
              Object.set_where(new_item, :invent)
              items = Map.put(state.items, invlet2, new_item)
              {:reply, {:ok, invlet, invlet2}, %{state | items: items, order: [invlet2 | state.order]}}
          end
        end

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  # --- equip / unequip (owornmask) -----------------------------------------------------

  @impl true
  def handle_call({:equip, item, slot}, _from, state) do
    if Map.key(state.items, item) do
      previous = worn_at(state, slot)
      if previous, do: Object.unequip(previous, slot)
      Object.equip(item, slot)
      {:reply, {:ok, previous}, state}
    else
      {:reply, {:error, :not_carried}, state}
    end
  end

  @impl true
  def handle_call({:unequip, slot}, _from, state) do
    case worn_at(state, slot) do
      nil ->
        {:reply, {:error, :not_worn}, state}

      item ->
        Object.unequip(item, slot)
        {:reply, {:ok, item}, state}
    end
  end

  @impl true
  def handle_call(:worn, _from, state) do
    {:reply, worn_map(state), state}
  end

  @impl true
  def handle_call({:worn_at, slot}, _from, state) do
    {:reply, worn_at(state, slot), state}
  end

  # --- gold -----------------------------------------------------------------------------

  @impl true
  def handle_call({:add_gold, amount}, _from, state) do
    {:reply, {:ok, state.gold + amount}, %{state | gold: state.gold + amount}}
  end

  @impl true
  def handle_call({:remove_gold, amount}, _from, state) do
    if state.gold >= amount do
      {:reply, {:ok, state.gold - amount}, %{state | gold: state.gold - amount}}
    else
      {:reply, {:error, :not_enough_gold}, state}
    end
  end

  # --- internal helpers ------------------------------------------------------------------

  defp invlet_char(let), do: <<let>>

  defp free_invlet(state) do
    taken = Map.keys(state.items)
    letters = Enum.take(@letters, state.max_items)

    Enum.find_value(letters, :full, fn let ->
      if let in taken, do: nil, else: let
    end)
  end

  defp find_merge_target(state, item_state) do
    Enum.find_value(state.items, fn {_invlet, pid} ->
      if Process.alive?(pid) do
        other = Object.state(pid)
        if Object.mergable?(other, item_state), do: pid, else: nil
      end
    end)
  end

  defp count_of(state) do
    Map.size(state.items) + if(state.gold > 0, do: 1, else: 0)
  end

  defp weight_of(state) do
    state.items
    |> Enum.reduce(0, fn {_invlet, pid}, acc ->
      if Process.alive?(pid), do: acc + Object.weight(pid), else: acc
    end)
  end

  defp worn_at(state, slot) do
    state.items
    |> Enum.find_value(fn {_invlet, pid} ->
      if Process.alive?(pid) and slot in Object.worn_slots(pid), do: pid
    end)
  end

  defp worn_map(state) do
    state.items
    |> Enum.reduce(%{}, fn {_invlet, pid}, acc ->
      if Process.alive?(pid) do
        Enum.reduce(Object.worn_slots(pid), acc, fn s, a2 -> Map.put(a2, s, pid) end)
      else
        acc
      end
    end)
  end

  # Sort order mirrors loot_classify() / sortloot() in invent.c:
  # class (def_srt_order), then subclass, then otype, then name.
  defp sorted_items(state) do
    state.items
    |> Enum.map(fn {invlet, item} ->
      st = Object.state(item)
      {invlet, item, st, ObjectDB.get(st.otype)}
    end)
    |> Enum.sort_by(fn {_, _, st, def_} ->
      {class_rank(def_.oclass), subclass_rank(def_), st.otype, Object.base_name(st)}
    end)
    |> Enum.map(fn {invlet, item, _, _} -> {invlet, item} end)
  end

  defp class_rank(oclass) do
    order = ObjectClass.sort_order()
    index = Enum.find_index(order, fn c -> c == oclass end)
    if is_nil(index), do: length(order), else: index
  end

  # Simplified subclass designations from loot_classify()
  defp subclass_rank(%{oclass: :weapon, skill: skill}) when not is_nil(skill) do
    cond do
      skill in [:arrow, :bolt, :sling_bullet, :dart, :boomerang] -> 1 # ammo
      skill in [:bow, :crossbow, :sling] -> 2 # launchers
      skill in [:spear, :dagger, :knife] -> 4 # stackable
      true -> 5 # other / polearms
    end
  end

  defp subclass_rank(%{oclass: :armor, skill: cat}) when not is_nil(cat) do
    case cat do
      :helm -> 1
      :gloves -> 2
      :boots -> 3
      :shield -> 4
      :cloak -> 5
      :shirt -> 6
      :suit -> 7
      _ -> 8
    end
  end

  defp subclass_rank(_def_), do: 1
end
