defmodule Nexthack.ItemAction do
  @moduledoc """
  Item actions, converted from NetHack's `iactions.c`.

  In NetHack, running item actions on an object (`itemactions()`)
  builds a menu of everything the hero could do with it -- drop it,
  drink it, wield it, invoke it... -- each entry carrying a letter,
  an `IA_*` action id and a human readable line, and the chosen
  entry is queued as a command (`itemactions_pushkeys()`).

  This module provides the same catalog as data:

      actions_for(item_pid, ctx) -> [%Action{letter, action, text}]

  where `ctx` carries the situation-dependent facts (which weapon is
  wielded, whether we stand at an altar, ...). `execute/4` is a
  skeleton dispatcher that performs the actions the item system
  already supports (drop, quaff, eat, read, wield, wear, take off,
  tip, rename, ...) and reports the rest as not implemented yet.
  """

  alias Nexthack.Object
  alias Nexthack.ObjectDB
  alias Nexthack.Inventory

  # the IA_* enum from iactions.c
  @actions [
    :unwield, :apply, :dip, :name_item, :name_type, :drop, :eat,
    :engrave, :fire, :adjust, :adjust_stack, :sacrifice, :buy,
    :quaff, :quiver, :read, :rub, :throw, :takeoff, :tip_container,
    :invoke, :wield, :wear, :swap_weapon, :twoweapon, :zap, :whatis
  ]

  defstruct [:letter, :action, :text]

  @doc "All known item actions (the IA_* enum)."
  def actions, do: @actions

  @doc """
  The actions available for `item_pid` (a %Nexthack.Object{} pid),
  given the context. Mirrors the menu building of `itemactions()`.

  Context keys (all optional):
      wielded:      pid of the wielded weapon (uwep)
      swap_weapon:  pid of the readied alternate weapon (uswapwep)
      quiver:       pid of the readied ammo (uquiver)
      at_altar:     boolean, hero stands at an altar
      in_shop:      boolean, hero is inside a shop
      unpaid:       boolean, the item is unpaid shop stock
      name:         name to use for :name_item
  """
  def actions_for(item_pid, ctx \\ %{}) do
    item = Object.state(item_pid)
    def_ = ObjectDB.get(item.otype)
    apply_txt = apply_text(item, def_)

    [
      opt(:unwield, "Unwield this item", unwieldable?(item_pid, ctx)),
      opt(:apply, apply_txt, is_binary(apply_txt)),
      opt(:dip, dip_text(item), item.oclass == :potion),
      opt(:name_item, name_item_text(item), true),
      opt(:name_type, "Call this type", true),
      opt(:drop, drop_text(item), droppable?(item)),
      opt(:eat, "Eat this", edible?(item, def_)),
      opt(:engrave, engrave_text(item, def_), engravelable?(item, def_)),
      opt(:fire, "Fire this with your readied ammo", fireable?(item_pid, ctx)),
      opt(:adjust, "Adjust inventory by assigning new letter", adjustable?(def_)),
      opt(:adjust_stack, "Adjust inventory by splitting this stack",
        item.quantity > 1 and def_.oclass != :coin),
      opt(:sacrifice, "Offer this as a sacrifice at this altar",
        sacrificeable?(item, ctx)),
      opt(:buy, "Buy this unpaid item", buyable?(ctx)),
      opt(:quaff, "Quaff (drink) this potion", item.oclass == :potion),
      opt(:quiver, "Quiver this for easy throwing or shooting",
        quiverable?(def_)),
      opt(:read, read_text(item), readable?(item)),
      opt(:rub, rub_text(item), rubbable?(item)),
      opt(:throw, throw_text(item), droppable?(item)),
      opt(:takeoff, "Take off this item", worn?(item)),
      opt(:tip_container, "Tip all the contents out of this container",
        tipable?(item, def_)),
      opt(:invoke, "Try to invoke a unique power of this object",
        invocable?(item, def_)),
      opt(:wield, "Wield this as your weapon",
        wieldable?(item, def_) and ctx[:wielded] != item_pid),
      opt(:wear, wear_text(item, def_), wearable?(item, def_) or accessory?(item)),
      opt(:swap_weapon, swap_weapon_text(item_pid, ctx),
        item_pid in [ctx[:wielded], ctx[:swap_weapon]] and
          not is_nil(ctx[:wielded]) and not is_nil(ctx[:swap_weapon])),
      opt(:twoweapon, "Toggle two-weapon combat", twoweapon_ok?(item_pid, ctx)),
      opt(:zap, "Zap this wand to release its magic", def_.oclass == :wand),
      opt(:whatis, "Look up information about this", true)
    ]
    |> Enum.filter(fn a -> a != nil end)
  end

  @doc """
  Skeleton dispatcher (the other half of iactions.c): perform
  `action` on the item at letter `invlet` of inventory `inv`.

  Returns `{:ok, message}`, `{:error, reason}` or
  `{:not_implemented, explanation}`.
  """
  def execute(inv, invlet, action, ctx \\ %{}) do
    case List.keyfind(Inventory.items(inv), invlet, 0) do
      {^invlet, item} -> run(inv, invlet, item, action, ctx)
      nil -> {:error, :not_in_inventory}
    end
  end

  # -------------------------------------------------------------- execution

  defp run(inv, invlet, item, :drop, ctx) do
    pos = ctx[:pos] || {0, 0}

    case Inventory.drop(inv, [invlet], pos) do
      {:ok, [_l, _i]} -> {:ok, "You drop #{Object.describe(Object.state(item))}."}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run(inv, invlet, item, :quaff, _ctx),
    do: useup(inv, invlet, item, "You quaff the potion.")

  defp run(inv, invlet, item, :eat, _ctx),
    do: useup(inv, invlet, item, "You eat the food.")

  defp run(inv, invlet, item, :read, _ctx),
    do: useup(inv, invlet, item, "You read the scroll.")

  defp run(inv, _invlet, item, :wield, _ctx) do
    case Inventory.equip(inv, item, :weapon) do
      {:ok, _previous} -> {:ok, "You wield #{Object.describe(Object.state(item))}."}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run(inv, _invlet, item, :wear, _ctx) do
    slot = ObjectDB.slot_for(item.otype) || :armor

    case Inventory.equip(inv, item, slot) do
      {:ok, _previous} -> {:ok, "You wear #{Object.describe(Object.state(item))}."}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run(inv, _invlet, item, :takeoff, _ctx) do
    case Object.worn_slots(item) do
      [slot] ->
        case Inventory.unequip(inv, slot) do
          {:ok, _i} -> {:ok, "You take off the item."}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :not_worn}
    end
  end

  defp run(inv, _invlet, item, :unwield, ctx) do
    slot =
      cond do
        ctx[:wielded] == item -> :weapon
        ctx[:swap_weapon] == item -> :swap_weapon
        ctx[:quiver] == item -> :quiver
        true -> :weapon
      end

    case Inventory.unequip(inv, slot) do
      {:ok, _i} -> {:ok, "You unwield the weapon."}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run(_inv, _invlet, item, :tip_container, ctx) do
    contents = Object.tip_contents(item)
    pos = ctx[:pos] || {0, 0}

    Enum.each(contents, fn c ->
      Object.clear_holder(c)
      Object.set_where(c, :floor)
      Object.set_pos(c, pos)
    end)

    {:ok, "You tip the contents out."}
  end

  defp run(_inv, _invlet, item, :name_item, ctx) do
    name = ctx[:name]

    if is_binary(name) and name != "" do
      Object.rename(item, name)
      {:ok, "You name the item #{name}."}
    else
      Object.rename(item, nil)
      {:ok, "You forget the item's name."}
    end
  end

  defp run(_inv, _invlet, _item, :zap, _ctx),
    do: {:not_implemented, "Zap targeting is handled by the zap system."}

  defp run(_inv, _invlet, _item, :throw, _ctx),
    do: {:not_implemented, "Throwing reuses the bolt (zap) actors."}

  defp run(_inv, _invlet, _item, action, _ctx) do
    {:not_implemented, "#{inspect(action)} is not implemented yet."}
  end

  # remove from the pack, then consume one (the useup() flow)
  defp useup(inv, invlet, item, message) do
    case Inventory.remove_item(inv, invlet) do
      {:ok, _i} ->
        Object.consume(item, 1)
        {:ok, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ------------------------------------------------------------ eligibility

  defp opt(action, text, ok?) do
    if ok?, do: %__MODULE__{letter: letter_for(action), action: action, text: text}, else: nil
  end

  # the menu letters from iactions.c
  defp letter_for(:unwield), do: ?-
  defp letter_for(:apply), do: ?a
  defp letter_for(:dip), do: ?a
  defp letter_for(:name_item), do: ?c
  defp letter_for(:name_type), do: ?C
  defp letter_for(:drop), do: ?d
  defp letter_for(:eat), do: ?e
  defp letter_for(:engrave), do: ?E
  defp letter_for(:fire), do: ?f
  defp letter_for(:adjust), do: ?i
  defp letter_for(:adjust_stack), do: ?I
  defp letter_for(:sacrifice), do: ?O
  defp letter_for(:buy), do: ?p
  defp letter_for(:quaff), do: ?q
  defp letter_for(:quiver), do: ?Q
  defp letter_for(:read), do: ?r
  defp letter_for(:rub), do: ?R
  defp letter_for(:throw), do: ?t
  defp letter_for(:takeoff), do: ?T
  defp letter_for(:tip_container), do: ?T
  defp letter_for(:invoke), do: ?V
  defp letter_for(:wield), do: ?w
  defp letter_for(:wear), do: ?W
  defp letter_for(:swap_weapon), do: ?x
  defp letter_for(:twoweapon), do: ?X
  defp letter_for(:zap), do: ?z
  defp letter_for(:whatis), do: ?/

  # --- per-action predicates (the if-chain of itemactions()) ---------------

  defp unwieldable?(item_pid, ctx) do
    ctx[:wielded] == item_pid or ctx[:swap_weapon] == item_pid or ctx[:quiver] == item_pid
  end

  # the big 'a: apply' case from itemactions()
  defp apply_text(item, def_) do
    cond do
      item.oclass == :coin -> "Flip a coin"
      item.otype == :cream_pie -> "Hit yourself with this cream pie"
      item.otype == :bullwhip -> "Lash out with this whip"
      item.otype == :grappling_hook -> "Grapple something with this hook"
      item.otype == :bag_of_tricks and item.known -> "Reach into this bag"
      def_.container -> "Open this container"
      item.otype == :can_of_grease -> "Use the can to grease an item"
      item.otype in [:lock_pick, :skeleton_key, :credit_card] -> "Use this tool to pick a lock"
      item.otype == :tinning_kit -> "Use this kit to tin a corpse"
      item.otype == :leash -> "Attach this leash to a pet"
      item.otype == :saddle -> "Place this saddle on a pet"
      item.otype in [:magic_whistle, :tin_whistle] -> "Blow this whistle"
      item.otype == :eucalyptus_leaf -> "Use this leaf as a whistle"
      item.otype == :stethoscope -> "Listen through the stethoscope"
      item.otype == :mirror -> "Show something its reflection"
      item.otype in [:bell, :bell_of_opening] -> "Ring the bell"
      item.otype in [:candelabrum_of_invocation, :tallow_candle, :wax_candle,
                     :oil_lamp, :magic_lamp, :brass_lantern, :pot_of_oil] ->
        light_text(item)

      item.oclass == :potion -> nil # potions only offer dip
      item.otype == :crystal_ball -> "Peer into this crystal ball"
      item.otype == :magic_marker -> "Write on something with this marker"
      item.otype == :figurine -> "Make this figurine transform"
      item.otype == :unicorn_horn -> "Use this unicorn horn"
      item.otype == :horn_of_plenty -> "Blow into the horn of plenty"
      musical?(item.otype) -> "Play this musical instrument"
      item.otype in [:pick_axe, :dwarfish_mattock] -> "Dig with this digging tool"
      item.oclass == :wand -> "Break this wand"
      true -> nil
    end
  end

  defp light_text(item) do
    if item.properties[:lit] do
      "Extinguish this light source"
    else
      "Light this light source"
    end
  end

  defp musical?(otype) do
    otype in [
      :wooden_flute, :magic_flute, :tooled_horn, :fire_horn,
      :wooden_harp, :magic_harp, :bugle, :leather_drum, :drum_of_earthquake
    ]
  end

  defp dip_text(item) do
    if item.quantity > 1 do
      "Dip something into one of these potions"
    else
      "Dip something into this potion"
    end
  end

  defp name_item_text(item) do
    if is_binary(item.name) and item.name != "" do
      "Rename or un-name the #{item.name}"
    else
      "Name the #{Object.base_name(item)}"
    end
  end

  defp droppable?(item), do: map_size(item.worn) == 0
  defp drop_text(item), do: if(item.quantity > 1, do: "Drop this stack", else: "Drop this item")
  defp throw_text(item), do: if(item.quantity > 1, do: "Throw one of these", else: "Throw this")

  defp edible?(item, def_), do: def_.food or item.otype == :tin

  defp engravelable?(item, def_) do
    def_.oclass in [:weapon, :wand, :gem, :ring] or
      item.otype in [:towel, :magic_marker]
  end

  defp engrave_text(item, def_) do
    cond do
      item.otype == :towel -> "Wipe the floor with this towel"
      item.otype == :magic_marker -> "Scribble graffiti on the floor"
      def_.oclass in [:gem, :ring] -> "Write on the floor with this"
      true -> "Engrave the floor with this"
    end
  end

  defp fireable?(item_pid, ctx), do: ctx[:quiver] == item_pid

  defp adjustable?(def_), do: def_.oclass != :coin

  defp sacrificeable?(item, ctx) do
    ctx[:at_altar] == true and
      item.otype in [:corpse, :amulet_of_yendor, :fake_amulet_of_yendor]
  end

  defp buyable?(ctx), do: ctx[:in_shop] == true and ctx[:unpaid] == true

  defp quiverable?(def_) do
    def_.ammo or def_.oclass == :gem
  end

  # item_reading_classification() from iactions.c
  defp readable?(item) do
    item.oclass in [:scroll, :spellbook] or
      item.otype in [:fortune_cookie, :t_shirt, :alchemys_smock, :hawaiian_shirt]
  end

  defp read_text(item) do
    case item.otype do
      :fortune_cookie -> "Read the message inside this cookie"
      :t_shirt -> "Read the slogan on the shirt"
      :alchemys_smock -> "Read the slogan on the apron"
      :hawaiian_shirt -> "Look at the pattern on the shirt"
      _ ->
        if item.oclass == :spellbook do
          case item.otype do
            :novel -> "Read this novel"
            :book_of_the_dead -> "Examine this tome"
            _ -> "Study this spellbook"
          end
        else
          "Read this scroll"
        end
    end
  end

  defp rubbable?(item) do
    item.otype in [:oil_lamp, :magic_lamp, :brass_lantern] or
      item.otype in [:loadstone, :flint, :touchstone, :luckstone]
  end

  defp rub_text(item) do
    if item.otype in [:oil_lamp, :magic_lamp, :brass_lantern] do
      "Rub this #{Object.base_name(item)}"
    else
      "Rub something on this stone"
    end
  end

  defp worn?(item), do: map_size(item.worn) > 0

  defp tipable?(item, def_) do
    (def_.container and (item.contents != [] or not item.cknown)) or
      (item.otype == :horn_of_plenty and (item.spe > 0 or not item.known))
  end

  defp invocable?(item, def_) do
    def_.unique or def_.artifact or
      item.otype in [:crystal_ball, :fake_amulet_of_yendor]
  end

  defp wieldable?(item, def_) do
    (def_.oclass == :weapon and not def_.ammo and not def_.launcher) or
      def_.weptool or
      item.otype == :iron_ball or
      (item.otype == :towel and item.spe > 0)
  end

  defp wearable?(item, def_) do
    def_.oclass == :armor and item.otype not in [:blindfold, :towel, :lenses]
  end

  defp accessory?(item) do
    item.oclass in [:ring, :amulet] or
      item.otype in [:blindfold, :towel, :lenses]
  end

  defp wear_text(item, def_) do
    if def_.oclass == :armor and item.otype not in [:blindfold, :towel, :lenses] do
      "Wear this armor"
    else
      "Put this on"
    end
  end

  defp swap_weapon_text(item_pid, ctx) do
    cond do
      ctx[:wielded] == item_pid and not is_nil(ctx[:swap_weapon]) ->
        "Swap this with your alternate weapon"

      ctx[:wielded] == item_pid ->
        "Ready this as an alternate weapon"

      ctx[:swap_weapon] == item_pid ->
        "Swap this with your main weapon"

      true ->
        "Swap weapons"
    end
  end

  # a simplified TWOWEAPOK(): both weapons readied, none of them
  # launcher/ammo/bimanual (bimanual data not carried in the skeleton)
  defp twoweapon_ok?(item_pid, ctx) do
    item_pid in [ctx[:wielded], ctx[:swap_weapon]] and
      not is_nil(ctx[:wielded]) and
      not is_nil(ctx[:swap_weapon])
  end
end
