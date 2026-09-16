defmodule Nexthack.ItemActionTest do
  use ExUnit.Case
  alias Nexthack.ItemAction
  alias Nexthack.Inventory
  alias Nexthack.Object
  alias Nexthack.ObjectFactory

  defp has_action?(actions, action) do
    Enum.any?(actions, fn %ItemAction{action: a} -> a == action end)
  end

  test "a potion offers quaff, dip, name, drop and throw" do
    {:ok, potion} = ObjectFactory.new(:potion_of_healing)
    acts = ItemAction.actions_for(potion)

    assert has_action?(acts, :quaff)
    assert has_action?(acts, :dip)
    assert has_action?(acts, :name_item)
    assert has_action?(acts, :drop)
    assert has_action?(acts, :throw)
    refute has_action?(acts, :read)
    refute has_action?(acts, :eat)
    refute has_action?(acts, :wield)
  end

  test "a wand offers zap and break (apply)" do
    {:ok, wand} = ObjectFactory.new(:wand_of_fire)
    acts = ItemAction.actions_for(wand)
    assert has_action?(acts, :zap)
    assert has_action?(acts, :apply)
  end

  test "a scroll offers read; a spellbook offers study" do
    {:ok, scroll} = ObjectFactory.new(:scroll_of_identify)
    acts = ItemAction.actions_for(scroll)
    assert has_action?(acts, :read)

    {:ok, book} = ObjectFactory.new(:magic_missile)
    acts = ItemAction.actions_for(book)
    assert has_action?(acts, :read)

    {:ok, novel} = ObjectFactory.new(:novel)
    acts = ItemAction.actions_for(novel)
    assert has_action?(acts, :read)
  end

  test "food offers eat" do
    {:ok, rations} = ObjectFactory.new(:rations)
    acts = ItemAction.actions_for(rations)
    assert has_action?(acts, :eat)
    refute has_action?(acts, :quaff)
  end

  test "a weapon offers wield, throw and engrave - but not wear" do
    {:ok, sword} = ObjectFactory.new(:short_sword)
    acts = ItemAction.actions_for(sword)
    assert has_action?(acts, :wield)
    assert has_action?(acts, :throw)
    assert has_action?(acts, :engrave)
    refute has_action?(acts, :wear)
  end

  test "ammo cannot be wielded but can be quivered" do
    {:ok, arrows} = ObjectFactory.new(:arrow)
    acts = ItemAction.actions_for(arrows)
    refute has_action?(acts, :wield)
    assert has_action?(acts, :quiver)
  end

  test "armor offers wear; a ring and an amulet offer put-on" do
    {:ok, mail} = ObjectFactory.new(:chain_mail)
    assert has_action?(ItemAction.actions_for(mail), :wear)

    {:ok, ring} = ObjectFactory.new(:ring_of_protection)
    assert has_action?(ItemAction.actions_for(ring), :wear)

    {:ok, amulet} = ObjectFactory.new(:amulet_of_opening)
    assert has_action?(ItemAction.actions_for(amulet), :wear)
    refute has_action?(ItemAction.actions_for(amulet), :wield)
  end

  test "a wielded weapon offers unwield, not wield again" do
    {:ok, sword} = ObjectFactory.new(:short_sword)
    acts = ItemAction.actions_for(sword, wielded: sword)
    assert has_action?(acts, :unwield)
    assert has_action?(acts, :swap_weapon)
    refute has_action?(acts, :wield)
  end

  test "a container offers tip; the amulet of Yendor offers invoke" do
    {:ok, box} = ObjectFactory.new(:large_box)
    assert has_action?(ItemAction.actions_for(box), :tip_container)

    {:ok, yendor} = ObjectFactory.new(:amulet_of_yendor)
    assert has_action?(ItemAction.actions_for(yendor), :invoke)
  end

  test "a corpse offers sacrifice only at an altar" do
    {:ok, corpse} = ObjectFactory.new(:corpse)
    assert has_action?(ItemAction.actions_for(corpse, at_altar: true), :sacrifice)
    refute has_action?(ItemAction.actions_for(corpse), :sacrifice)
  end

  defp find_apply(acts) do
    Enum.find(acts, fn
      %ItemAction{action: :apply} -> true
      _ -> false
    end)
  end

  test "apply covers the NetHack 'a' menu entries" do
    {:ok, coin} = ObjectFactory.new(:gold_piece)
    coin_apply = find_apply(ItemAction.actions_for(coin))
    assert coin_apply.text == "Flip a coin"

    {:ok, whistle} = ObjectFactory.new(:magic_whistle)
    whistle_apply = find_apply(ItemAction.actions_for(whistle))
    assert whistle_apply.text == "Blow this whistle"

    {:ok, pick} = ObjectFactory.new(:pick_axe)
    pick_apply = find_apply(ItemAction.actions_for(pick))
    assert pick_apply.text == "Dig with this digging tool"

    # an unknown bag of tricks can only be opened
    {:ok, tricks} = ObjectFactory.new(:bag_of_tricks)
    tricks_apply = find_apply(ItemAction.actions_for(tricks))
    assert tricks_apply.text == "Open this container"

    # a known bag of tricks can be reached into
    Object.identify(tricks)
    Process.sleep(20)
    tricks_apply = find_apply(ItemAction.actions_for(tricks))
    assert tricks_apply.text == "Reach into this bag"
  end

  test "execute: drop removes the item from the pack" do
    {:ok, inv} = Inventory.start_link(self(), carrier_id: "hero")
    {:ok, dagger} = ObjectFactory.new(:dagger)
    Inventory.add_item(inv, dagger)

    assert {:ok, msg} = ItemAction.execute(inv, ?a, :drop, pos: {3, 3})
    assert msg =~ "drop"
    Process.sleep(20)
    assert Inventory.count(inv) == 0
    assert Object.state(dagger).where == :floor
    assert Object.state(dagger).pos == {3, 3}
  end

  test "execute: quaff consumes the potion" do
    {:ok, inv} = Inventory.start_link(self(), carrier_id: "hero")
    {:ok, potion} = ObjectFactory.new(:potion_of_healing)
    Inventory.add_item(inv, potion)

    assert {:ok, _msg} = ItemAction.execute(inv, ?a, :quaff)
    Process.sleep(20)
    assert Object.alive?(potion) == false
    assert Inventory.count(inv) == 0
  end

  test "execute: eat consumes the food" do
    {:ok, inv} = Inventory.start_link(self(), carrier_id: "hero")
    {:ok, rations} = ObjectFactory.new(:rations)
    Inventory.add_item(inv, rations)

    assert {:ok, _msg} = ItemAction.execute(inv, ?a, :eat)
    Process.sleep(20)
    assert Object.alive?(rations) == false
  end

  test "execute: read consumes the scroll" do
    {:ok, inv} = Inventory.start_link(self(), carrier_id: "hero")
    {:ok, scroll} = ObjectFactory.new(:scroll_of_light)
    Inventory.add_item(inv, scroll)

    assert {:ok, _msg} = ItemAction.execute(inv, ?a, :read)
    Process.sleep(20)
    assert Object.alive?(scroll) == false
  end

  test "execute: wield equips in the weapon slot" do
    {:ok, inv} = Inventory.start_link(self(), carrier_id: "hero")
    {:ok, sword} = ObjectFactory.new(:short_sword)
    Inventory.add_item(inv, sword)

    assert {:ok, _msg} = ItemAction.execute(inv, ?a, :wield)
    Process.sleep(20)
    assert Inventory.worn_at(inv, :weapon) == sword
    assert Object.worn_slots(sword) == [:weapon]
  end

  test "execute: wear equips armor in the right slot" do
    {:ok, inv} = Inventory.start_link(self(), carrier_id: "hero")
    {:ok, helm} = ObjectFactory.new(:elven_leather_helm)
    Inventory.add_item(inv, helm)

    assert {:ok, _msg} = ItemAction.execute(inv, ?a, :wear)
    Process.sleep(20)
    assert Inventory.worn_at(inv, :helmet) == helm
  end

  test "execute: unknown item or unimplemented action" do
    {:ok, inv} = Inventory.start_link(self(), carrier_id: "hero")
    assert {:error, :not_in_inventory} = ItemAction.execute(inv, ?z, :drop)

    {:ok, wand} = ObjectFactory.new(:wand_of_fire)
    Inventory.add_item(inv, wand)
    assert {:not_implemented, _text} = ItemAction.execute(inv, ?a, :zap)
  end
end
