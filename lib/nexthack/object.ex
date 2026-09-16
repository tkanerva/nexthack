defmodule Nexthack.Object do
  @moduledoc """
  Item actor.

  The Elixir counterpart of NetHack's `struct obj` (include/obj.h).
  Following the actor-model goal of this project, **every object is
  its own Erlang process** (a GenServer): a potion, an arrow, a
  boulder, the Amulet of Yendor... Other actors only ever interact
  with an item by sending it messages; the item's mutable state
  (quantity, enchantment, charges, contents, ...) lives inside the
  item itself.

  Field mapping to the C struct:

      struct obj field      Nexthack.Object field
      -------------         ---------------------
      otype, oclass         :otype, :oclass
      quan                  :quantity
      spe                   :spe          (enchantment, or charges/fuel)
      blessed / cursed      :blessed, :cursed
      where (OBJ_FLOOR..)   :where        (:free, :floor, :contained,
                                           :invent, :minvent, :buried)
      ox, oy                :pos
      ocarry                :carrier      (pid of the carrying actor)
      ocontainer            :container    (pid of the containing item)
      cobj                  :contents     (list of item pids inside)
      owornmask             :worn         (%{slot => true})
      known/dknown/...      :known, :dknown, :bknown, :cknown
      oextra->oname         :name         (user-assigned name)

  When a stack's quantity drops to zero the actor terminates -- the
  Elixir equivalent of `obfree()` -- so items come and go with the
  process lifecycle, supervised like everything else in the world.
  """

  use GenServer
  alias Nexthack.ObjectDB

  # ---------------------------------------------------------------- state

  defstruct [
    id: nil,
    otype: nil,
    oclass: nil,
    name: nil,
    quantity: 1,
    spe: 0,
    blessed: false,
    cursed: false,
    where: :free,
    pos: nil,
    carrier: nil,
    container: nil,
    contents: [],
    known: false,
    dknown: false,
    bknown: false,
    cknown: false,
    worn: %{},
    properties: %{},
    world_pid: nil
  ]

  # ------------------------------------------------------------- public API

  @doc """
  Start an item process. `attrs` is a keyword list; `:otype` is
  mandatory, the rest are optional initial fields (see the struct).
  """
  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs)
  end

  @doc "Convenience wrapper: `Nexthack.Object.create(:dagger, quantity: 2)`."
  def create(otype, opts \\ []) do
    start_link(Keyword.put(opts, :otype, otype))
  end

  # --- queries -----------------------------------------------------------

  @doc "The full state of the item (a %Nexthack.Object{} struct)."
  def state(pid), do: GenServer.call(pid, :state)

  def otype(pid), do: GenServer.call(pid, :otype)
  def oclass(pid), do: GenServer.call(pid, :oclass)
  def quantity(pid), do: GenServer.call(pid, :quantity)
  def where(pid), do: GenServer.call(pid, :where)
  def charges(pid), do: GenServer.call(pid, :charges)
  def worn_slots(pid), do: GenServer.call(pid, :worn_slots)
  def contents(pid), do: GenServer.call(pid, :contents)
  def has_contents?(pid), do: GenServer.call(pid, :has_contents?)

  @doc "Weight of the whole stack, in NetHack units (1 = 0.1 lb)."
  def weight(pid), do: GenServer.call(pid, :weight)

  @doc "Value of the whole stack, in gold pieces."
  def value(pid), do: GenServer.call(pid, :value)

  @doc "Is the item process alive (quantity > 0)?"
  def alive?(pid) do
    if Process.alive?(pid) do
      GenServer.call(pid, :quantity, 100) > 0
    else
      false
    end
  end

  # --- commands ------------------------------------------------------------

  def add_quantity(pid, n), do: GenServer.call(pid, {:add_quantity, n})

  @doc """
  Consume `n` of the stack. When the stack runs out the item actor
  stops (obfree). Returns the remaining quantity or `:gone`.
  """
  def consume(pid, n \\ 1), do: GenServer.call(pid, {:consume, n})

  @doc "Spend `n` charges (wands) or fuel (lamps). Returns remaining."
  def use_charge(pid, n \\ 1), do: GenServer.call(pid, {:use_charge, n})

  def set_where(pid, where), do: GenServer.cast(pid, {:set_where, where})
  def set_pos(pid, pos), do: GenServer.cast(pid, {:set_pos, pos})
  def set_carrier(pid, carrier), do: GenServer.cast(pid, {:set_carrier, carrier})
  def set_container(pid, container), do: GenServer.cast(pid, {:set_container, container})
  def clear_holder(pid), do: GenServer.cast(pid, :clear_holder)

  @doc "Put `item` inside this container (mirrors the cobj list)."
  def add_content(pid, item), do: GenServer.call(pid, {:add_content, item})

  def remove_content(pid, item), do: GenServer.call(pid, {:remove_content, item})

  @doc "Empty the container; returns the list of contained item pids."
  def tip_contents(pid), do: GenServer.call(pid, :tip_contents)

  @doc "Mark the item as worn in `slot` (owornmask)."
  def equip(pid, slot), do: GenServer.call(pid, {:equip, slot})

  def unequip(pid, slot), do: GenServer.call(pid, {:unequip, slot})

  def set_property(pid, key, value), do: GenServer.cast(pid, {:set_property, key, value})

  @doc "Give the item a personal name (ONAME); nil removes it."
  def rename(pid, name), do: GenServer.call(pid, {:rename, name})

  def set_blessed(pid, blessed), do: GenServer.cast(pid, {:set_blessed, blessed})
  def set_cursed(pid, cursed), do: GenServer.cast(pid, {:set_cursed, cursed})
  def set_spe(pid, spe), do: GenServer.cast(pid, {:set_spe, spe})

  @doc "The hero has seen the item up close (dknown)."
  def observe(pid), do: GenServer.cast(pid, :observe)

  @doc "Full identification: nature, enchantment and BUC all known."
  def identify(pid), do: GenServer.call(pid, :identify)

  # --- naming / display (the xname() family) -------------------------------

  @doc """
  The name to show for the item, taking discovery into account
  (a simplified `simpleonames()`): user name if given, the real
  name if the type is known or always visible, otherwise the
  generic placeholder ("potion", "scroll", ...).
  """
  def base_name(state) when is_map(state) do
    base_name(state, ObjectDB.get(state.otype))
  end

  defp base_name(state, def_) do
    cond do
      is_binary(state.name) and state.name != "" ->
        state.name

      state.known or known_by_default?(def_) ->
        def_.name

      true ->
        def_.description
    end
  end

  @doc """
  NetHack-style description of an item (simplified `xname()`):

      "a dagger"
      "3 potions of healing (blessed)"
      "a +2 mace"
      "a wand of fire (10)"
      "the Dagger of Doom"
  """
  def describe(state) when is_map(state) do
    def_ = ObjectDB.get(state.otype)

    cond do
      is_binary(state.name) and state.name != "" ->
        "the " <> state.name <> buc_suffix(state)

      state.quantity > 1 ->
        singular = base_name(state, def_)
        "#{state.quantity} " <> pluralize(singular) <>
          spe_suffix(state, def_) <> buc_suffix(state)

      true ->
        singular = base_name(state, def_)
        article(singular) <> singular <>
          spe_suffix(state, def_) <> buc_suffix(state)
    end
  end

  def describe(pid), do: describe(state(pid))

  # --- merging (mergable() from object.c) ----------------------------------

  @doc """
  Can two stacks be merged? Mirrors NetHack's `mergable()`
  (object.c): same type, same blessed/cursed state, same
  enchantment (when both are known), and compatible user names.
  Coins always merge.
  """
  def mergable?(%{otype: a, oclass: oa} = sa, %{otype: b, oclass: ob} = sb) do
    if a != b or oa != ob do
      false
    else
      if oa == :coin do
        true
      else
        same_buc = sa.blessed == sb.blessed and sa.cursed == sb.cursed
        same_spe = if sa.bknown and sb.bknown, do: sa.spe == sb.spe, else: true
        same_buc and same_spe and same_name?(sa, sb)
      end
    end
  end

  # if either item has a personal name, both must have the same one
  defp named?(state) do
    is_binary(state.name) and state.name != ""
  end

  defp same_name?(sa, sb) do
    if named?(sa) or named?(sb) do
      named?(sa) and named?(sb) and sa.name == sb.name
    else
      true
    end
  end

  # ---------------------------------------------------------- GenServer impl

  @impl true
  def init(attrs) do
    otype = Keyword.fetch!(attrs, :otype)
    def_ = ObjectDB.get(otype)

    state = %__MODULE__{
      id: attrs[:id] || "#{def_.otype}_#{System.unique_integer([:positive])}",
      otype: otype,
      oclass: def_.oclass,
      name: attrs[:name],
      quantity: attrs[:quantity] || 1,
      spe: attrs[:spe] || 0,
      blessed: attrs[:blessed] || false,
      cursed: attrs[:cursed] || false,
      where: attrs[:where] || :free,
      pos: attrs[:pos],
      carrier: attrs[:carrier],
      container: attrs[:container],
      contents: attrs[:contents] || [],
      known: attrs[:known] || false,
      dknown: attrs[:dknown] || false,
      bknown: attrs[:bknown] || (attrs[:spe] || 0) != 0,
      cknown: attrs[:cknown] || false,
      worn: attrs[:worn] || %{},
      properties: attrs[:properties] || %{},
      world_pid: attrs[:world_pid]
    }

    {:ok, state}
  end

  # --- queries -------------------------------------------------------------

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}
  def handle_call(:otype, _from, state), do: {:reply, state.otype, state}
  def handle_call(:oclass, _from, state), do: {:reply, state.oclass, state}
  def handle_call(:quantity, _from, state), do: {:reply, state.quantity, state}
  def handle_call(:where, _from, state), do: {:reply, state.where, state}
  def handle_call(:charges, _from, state), do: {:reply, state.spe, state}
  def handle_call(:worn_slots, _from, state), do: {:reply, Map.keys(state.worn), state}
  def handle_call(:contents, _from, state), do: {:reply, state.contents, state}

  @impl true
  def handle_call(:has_contents?, _from, state) do
    {:reply, state.contents != [], state}
  end

  @impl true
  def handle_call(:weight, _from, state) do
    def_ = ObjectDB.get(state.otype)
    {:reply, def_.weight * state.quantity, state}
  end

  @impl true
  def handle_call(:value, _from, state) do
    def_ = ObjectDB.get(state.otype)
    {:reply, def_.cost * state.quantity, state}
  end

  # --- commands --------------------------------------------------------------

  @impl true
  def handle_call({:add_quantity, n}, _from, state) do
    q = state.quantity + n

    if q <= 0 do
      broadcast(state, "was destroyed.")
      {:stop, :normal, :gone, %{state | quantity: 0}}
    else
      {:reply, q, %{state | quantity: q}}
    end
  end

  @impl true
  def handle_call({:consume, n}, _from, state) do
    q = state.quantity - n

    if q <= 0 do
      broadcast(state, "is used up.")
      {:stop, :normal, :gone, %{state | quantity: 0}}
    else
      {:reply, q, %{state | quantity: q}}
    end
  end

  @impl true
  def handle_call({:use_charge, n}, _from, state) do
    c = state.spe - n

    if c <= 0 do
      broadcast(state, "runs out of charge.")
      {:stop, :normal, :gone, %{state | spe: 0}}
    else
      {:reply, c, %{state | spe: c, bknown: true}}
    end
  end

  @impl true
  def handle_call({:equip, slot}, _from, state) do
    {:reply, :ok, %{state | worn: Map.put(state.worn, slot, true)}}
  end

  @impl true
  def handle_call({:unequip, slot}, _from, state) do
    {:reply, :ok, %{state | worn: Map.delete(state.worn, slot)}}
  end

  @impl true
  def handle_call({:rename, name}, _from, state) do
    {:reply, :ok, %{state | name: name, known: true, dknown: true}}
  end

  @impl true
  def handle_call(:identify, _from, state) do
    {:reply, :ok, %{state | known: true, dknown: true, bknown: true}}
  end

  @impl true
  def handle_call({:add_content, item}, _from, state) do
    def_ = ObjectDB.get(state.otype)

    if def_.container do
      # the contained item updates itself; no reply needed
      Object.set_carrier(item, nil)
      Object.set_container(item, self())
      Object.set_where(item, :contained)
      {:reply, :ok, %{state | contents: [item | state.contents]}}
    else
      {:reply, {:error, :not_a_container}, state}
    end
  end

  @impl true
  def handle_call({:remove_content, item}, _from, state) do
    if item in state.contents do
      Object.clear_holder(item)
      Object.set_where(item, :free)
      {:reply, :ok, %{state | contents: List.delete(state.contents, item)}}
    else
      {:reply, {:error, :not_inside}, state}
    end
  end

  @impl true
  def handle_call(:tip_contents, _from, state) do
    items = state.contents

    Enum.each(items, fn item ->
      Object.clear_holder(item)
      Object.set_where(item, :free)
    end)

    {:reply, items, %{state | contents: [], cknown: true}}
  end

  # --- casts ------------------------------------------------------------------

  @impl true
  def handle_cast({:set_where, where}, state),
    do: {:noreply, %{state | where: where}}

  def handle_cast({:set_pos, pos}, state),
    do: {:noreply, %{state | pos: pos}}

  def handle_cast({:set_carrier, carrier}, state),
    do: {:noreply, %{state | carrier: carrier}}

  def handle_cast({:set_container, container}, state),
    do: {:noreply, %{state | container: container}}

  def handle_cast(:clear_holder, state),
    do: {:noreply, %{state | carrier: nil, container: nil}}

  def handle_cast({:set_property, key, value}, state),
    do: {:noreply, %{state | properties: Map.put(state.properties, key, value)}}

  def handle_cast({:set_blessed, blessed}, state),
    do: {:noreply, %{state | blessed: blessed, bknown: true}}

  def handle_cast({:set_cursed, cursed}, state),
    do: {:noreply, %{state | cursed: cursed, bknown: true}}

  def handle_cast({:set_spe, spe}, state),
    do: {:noreply, %{state | spe: spe, bknown: true}}

  def handle_cast(:observe, state),
    do: {:noreply, %{state | dknown: true}}

  # --- internal helpers ---------------------------------------------------------

  defp known_by_default?(def_) do
    def_.oclass not in [:potion, :scroll, :spellbook, :wand]
  end

  defp article(name) do
    if String.starts_with?(String.downcase(name), ["a", "e", "i", "o", "u"]) do
      "an "
    else
      "a "
    end
  end

  defp pluralize(name) do
    if String.ends_with?(name, "s") do
      name
    else
      name <> "s"
    end
  end

  defp spe_suffix(state, def_) do
    known = state.bknown or state.known

    cond do
      def_.charged and known and state.spe > 0 ->
        " (#{state.spe})"

      def_.charged and not known ->
        " (?)"

      def_.enchantable and known and state.spe != 0 ->
        if state.spe > 0, do: " (+#{state.spe})", else: " (-#{-state.spe})"

      true ->
        ""
    end
  end

  defp buc_suffix(state) do
    cond do
      state.blessed -> " (blessed)"
      state.cursed -> " (cursed)"
      true -> ""
    end
  end

  defp broadcast(state, text) do
    if state.world_pid do
      send(state.world_pid, {:broadcast, "#{describe(state)} #{text}", state.id})
    end
  end
end
