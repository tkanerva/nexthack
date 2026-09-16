defmodule Nexthack.ObjectDB do
  @moduledoc """
  Static object database, the Elixir counterpart of NetHack's
  `objects[]` / `obj_descr[]` tables (see `include/objclass.h` and
  `dat/object.data`).

  A curated subset of NetHack's objects is included as a starting
  point: every object class is covered, plus the objects that the
  item actions in `iactions.c` specifically call out by name
  (candles, whistles, containers, gems, ...). Each entry carries the
  fields of `struct objclass` that the skeleton needs:

      name / description   ~ oc_name / oc_descr (actual name vs.
                             "potion" / "scroll" style placeholder)
      weight, cost, prob   ~ oc_weight, oc_cost, oc_prob
      charged              ~ oc_charged (wands, lamps with fuel)
      enchantable          ~ objects that may carry a +N / -N spe
      skill                ~ oc_skill / oc_armcat (weapon skill,
                             armor category, spell level for books)
      food, container, ... ~ class predicates used by iactions.c
  """

  # Entry shape:
  #   {otype, oclass, name, weight, cost, prob, flags, skill}
  #
  # flags (a list of atoms):
  #   :charged    - has charges (wands) or fuel (lamps, candles)
  #   :enchantable - may carry a +N/-N enchantment (weapons, armor, ...)
  #   :container   - has contents (boxes, bags, ...)
  #   :food        - edible
  #   :light       - a light source
  #   :ammo        - ammunition (arrows, bolts, bullets, darts)
  #   :launcher    - shoots ammo (bow, sling, crossbow)
  #   :weptool     - tool usable as a weapon (pick-axe, mattock, ...)
  #   :globby      - globs of ooze (merge with like types)
  #   :unique      - one-of-a-kind (amulet of Yendor, book of the dead)
  #   :no_merge    - never merged with other stacks
  #
  # weight is in NetHack units (1 = 0.1 lb), cost in gold pieces,
  # prob is the relative probability used by random generation
  # (the Elixir version of mkobj()).

  @objects [
    # ------------------------------------------------------------ weapons
    {:dagger, :weapon, "dagger", 4, 3, 12, [:enchantable], :dagger},
    {:knife, :weapon, "knife", 4, 2, 8, [:enchantable], :knife},
    {:short_sword, :weapon, "short sword", 10, 12, 10, [:enchantable], :short_sword},
    {:broadsword, :weapon, "broadsword", 15, 15, 8, [:enchantable], :broadsword},
    {:two_handed_sword, :weapon, "two-handed sword", 20, 25, 4, [:enchantable], :two_handed_sword},
    {:mace, :weapon, "mace", 16, 12, 10, [:enchantable], :mace},
    {:war_hammer, :weapon, "war hammer", 20, 15, 8, [:enchantable], :war_hammer},
    {:battle_axe, :weapon, "battle axe", 16, 15, 8, [:enchantable], :battle_axe},
    {:halberd, :weapon, "halberd", 20, 30, 4, [:enchantable], :halberd},
    {:spear, :weapon, "spear", 10, 10, 6, [:enchantable], :spear},
    {:trident, :weapon, "trident", 20, 20, 5, [:enchantable], :trident},
    {:arrow, :weapon, "arrow", 1, 1, 15, [:ammo], :arrow},
    {:elf_arrow, :weapon, "elf-arrow", 1, 1, 5, [:ammo], :arrow},
    {:bolt, :weapon, "bolt", 1, 2, 6, [:ammo], :bolt},
    {:sling_bullet, :weapon, "sling bullet", 1, 1, 8, [:ammo], :sling_bullet},
    {:dart, :weapon, "dart", 1, 1, 6, [:ammo], :dart},
    {:boomerang, :weapon, "boomerang", 4, 5, 2, [], :boomerang},
    {:bow, :weapon, "bow", 20, 30, 4, [:launcher], :bow},
    {:long_bow, :weapon, "long bow", 20, 35, 3, [:launcher], :bow},
    {:crossbow, :weapon, "crossbow", 40, 50, 2, [:launcher], :crossbow},
    {:sling, :weapon, "sling", 4, 2, 4, [:launcher], :sling},

    # ------------------------------------------------------------ armor
    {:leather_armor, :armor, "leather armor", 30, 15, 10, [:enchantable], :suit},
    {:studded_leather, :armor, "studded leather", 40, 25, 8, [:enchantable], :suit},
    {:ring_mail, :armor, "ring mail", 60, 75, 6, [:enchantable], :suit},
    {:chain_mail, :armor, "chain mail", 60, 100, 6, [:enchantable], :suit},
    {:scale_mail, :armor, "scale mail", 70, 200, 4, [:enchantable], :suit},
    {:plate_mail, :armor, "plate mail", 90, 300, 3, [:enchantable], :suit},
    {:elven_leather_helm, :armor, "elven leather helm", 10, 30, 3, [:enchantable], :helm},
    {:elven_mithril_coat, :armor, "elven mithril-coat", 40, 400, 2, [:enchantable], :suit},
    {:elven_cloak, :armor, "elven cloak", 20, 100, 2, [:enchantable], :cloak},
    {:elven_shield, :armor, "elven shield", 25, 200, 2, [:enchantable], :shield},
    {:elven_boots, :armor, "elven boots", 15, 250, 2, [:enchantable], :boots},
    {:orcish_helm, :armor, "orcish helm", 10, 25, 3, [:enchantable], :helm},
    {:orcish_chain_mail, :armor, "orcish chain mail", 60, 120, 2, [:enchantable], :suit},
    {:orcish_ring_mail, :armor, "orcish ring mail", 60, 90, 3, [:enchantable], :suit},
    {:orcish_cloak, :armor, "orcish cloak", 20, 80, 2, [:enchantable], :cloak},
    {:orcish_shield, :armor, "orcish shield", 25, 150, 2, [:enchantable], :shield},
    {:dwarfish_iron_helm, :armor, "dwarvish iron helm", 10, 40, 2, [:enchantable], :helm},
    {:dwarfish_mithril_coat, :armor, "dwarvish mithril-coat", 40, 500, 1, [:enchantable], :suit},
    {:dwarfish_cloak, :armor, "dwarvish cloak", 20, 120, 2, [:enchantable], :cloak},
    {:dwarfish_roundshield, :armor, "dwarvish round shield", 25, 180, 2, [:enchantable], :shield},
    {:t_shirt, :armor, "T-shirt", 10, 5, 3, [], :shirt},
    {:alchemys_smock, :armor, "alchemy smock", 10, 5, 2, [], :shirt},
    {:hawaiian_shirt, :armor, "Hawaiian shirt", 10, 25, 2, [], :shirt},
    {:blindfold, :armor, "blindfold", 2, 1, 1, [], :blindfold},
    {:towel, :armor, "towel", 15, 2, 2, [], :towel},
    {:lenses, :armor, "lenses", 2, 25, 1, [], :lenses},

    # ------------------------------------------------------------ rings
    {:ring_of_extra_vision, :ring, "ring of extra vision", 3, 50, 2, [], :ring},
    {:ring_of_protection, :ring, "ring of protection", 3, 100, 3, [], :ring},
    {:ring_of_regeneration, :ring, "ring of regeneration", 3, 150, 3, [], :ring},
    {:ring_of_slow_regeneration, :ring, "ring of slow regeneration", 3, 75, 2, [], :ring},
    {:ring_of_invisibility, :ring, "ring of invisibility", 3, 200, 2, [], :ring},
    {:ring_of_searching, :ring, "ring of searching", 3, 120, 2, [], :ring},
    {:ring_of_detect_magic, :ring, "ring of detect magic", 3, 150, 2, [], :ring},
    {:ring_of_teleportation, :ring, "ring of teleportation", 3, 250, 2, [], :ring},
    {:ring_of_free_action, :ring, "ring of free action", 3, 250, 2, [], :ring},
    {:ring_of_stealth, :ring, "ring of stealth", 3, 300, 1, [], :ring},
    {:ring_of_enlightenment, :ring, "ring of enlightenment", 3, 100, 1, [], :ring},
    {:ring_of_amulet, :ring, "ring of amulet", 3, 500, 1, [], :ring},
    {:meat_ring, :ring, "ring of meat", 3, 5, 2, [], :ring},

    # ------------------------------------------------------------ amulets
    {:amulet_of_yendor, :amulet, "amulet of Yendor", 5, 100_000, 0, [:unique, :no_merge], nil},
    {:fake_amulet_of_yendor, :amulet, "amulet of Yendor", 5, 5000, 1, [:no_merge], nil},
    {:amulet_of_opening, :amulet, "amulet of opening", 5, 500, 1, [], nil},
    {:amulet_of_darkness, :amulet, "amulet of darkness", 5, 150, 2, [], nil},
    {:amulet_of_mirroring, :amulet, "amulet of mirroring", 5, 500, 1, [], nil},

    # ------------------------------------------------------------ tools
    {:oil_lamp, :tool, "oil lamp", 10, 5, 3, [:light, :charged], nil},
    {:magic_lamp, :tool, "magic lamp", 15, 1000, 1, [:light, :charged], nil},
    {:brass_lantern, :tool, "brass lantern", 15, 20, 2, [:light, :charged], nil},
    {:candelabrum_of_invocation, :tool, "candelabrum of invocation", 15, 1000, 1, [:light, :charged], nil},
    {:tallow_candle, :tool, "tallow candle", 2, 1, 4, [:light, :charged], nil},
    {:wax_candle, :tool, "wax candle", 2, 1, 4, [:light, :charged], nil},
    {:pot_of_oil, :tool, "pot of oil", 15, 1, 2, [:light], nil},
    {:pick_axe, :tool, "pick-axe", 16, 25, 3, [:weptool], :pick_axe},
    {:dwarfish_mattock, :tool, "dwarvish mattock", 16, 40, 2, [:weptool], :pick_axe},
    {:bowie_knife, :tool, "bowie knife", 8, 10, 2, [:weptool], :knife},
    {:trowel, :tool, "trowel", 4, 5, 2, [:weptool], :trowel},
    {:leash, :tool, "leash", 2, 10, 1, [], nil},
    {:saddle, :tool, "saddle", 20, 50, 1, [], nil},
    {:rope, :tool, "rope", 50, 10, 2, [], nil},
    {:can_of_grease, :tool, "can of grease", 10, 20, 1, [], nil},
    {:tinning_kit, :tool, "tinning kit", 5, 30, 1, [], nil},
    {:stethoscope, :tool, "stethoscope", 5, 25, 1, [], nil},
    {:crystal_ball, :tool, "crystal ball", 20, 1000, 1, [], nil},
    {:magic_marker, :tool, "magic marker", 2, 50, 1, [], nil},
    {:bell, :tool, "bell", 10, 20, 1, [], nil},
    {:bell_of_opening, :tool, "bell of opening", 10, 500, 1, [], nil},
    {:magic_whistle, :tool, "magic whistle", 2, 500, 1, [], nil},
    {:tin_whistle, :tool, "tin whistle", 2, 5, 2, [], nil},
    {:eucalyptus_leaf, :tool, "eucalyptus leaf", 1, 1, 2, [], nil},
    {:mirror, :tool, "mirror", 10, 20, 2, [], nil},
    {:large_box, :tool, "large box", 20, 10, 3, [:container], nil},
    {:chest, :tool, "chest", 25, 20, 3, [:container], nil},
    {:oilskin_sack, :tool, "oilskin sack", 2, 2, 2, [:container], nil},
    {:ice_box, :tool, "ice box", 25, 15, 1, [:container], nil},
    {:bag_of_holding, :tool, "bag of holding", 2, 200, 1, [:container], nil},
    {:bag_of_tricks, :tool, "bag of tricks", 2, 1000, 1, [:container], nil},
    {:satchel, :tool, "satchel", 2, 5, 3, [:container], nil},
    {:small_box, :tool, "small box", 10, 5, 2, [:container], nil},
    {:lock_pick, :tool, "lock pick", 1, 10, 2, [], nil},
    {:skeleton_key, :tool, "skeleton key", 1, 10, 2, [], nil},
    {:credit_card, :tool, "credit card", 1, 5, 1, [], nil},
    {:horn_of_plenty, :tool, "horn of plenty", 10, 2000, 1, [:container, :charged], nil},
    {:wooden_flute, :tool, "wooden flute", 2, 5, 2, [], nil},
    {:magic_flute, :tool, "magic flute", 2, 100, 1, [], nil},
    {:tooled_horn, :tool, "tooled horn", 5, 20, 1, [], nil},
    {:fire_horn, :tool, "fire horn", 5, 500, 1, [], nil},
    {:wooden_harp, :tool, "wooden harp", 10, 5, 2, [], nil},
    {:magic_harp, :tool, "magic harp", 10, 100, 1, [], nil},
    {:bugle, :tool, "bugle", 5, 20, 1, [], nil},
    {:leather_drum, :tool, "leather drum", 5, 5, 1, [], nil},
    {:drum_of_earthquake, :tool, "drum of earthquake", 5, 1000, 1, [], nil},
    {:bullwhip, :tool, "bullwhip", 15, 25, 1, [], nil},
    {:grappling_hook, :tool, "grappling hook", 10, 10, 1, [], nil},
    {:figurine, :tool, "figurine", 15, 50, 1, [], nil},

    # ------------------------------------------------------------ food
    {:rations, :food, "rations", 20, 1, 10, [:food], nil},
    {:huge_trout, :food, "huge trout", 10, 5, 8, [:food], nil},
    {:slime_mold, :food, "slime mold", 10, 1, 6, [:food], nil},
    {:spinach, :food, "spinach", 5, 1, 6, [:food], nil},
    {:egg, :food, "egg", 2, 2, 6, [:food], nil},
    {:tin, :food, "tin", 15, 10, 6, [:food], nil},
    {:corpse, :food, "corpse", 50, 5, 8, [:food], nil},
    {:glob_of_gray_ooze, :food, "glob of gray ooze", 100, 1, 2, [:food, :globby], nil},
    {:glob_of_brown_pudding, :food, "glob of brown pudding", 100, 1, 2, [:food, :globby], nil},
    {:glob_of_green_slime, :food, "glob of green slime", 100, 1, 2, [:food, :globby], nil},
    {:glob_of_black_pudding, :food, "glob of black pudding", 100, 1, 1, [:food, :globby], nil},
    {:fortune_cookie, :food, "fortune cookie", 2, 10, 2, [:food], nil},
    {:apple, :food, "apple", 5, 2, 8, [:food], nil},
    {:pear, :food, "pear", 5, 2, 8, [:food], nil},
    {:lemon, :food, "lemon", 5, 2, 8, [:food], nil},
    {:orange, :food, "orange", 5, 2, 8, [:food], nil},
    {:plum, :food, "plum", 5, 2, 8, [:food], nil},
    {:kiwi, :food, "kiwi", 5, 2, 8, [:food], nil},
    {:cantaloupe, :food, "cantaloupe", 50, 1, 4, [:food], nil},
    {:watermelon, :food, "watermelon", 80, 1, 4, [:food], nil},
    {:banana, :food, "banana", 5, 2, 8, [:food], nil},
    {:cherries, :food, "cherries", 5, 2, 8, [:food], nil},
    {:grapefruit, :food, "grapefruit", 10, 1, 4, [:food], nil},
    {:grape, :food, "grape", 5, 2, 8, [:food], nil},
    {:strawberry, :food, "strawberry", 2, 2, 8, [:food], nil},
    {:peach, :food, "peach", 5, 2, 8, [:food], nil},
    {:quince, :food, "quince", 5, 2, 8, [:food], nil},
    {:papaya, :food, "papaya", 10, 1, 4, [:food], nil},
    {:honeydew_melon, :food, "honeydew melon", 40, 1, 4, [:food], nil},
    {:cream_pie, :food, "cream pie", 10, 5, 3, [:food], nil},
    {:cigarette, :food, "cigarette", 1, 2, 2, [:food], nil},
    {:candy_bar, :food, "candy bar", 3, 5, 3, [:food], nil},

    # ------------------------------------------------------------ potions
    {:potion_of_healing, :potion, "potion of healing", 3, 5, 10, [], nil},
    {:potion_of_extra_healing, :potion, "potion of extra healing", 3, 15, 6, [], nil},
    {:potion_of_see_invisible, :potion, "potion of see invisible", 3, 25, 6, [], nil},
    {:potion_of_restore_abilities, :potion, "potion of restore abilities", 3, 50, 4, [], nil},
    {:potion_of_gain_energy, :potion, "potion of gain energy", 3, 75, 4, [], nil},
    {:potion_of_polymorph, :potion, "potion of polymorph", 3, 50, 6, [], nil},
    {:potion_of_sleep, :potion, "potion of sleep", 3, 25, 5, [], nil},
    {:potion_of_teleport, :potion, "potion of teleport", 3, 25, 5, [], nil},
    {:potion_of_oil, :potion, "potion of oil", 3, 1, 4, [], nil},
    {:potion_of_water, :potion, "potion of water", 3, 1, 8, [], nil},
    {:potion_of_holy_water, :potion, "potion of holy water", 3, 10, 4, [], nil},
    {:potion_of_unholy_water, :potion, "potion of unholy water", 3, 10, 4, [], nil},
    {:potion_of_neutralize_poison, :potion, "potion of neutralize poison", 3, 5, 4, [], nil},
    {:potion_of_gain_strength, :potion, "potion of gain strength", 3, 100, 2, [], nil},
    {:potion_of_gain_dexterity, :potion, "potion of gain dexterity", 3, 100, 2, [], nil},
    {:potion_of_gain_constitution, :potion, "potion of gain constitution", 3, 100, 2, [], nil},
    {:potion_of_invisibility, :potion, "potion of invisibility", 3, 100, 3, [], nil},
    {:potion_of_level_drain, :potion, "potion of level drain", 3, 50, 2, [], nil},
    {:potion_of_sickness, :potion, "potion of sickness", 3, 25, 4, [], nil},
    {:potion_of_confusion, :potion, "potion of confusion", 3, 50, 3, [], nil},
    {:potion_of_amnesia, :potion, "potion of amnesia", 3, 25, 4, [], nil},
    {:potion_of_poison, :potion, "potion of poison", 3, 25, 3, [], nil},
    {:potion_of_liquidation, :potion, "potion of liquidation", 3, 100, 2, [], nil},
    {:potion_of_restore_stats, :potion, "potion of restore stats", 3, 50, 3, [], nil},
    {:potion_of_extra_food, :potion, "potion of extra food", 3, 5, 5, [], nil},
    {:potion_of_raise_dead, :potion, "potion of raise dead", 3, 2000, 1, [], nil},
    {:potion_of_mind_blindness, :potion, "potion of mind blindness", 3, 100, 2, [], nil},

    # ------------------------------------------------------------ scrolls
    {:scroll_of_message, :scroll, "scroll of message", 1, 5, 6, [], nil},
    {:scroll_of_magic_mapping, :scroll, "scroll of magic mapping", 1, 25, 6, [], nil},
    {:scroll_of_teleport, :scroll, "scroll of teleport", 1, 25, 5, [], nil},
    {:scroll_of_teleport_control, :scroll, "scroll of teleport control", 1, 50, 3, [], nil},
    {:scroll_of_enchant_weapon, :scroll, "scroll of enchant weapon", 1, 50, 4, [], nil},
    {:scroll_of_identify, :scroll, "scroll of identify", 1, 15, 8, [], nil},
    {:scroll_of_enchant_armor, :scroll, "scroll of enchant armor", 1, 50, 3, [], nil},
    {:scroll_of_remove_curse, :scroll, "scroll of remove curse", 1, 50, 4, [], nil},
    {:scroll_of_protection, :scroll, "scroll of protection", 1, 50, 4, [], nil},
    {:scroll_of_nameless, :scroll, "scroll of nameless", 1, 50, 3, [], nil},
    {:scroll_of_detect_monsters, :scroll, "scroll of detect monsters", 1, 25, 4, [], nil},
    {:scroll_of_detect_invisible, :scroll, "scroll of detect invisible creature", 1, 50, 3, [], nil},
    {:scroll_of_detect_treasure, :scroll, "scroll of detect treasure", 1, 25, 4, [], nil},
    {:scroll_of_detect_unseen, :scroll, "scroll of detect unseen", 1, 25, 3, [], nil},
    {:scroll_of_detect_undead, :scroll, "scroll of detect undead", 1, 50, 3, [], nil},
    {:scroll_of_scare_monster, :scroll, "scroll of scare monster", 1, 100, 2, [], nil},
    {:scroll_of_light, :scroll, "scroll of light", 1, 50, 3, [], nil},
    {:scroll_of_blank_paper, :scroll, "blank paper", 1, 1, 3, [], nil},

    # ------------------------------------------------------------ spell books
    # (the otype is the spell itself, as in NetHack's SPE_* enum)
    {:spell_book, :spellbook, "spellbook", 3, 10, 10, [], 1},
    {:blank_paper, :spellbook, "blank paper", 1, 1, 4, [], 0},
    {:sleep, :spellbook, "sleep", 3, 25, 3, [], 1},
    {:magic_missile, :spellbook, "magic missile", 3, 25, 4, [], 1},
    {:cure, :spellbook, "cure", 3, 25, 3, [], 2},
    {:cure_serious_wounds, :spellbook, "cure serious wounds", 3, 50, 3, [], 3},
    {:cure_critical_wounds, :spellbook, "cure critical wounds", 3, 75, 3, [], 4},
    {:healing, :spellbook, "healing", 3, 75, 3, [], 4},
    {:extra_healing, :spellbook, "extra healing", 3, 100, 2, [], 5},
    {:light, :spellbook, "light", 3, 25, 4, [], 1},
    {:lightning_bolt, :spellbook, "lightning bolt", 3, 75, 3, [], 3},
    {:chain_lightning, :spellbook, "chain lightning", 3, 200, 1, [], 5},
    {:knock, :spellbook, "knock", 3, 75, 2, [], 3},
    {:search, :spellbook, "search", 3, 25, 3, [], 1},
    {:teleport, :spellbook, "teleport", 3, 75, 3, [], 3},
    {:polymorph, :spellbook, "polymorph", 3, 100, 3, [], 4},
    {:force_bolt, :spellbook, "force bolt", 3, 50, 3, [], 2},
    {:extra_food, :spellbook, "extra food", 3, 25, 3, [], 1},
    {:protection, :spellbook, "protection", 3, 75, 3, [], 3},
    {:slow_monster, :spellbook, "slow monster", 3, 100, 2, [], 4},
    {:telepathy, :spellbook, "telepathy", 3, 75, 2, [], 3},
    {:fear, :spellbook, "fear", 3, 100, 2, [], 4},
    {:stone_to_flesh, :spellbook, "stone to flesh", 3, 200, 1, [], 5},
    {:fireball, :spellbook, "fireball", 3, 150, 2, [], 4},
    {:dragon_breath, :spellbook, "dragon breath", 3, 400, 1, [], 5},
    {:meteor_shower, :spellbook, "meteor shower", 3, 500, 1, [], 5},
    {:word_of_recall, :spellbook, "word of recall", 3, 1000, 1, [], 5},
    {:word_of_death, :spellbook, "word of death", 3, 2000, 1, [], 5},
    {:novel, :spellbook, "novel", 5, 10, 2, [], 0},
    {:book_of_the_dead, :spellbook, "book of the dead", 15, 10_000, 1, [:unique, :no_merge], 5},

    # ------------------------------------------------------------ wands
    {:wand_of_fire, :wand, "wand of fire", 2, 50, 8, [:charged], nil},
    {:wand_of_lightning, :wand, "wand of lightning", 2, 75, 6, [:charged], nil},
    {:wand_of_cold, :wand, "wand of cold", 2, 75, 6, [:charged], nil},
    {:wand_of_sleep, :wand, "wand of sleep", 2, 25, 6, [:charged], nil},
    {:wand_of_teleport, :wand, "wand of teleport", 2, 50, 5, [:charged], nil},
    {:wand_of_teleport_control, :wand, "wand of teleport control", 2, 100, 4, [:charged], nil},
    {:wand_of_paralyzation, :wand, "wand of paralyzation", 2, 100, 4, [:charged], nil},
    {:wand_of_magic_mapping, :wand, "wand of magic mapping", 2, 50, 5, [:charged], nil},
    {:wand_of_enchantment, :wand, "wand of enchantment", 2, 100, 3, [:charged], nil},
    {:wand_of_creation, :wand, "wand of creation", 2, 100, 3, [:charged], nil},
    {:wand_of_destruction, :wand, "wand of destruction", 2, 200, 2, [:charged], nil},
    {:wand_of_light, :wand, "wand of light", 2, 100, 3, [:charged], nil},
    {:wand_of_death_ray, :wand, "wand of death ray", 2, 400, 1, [:charged], nil},
    {:wand_of_force_bolt, :wand, "wand of force bolt", 2, 75, 3, [:charged], nil},
    {:wand_of_random, :wand, "wand of random", 2, 100, 2, [:charged], nil},
    {:wand_of_polymorph, :wand, "wand of polymorph", 2, 100, 3, [:charged], nil},
    {:wand_of_digging, :wand, "wand of digging", 2, 100, 3, [:charged], nil},
    {:wand_of_cancellation, :wand, "wand of cancellation", 2, 500, 1, [:charged], nil},
    {:wand_of_opening, :wand, "wand of opening", 2, 500, 2, [:charged], nil},
    {:wand_of_locking, :wand, "wand of locking", 2, 500, 2, [:charged], nil},
    {:wand_of_probing, :wand, "wand of probing", 2, 200, 2, [:charged], nil},
    {:wand_of_speed, :wand, "wand of speed", 2, 250, 2, [:charged], nil},
    {:wand_of_slow, :wand, "wand of slow", 2, 250, 2, [:charged], nil},
    {:wand_of_mind_reading, :wand, "wand of mind reading", 2, 500, 1, [:charged], nil},

    # ------------------------------------------------------------ gems & stones
    {:diamond, :gem, "diamond", 1, 2500, 2, [], nil},
    {:ruby, :gem, "ruby", 1, 500, 4, [], nil},
    {:sapphire, :gem, "sapphire", 1, 250, 4, [], nil},
    {:emerald, :gem, "emerald", 1, 150, 4, [], nil},
    {:opal, :gem, "opal", 1, 100, 4, [], nil},
    {:topaz, :gem, "topaz", 1, 50, 4, [], nil},
    {:amethyst, :gem, "amethyst", 1, 50, 4, [], nil},
    {:aquamarine, :gem, "aquamarine", 1, 50, 4, [], nil},
    {:garnet, :gem, "garnet", 1, 50, 4, [], nil},
    {:peridot, :gem, "peridot", 1, 50, 4, [], nil},
    {:moonstone, :gem, "moonstone", 1, 25, 4, [], nil},
    {:jasper, :gem, "jasper", 1, 25, 4, [], nil},
    {:glass, :gem, "glass", 1, 1, 4, [], nil},
    {:loadstone, :gem, "loadstone", 1, 5, 3, [], nil},
    {:flint, :gem, "flint", 1, 2, 3, [], nil},
    {:touchstone, :gem, "touchstone", 1, 1, 3, [], nil},
    {:luckstone, :gem, "luckstone", 1, 10, 2, [], nil},
    {:unicorn_horn, :gem, "unicorn horn", 10, 5000, 1, [], nil},

    # ------------------------------------------------------------ rocks
    {:rock, :rock, "rock", 50, 1, 10, [], nil},
    {:boulder, :rock, "boulder", 200, 1, 4, [], nil},
    {:statue, :rock, "statue", 100, 10, 2, [:container], nil},

    # ------------------------------------------------------------ balls & chains
    {:iron_ball, :ball, "iron ball", 50, 2, 3, [:weptool], nil},
    {:ball_of_striking_1, :ball, "ball of striking", 50, 50, 2, [:enchantable], nil},
    {:ball_of_striking_2, :ball, "ball of striking", 50, 100, 1, [:enchantable], nil},
    {:ball_of_cancellation_1, :ball, "ball of cancellation", 50, 100, 1, [:enchantable], nil},
    {:ball_of_cancellation_2, :ball, "ball of cancellation", 50, 200, 1, [:enchantable], nil},
    {:chain, :chain, "chain", 50, 2, 3, [:weptool], nil},

    # ------------------------------------------------------------ coins
    {:gold_piece, :coin, "gold piece", 0, 1, 50, [], nil}
  ]

  # the table is built at compile time; note the anonymous function
  # must be self-contained (module attributes cannot call functions
  # of the module being compiled)
  @table Map.new(@objects, fn {otype, oclass, name, weight, cost, prob, flags, skill} ->
    # potions, scrolls, books and wands hide their nature until
    # identified; every other class is recognised by sight
    description =
      case oclass do
        :potion -> "potion"
        :scroll -> "scroll"
        # like NetHack, an unidentified book is simply "a book"
        :spellbook -> "book"
        :wand -> "wand"
        _ -> name
      end

    def_ = %{
      otype: otype,
      oclass: oclass,
      name: name,
      description: description,
      weight: weight,
      cost: cost,
      prob: prob,
      skill: skill,
      mergeable: not (:no_merge in flags),
      charged: :charged in flags,
      enchantable: :enchantable in flags,
      container: :container in flags,
      food: :food in flags,
      light_source: :light in flags,
      ammo: :ammo in flags,
      launcher: :launcher in flags,
      weptool: :weptool in flags,
      globby: :globby in flags,
      unique: :unique in flags,
      nutrition: if(:food in flags, do: max(1, weight), else: 0),
      artifact: :artifact in flags
    }

    {otype, def_}
  end)

  # ------------------------------------------------------------------ API

  @doc "All known object types (otypes)."
  def all, do: Map.keys(@table)

  @doc "Look up the definition of an object type (raises on unknown otype)."
  def get(otype) do
    case Map.fetch(@table, otype) do
      {:ok, def_} -> def_
      :error -> raise ArgumentError, "unknown object type: #{inspect(otype)}"
    end
  end

  @doc "Is the object type known to the database?"
  def known?(otype), do: Map.has_key?(@table, otype)

  @doc "All object types of a given class."
  def by_class(oclass) do
    @table
    |> Enum.filter(fn {_, def_} -> def_.oclass == oclass end)
    |> Enum.map(fn {otype, _} -> otype end)
    |> Enum.sort()
  end

  @doc """
  Pick a random object type, weighted by `prob` (the Elixir version
  of `mkobj()` in mkobj.c).
  """
  def random_type do
    total = @table |> Map.values() |> Enum.reduce(0, fn def_, acc -> acc + def_.prob end)
    roll = :rand.uniform(total)

    @table
    |> Enum.sort_by(fn {otype, _} -> otype end)
    |> Enum.reduce_while(0, fn {otype, def_}, acc ->
      new_acc = acc + def_.prob

      if roll <= new_acc do
        {:halt, otype}
      else
        {:cont, new_acc}
      end
    end)
  end

  @doc """
  The equipment slot an item uses when worn/wielded (the Elixir
  version of the `owornmask` bits: W_WEP, W_AMUL, W_RING, W_ARMOR...).
  Returns nil for items that cannot be worn.
  """
  def slot_for(otype) do
    def_ = get(otype)

    cond do
      def_.oclass == :weapon and not def_.ammo and not def_.launcher ->
        :weapon

      def_.weptool ->
        :weapon

      def_.oclass == :ring ->
        :ring

      def_.oclass == :amulet ->
        :amulet

      def_.oclass == :armor ->
        armor_slot(def_)

      true ->
        nil
    end
  end

  # ----------------------------------------------------------------- misc

  defp armor_slot(def_) do
    case def_.skill do
      :helm -> :helmet
      :boots -> :boots
      :gloves -> :gloves
      :shield -> :shield
      :cloak -> :cloak
      :shirt -> :shirt
      :blindfold -> :blindfold
      :towel -> :towel
      :lenses -> :lenses
      _ -> :armor
    end
  end
end
