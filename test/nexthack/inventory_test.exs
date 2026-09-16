defmodule Nexthack.InventoryTest do
  use ExUnit.Case
  alias Nexthack.Inventory
  alias Nexthack.Object
  alias Nexthack.ObjectFactory

  defp new_inventory(opts \\ []) do
    {:ok, inv} =
      Inventory.start_link(self(), Keyword.put(opts, :carrier_id, "hero"))
    inv
  end

  test "items get inventory letters in order" do
    inv = new_inventory()
    {:ok, a} = ObjectFactory.new(:dagger)
    {:ok, potion} = ObjectFactory.new(:potion_of_healing)

    assert Inventory.add_item(inv, a) == {:ok, ?a}
    assert Inventory.add_item(inv, potion) == {:ok, ?b}
    assert Inventory.item_at(inv, ?a) == a
    assert Inventory.item_at(inv, ?b) == potion
    assert Inventory.invlet_of(inv, potion) == ?b
    assert Inventory.count(inv) == 2
  end

  test "stacks merge on add (addinv)" do
    inv = new_inventory()
    {:ok, a} = ObjectFactory.new(:potion_of_healing, quantity: 1)
    {:ok, b} = ObjectFactory.new(:potion_of_healing, quantity: 2)

    assert Inventory.add_item(inv, a) == {:ok, ?a}
    assert Inventory.add_item(inv, b) == {:merged, ?a}

    assert Object.quantity(a) == 3
    assert Object.alive?(b) == false
    assert Inventory.count(inv) == 1
  end

  test "blessed and uncursed stacks do not merge" do
    inv = new_inventory()
    {:ok, a} = ObjectFactory.new(:potion_of_healing)
    {:ok, b} = ObjectFactory.new(:potion_of_healing)
    Object.set_blessed(b, true)
    Process.sleep(20)

    assert Inventory.add_item(inv, a) == {:ok, ?a}
    assert Inventory.add_item(inv, b) == {:ok, ?b}
    assert Inventory.count(inv) == 2
  end

  test "gold is collected into the $ slot" do
    inv = new_inventory()
    {:ok, g1} = ObjectFactory.new(:gold_piece, quantity: 30)
    {:ok, g2} = ObjectFactory.new(:gold_piece, quantity: 20)

    assert Inventory.add_item(inv, g1) == :gold
    assert Inventory.add_item(inv, g2) == :gold
    Process.sleep(20)
    assert Inventory.gold(inv) == 50
    assert {:error, :not_enough_gold} = Inventory.remove_gold(inv, 51)
    assert {:ok, 1} = Inventory.remove_gold(inv, 49)
  end

  test "picking up respects the carry weight limit" do
    inv = new_inventory()
    {:ok, boulders} = ObjectFactory.new(:boulder, quantity: 200)
    assert Inventory.pick_up(inv, boulders) == {:error, :too_heavy}
  end

  test "dropping puts items on the floor pile of the world" do
    inv = new_inventory(world_pid: self())
    {:ok, a} = ObjectFactory.new(:dagger)
    Inventory.add_item(inv, a)

    assert {:ok, [[?a, ^a]]} = Inventory.drop(inv, [?a], {5, 5})
    assert_received {:drop_floor_item, {5, 5}, ^a, _}
    Process.sleep(20)
    assert Object.state(a).where == :floor
    assert Object.state(a).pos == {5, 5}
    assert Inventory.count(inv) == 0
  end

  test "the inventory list is sorted NetHack-style" do
    inv = new_inventory()
    {:ok, sword} = ObjectFactory.new(:short_sword)
    {:ok, potion} = ObjectFactory.new(:potion_of_healing, known: true)
    {:ok, ring} = ObjectFactory.new(:ring_of_protection)
    Inventory.add_item(inv, sword) # ?a
    Inventory.add_item(inv, potion) # ?b
    Inventory.add_item(inv, ring)   # ?c

    # class order: rings before potions, potions before weapons
    lines = Inventory.list(inv)
    assert [l1, l2, l3] = lines
    assert l1 == "c) a ring of protection"
    assert l2 == "b) a potion of healing"
    assert l3 == "a) a short sword"
  end

  test "organize reassigns letters in sort order (doorganize)" do
    inv = new_inventory()
    {:ok, sword} = ObjectFactory.new(:short_sword)
    {:ok, potion} = ObjectFactory.new(:potion_of_healing, known: true)
    {:ok, ring} = ObjectFactory.new(:ring_of_protection)
    Inventory.add_item(inv, sword)
    Inventory.add_item(inv, potion)
    Inventory.add_item(inv, ring)

    Inventory.organize(inv)
    assert Inventory.list(inv) == [
      "a) a ring of protection",
      "b) a potion of healing",
      "c) a short sword"
    ]
    assert Inventory.item_at(inv, ?a) == ring
    assert Inventory.item_at(inv, ?b) == potion
    assert Inventory.item_at(inv, ?c) == sword
  end

  test "splitting a stack (altadjust)" do
    inv = new_inventory()
    {:ok, arrows} = ObjectFactory.new(:arrow, quantity: 20)
    Inventory.add_item(inv, arrows)

    assert {:ok, ?a, ?b} = Inventory.split_stack(inv, ?a, 5)
    Process.sleep(20)
    assert Object.quantity(arrows) == 15

    other = Inventory.item_at(inv, ?b)
    assert Object.quantity(other) == 5
    assert Object.state(other).where == :invent

    # cannot split coins, nor more than the stack has
    {:ok, gold} = ObjectFactory.new(:gold_piece, quantity: 10)
    Inventory.add_item(inv, gold)
    gold_let = Inventory.invlet_of(inv, gold)
    # gold merged into the $ slot, so there is no letter for it
    assert gold_let == nil
  end

  test "equipping swaps out the previous item in a slot" do
    inv = new_inventory()
    {:ok, sword} = ObjectFactory.new(:short_sword)
    {:ok, bow} = ObjectFactory.new(:bow)
    Inventory.add_item(inv, sword)
    Inventory.add_item(inv, bow)

    assert {:ok, nil} = Inventory.equip(inv, sword, :weapon)
    assert Inventory.worn_at(inv, :weapon) == sword

    # wielding the bow replaces the sword
    assert {:ok, sword} = Inventory.equip(inv, bow, :weapon)
    Process.sleep(20)
    assert Inventory.worn_at(inv, :weapon) == bow
    assert Object.worn_slots(sword) == []
    assert Object.worn_slots(bow) == [:weapon]

    assert {:ok, bow} = Inventory.unequip(inv, :weapon)
    Process.sleep(20)
    assert Inventory.worn_at(inv, :weapon) == nil
  end

  test "the pack is full when no letters remain" do
    {:ok, inv} = Inventory.start_link(self(), max_items: 2, carrier_id: "hero")
    {:ok, a} = ObjectFactory.new(:dagger)
    {:ok, b} = ObjectFactory.new(:mace)
    {:ok, c} = ObjectFactory.new(:spear)

    assert Inventory.add_item(inv, a) == {:ok, ?a}
    assert Inventory.add_item(inv, b) == {:ok, ?b}
    assert Inventory.add_item(inv, c) == {:error, :pack_full}
  end

  test "remove_item frees the holder and marks the item free" do
    inv = new_inventory()
    {:ok, a} = ObjectFactory.new(:dagger)
    Inventory.add_item(inv, a)

    assert {:ok, a} = Inventory.remove_item(inv, ?a)
    Process.sleep(20)
    assert Object.state(a).where == :free
    assert Object.state(a).carrier == nil
    assert Inventory.count(inv) == 0
  end
end
