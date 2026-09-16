defmodule Nexthack.ObjectFactory do
  @moduledoc """
  Factory for creating item actors -- the counterpart of NetHack's
  `newobj()` / `mkobj()` (mkobj.c).

      {:ok, item} = Nexthack.ObjectFactory.new(:potion_of_healing,
                                                quantity: 3)
      {:ok, item} = Nexthack.ObjectFactory.new_random(world_pid: world)
  """

  alias Nexthack.Object

  @doc "Create an item of a given type. See %Nexthack.Object{} for opts."
  def new(otype, opts \\ []) do
    Object.create(otype, opts)
  end

  @doc "Create a random item (weighted by the object database probabilities)."
  def new_random(opts \\ []) do
    new(Nexthack.ObjectDB.random_type(), opts)
  end

  # --- class specific helpers (like the newN() helpers in object.c) --------

  def new_potion(name, opts \\ []) do
    new(String.to_atom("potion_of_" <> to_string(name)), opts)
  end

  def new_scroll(name, opts \\ []) do
    new(String.to_atom("scroll_of_" <> to_string(name)), opts)
  end

  def new_wand(name, opts \\ []) do
    new(String.to_atom("wand_of_" <> to_string(name)), opts)
  end

  def new_ring(name, opts \\ []) do
    new(String.to_atom("ring_of_" <> to_string(name)), opts)
  end

  def new_amulet(name, opts \\ []) do
    new(String.to_atom("amulet_of_" <> to_string(name)), opts)
  end

  def new_book(name, opts \\ []), do: new(name, opts)
  def new_gem(name, opts \\ []), do: new(name, opts)
  def new_food(name, opts \\ []), do: new(name, opts)
end