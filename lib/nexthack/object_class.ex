defmodule Nexthack.ObjectClass do
  @moduledoc """
  Object classes, the Elixir counterpart of NetHack's `enum obj_class_types`
  (see `include/objclass.h` and the OBJCLASS entries in `include/defsym.h`).

  Every item has a class. The class determines the map glyph the item is
  drawn with and how the inventory groups and sorts items. The values
  below mirror the C enum (1 = illegal, 2 = weapon, ..., 17 = venom).

  This module also carries the other small enums that objects rely on:
  `obj_material_types`, `obj_armor_types` and the default inventory
  sort order used by `loot_classify()` in `invent.c`.
  """

  # {enum value, class atom, default map glyph, human readable name}
  @classes [
    {1, :illegal, ?], "illegal objects"},
    {2, :weapon, ?), "weapons"},
    {3, :armor, ?[, "armor"},
    {4, :ring, ?=, "rings"},
    {5, :amulet, ?", "amulets"},
    {6, :tool, ?(, "tools"},
    {7, :food, ?%, "food"},
    {8, :potion, ?!, "potions"},
    {9, :scroll, ??, "scrolls"},
    {10, :spellbook, ?+, "spellbooks"},
    {11, :wand, ?/, "wands"},
    {12, :coin, ?$, "coins"},
    {13, :gem, ?*, "rocks"},
    {14, :rock, ?`, "large stones"},
    {15, :ball, ?0, "iron balls"},
    {16, :chain, ?_, "chains"},
    {17, :venom, ?., "venoms"}
  ]

  # enum obj_material_types from include/objclass.h
  @materials [
    :no_material, :liquid, :wax, :vegy, :flesh, :paper, :cloth,
    :leather, :wood, :bone, :dragon_hide, :iron, :metal, :copper,
    :silver, :gold, :platinum, :mithril, :plastic, :glass,
    :gemstone, :mineral
  ]

  # enum obj_armor_types from include/objclass.h
  @armor_categories [
    :suit, :shield, :helm, :gloves, :boots, :cloak, :shirt
  ]

  # default inventory sort order (def_srt_order) from loot_classify()
  # in invent.c
  @sort_order [
    :coin, :amulet, :ring, :wand, :potion, :scroll, :spellbook,
    :gem, :food, :tool, :weapon, :armor, :rock, :ball, :chain
  ]

  @doc "All object class atoms."
  def all do
    for {_, class, _, _} <- @classes, do: class
  end

  @doc "Is `oclass` a known object class?"
  def valid?(oclass) do
    oclass in all()
  end

  @doc "The enum value of an object class (2..17), or nil."
  def value(oclass) do
    case Enum.find(@classes, fn {_, c, _, _} -> c == oclass end) do
      {v, _, _, _} -> v
      nil -> nil
    end
  end

  @doc "The default map glyph (integer character) of an object class."
  def symbol(oclass) do
    case Enum.find(@classes, fn {_, c, _, _} -> c == oclass end) do
      {_, _, sym, _} -> sym
      nil -> nil
    end
  end

  @doc "Human readable name of an object class."
  def name(oclass) do
    case Enum.find(@classes, fn {_, c, _, _} -> c == oclass end) do
      {_, _, _, n} -> n
      nil -> "unknown"
    end
  end

  @doc "All object materials (obj_material_types)."
  def materials, do: @materials

  @doc "All armor categories (obj_armor_types)."
  def armor_categories, do: @armor_categories

  @doc """
  Default inventory sort order, the same as `def_srt_order` in
  `loot_classify()` (invent.c): coins first, amulets next (one of
  them might be The Amulet), and so on.
  """
  def sort_order, do: @sort_order
end
