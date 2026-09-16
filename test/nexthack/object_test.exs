defmodule Nexthack.ObjectTest do
  use ExUnit.Case
  alias Nexthack.Object
  alias Nexthack.ObjectFactory
  alias Nexthack.ObjectDB

  test "an object can be created and inspected" do
    {:ok, item} = ObjectFactory.new(:dagger)
    assert is_pid(item)

    assert Object.otype(item) == :dagger
    assert Object.oclass(item) == :weapon
    assert Object.quantity(item) == 1
    assert Object.where(item) == :free

    state = Object.state(item)
    assert state.id != nil
    assert state.carrier == nil
    assert state.container == nil
  end

  test "objects describe themselves like NetHack xname" do
    {:ok, item} = ObjectFactory.new(:dagger)
    assert Object.describe(item) == "a dagger"

    {:ok, potions} = ObjectFactory.new(:potion_of_healing, quantity: 3)
    assert Object.describe(potions) == "3 potions"

    Object.identify(potions)
    Object.set_blessed(potions, true)
    Process.sleep(20)
    assert Object.describe(potions) == "3 potions of healing (blessed)"
  end

  test "unknown potions show a generic description until identified" do
    {:ok, item} = ObjectFactory.new(:potion_of_sleep)
    assert Object.describe(item) == "a potion"

    Object.identify(item)
    assert Object.describe(item) == "a potion of sleep"
  end

  test "wands show their charges and run out" do
    {:ok, wand} = ObjectFactory.new(:wand_of_fire, spe: 10, bknown: true, known: true)
    assert Object.describe(wand) == "a wand of fire (10)"

    Object.use_charge(wand, 3)
    assert Object.charges(wand) == 7
    assert Object.describe(wand) == "a wand of fire (7)"

    # last 7 charges -> the wand is used up and its process stops
    Object.use_charge(wand, 7)
    Process.sleep(20)
    assert Object.alive?(wand) == false
  end

  test "consuming decrements the quantity and frees the item" do
    {:ok, rations} = ObjectFactory.new(:rations, quantity: 2)
    Object.consume(rations, 1)
    assert Object.quantity(rations) == 1

    Object.consume(rations, 1)
    Process.sleep(20)
    assert Object.alive?(rations) == false
  end

  test "items can be renamed (ONAME)" do
    {:ok, item} = ObjectFactory.new(:dagger)
    Object.rename(item, "Dagger of Doom")
    assert Object.describe(item) == "the Dagger of Doom"
  end

  test "enchantments are shown as +N / -N" do
    {:ok, mace} = ObjectFactory.new(:mace)
    Object.set_spe(mace, 2)
    Process.sleep(20)
    assert Object.describe(mace) == "a +2 mace"

    Object.set_spe(mace, -1)
    Process.sleep(20)
    assert Object.describe(mace) == "a -1 mace"
  end

  test "containers can hold and tip out items" do
    {:ok, box} = ObjectFactory.new(:large_box)
    {:ok, dagger} = ObjectFactory.new(:dagger)

    assert :ok = Object.add_content(box, dagger)
    Process.sleep(20)
    assert Object.has_contents?(box)
    assert Object.state(dagger).where == :contained
    assert Object.state(dagger).container == box

    contents = Object.tip_contents(box)
    Process.sleep(20)
    assert contents == [dagger]
    assert Object.has_contents?(box) == false
    assert Object.state(dagger).where == :free
    assert Object.state(dagger).container == nil
  end

  test "items can be equipped in slots (owornmask)" do
    {:ok, sword} = ObjectFactory.new(:short_sword)
    Object.equip(sword, :weapon)
    assert Object.worn_slots(sword) == [:weapon]

    Object.unequip(sword, :weapon)
    assert Object.worn_slots(sword) == []
  end

  test "weight and value scale with quantity" do
    {:ok, arrows} = ObjectFactory.new(:arrow, quantity: 20)
    assert Object.weight(arrows) == ObjectDB.get(:arrow).weight * 20

    {:ok, gold} = ObjectFactory.new(:gold_piece, quantity: 50)
    assert Object.value(gold) == 50
    assert Object.weight(gold) == 0
  end

  test "mergable? follows the NetHack merging rules" do
    {:ok, a} = ObjectFactory.new(:potion_of_healing)
    {:ok, b} = ObjectFactory.new(:potion_of_healing)
    assert Object.mergable?(Object.state(a), Object.state(b))

    Object.set_blessed(a, true)
    Process.sleep(20)
    refute Object.mergable?(Object.state(a), Object.state(b))

    {:ok, c} = ObjectFactory.new(:potion_of_sleep)
    refute Object.mergable?(Object.state(b), Object.state(c))

    # named items only merge with identically named ones
    {:ok, d} = ObjectFactory.new(:dagger)
    Object.rename(d, "Sting")
    Process.sleep(20)
    {:ok, e} = ObjectFactory.new(:dagger)
    refute Object.mergable?(Object.state(d), Object.state(e))
  end
end
