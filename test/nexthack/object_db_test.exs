defmodule Nexthack.ObjectDBTest do
  use ExUnit.Case
  alias Nexthack.ObjectDB
  alias Nexthack.ObjectClass

  test "the database covers a good number of objects" do
    assert length(ObjectDB.all()) > 150
  end

  test "every object has a known class" do
    Enum.each(ObjectDB.all(), fn otype ->
      def_ = ObjectDB.get(otype)
      assert ObjectClass.valid?(def_.oclass), "bad class for #{inspect(otype)}"
    end)
  end

  test "every practical object class has at least one object" do
    covered =
      ObjectDB.all()
      |> Enum.map(fn o -> ObjectDB.get(o).oclass end)
      |> Enum.uniq()

    assert Enum.all?(ObjectClass.all(), fn c -> c in covered or c in [:illegal, :venom] end)
  end

  test "potions, scrolls, books and wands hide their nature until identified" do
    assert ObjectDB.get(:potion_of_healing).description == "potion"
    assert ObjectDB.get(:scroll_of_identify).description == "scroll"
    assert ObjectDB.get(:sleep).description == "book"
    assert ObjectDB.get(:wand_of_fire).description == "wand"
    assert ObjectDB.get(:dagger).description == "dagger"
    assert ObjectDB.get(:ring_of_protection).description == "ring of protection"
  end

  test "random_type returns a known type (mkobj)" do
    1..25
    |> Enum.each(fn _ ->
      assert ObjectDB.known?(ObjectDB.random_type())
    end)
  end

  test "wands are charged and weapons enchantable" do
    assert ObjectDB.get(:wand_of_fire).charged
    assert not ObjectDB.get(:wand_of_fire).enchantable
    assert ObjectDB.get(:mace).enchantable
    assert not ObjectDB.get(:mace).charged
    assert ObjectDB.get(:oil_lamp).light_source
  end

  test "unique objects never merge" do
    assert ObjectDB.get(:amulet_of_yendor).unique
    assert not ObjectDB.get(:amulet_of_yendor).mergeable
    assert not ObjectDB.get(:fake_amulet_of_yendor).mergeable
  end

  test "containers, food and ammo flags" do
    assert ObjectDB.get(:bag_of_holding).container
    assert ObjectDB.get(:chest).container
    assert ObjectDB.get(:rations).food
    assert ObjectDB.get(:arrow).ammo
    assert ObjectDB.get(:bow).launcher
    assert ObjectDB.get(:pick_axe).weptool
  end

  test "armor and gear map to equipment slots" do
    assert ObjectDB.slot_for(:chain_mail) == :armor
    assert ObjectDB.slot_for(:elven_leather_helm) == :helmet
    assert ObjectDB.slot_for(:elven_boots) == :boots
    assert ObjectDB.slot_for(:elven_shield) == :shield
    assert ObjectDB.slot_for(:elven_cloak) == :cloak
    assert ObjectDB.slot_for(:t_shirt) == :shirt
    assert ObjectDB.slot_for(:blindfold) == :blindfold
    assert ObjectDB.slot_for(:ring_of_protection) == :ring
    assert ObjectDB.slot_for(:amulet_of_yendor) == :amulet
    assert ObjectDB.slot_for(:short_sword) == :weapon
    assert ObjectDB.slot_for(:pick_axe) == :weapon
    assert ObjectDB.slot_for(:arrow) == nil
    assert ObjectDB.slot_for(:potion_of_healing) == nil
  end
end
