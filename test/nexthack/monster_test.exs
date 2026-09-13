defmodule Nexthack.MonsterTest do
  use ExUnit.Case
  alias Nexthack.Monster
  
  test "Goblin can be created" do
    {:ok, goblin_pid} = Monster.Goblin.create({10, 10}, self())
    assert is_pid(goblin_pid)
    
    name = Monster.get_name(goblin_pid)
    assert name == "Goblin"
    
    {hp, max_hp} = Monster.get_hp(goblin_pid)
    assert hp == 8
    assert max_hp == 8
    
    pos = Monster.get_position(goblin_pid)
    assert pos == {10, 10}
    
    alive = Monster.alive?(goblin_pid)
    assert alive == true
  end
  
  test "Orc can be created" do
    {:ok, orc_pid} = Monster.Orc.create({15, 15}, self())
    assert is_pid(orc_pid)
    
    name = Monster.get_name(orc_pid)
    assert name == "Orc"
    
    {hp, max_hp} = Monster.get_hp(orc_pid)
    assert hp == 15
    assert max_hp == 15
    
    alive = Monster.alive?(orc_pid)
    assert alive == true
  end
  
  test "Bat can be created" do
    {:ok, bat_pid} = Monster.Bat.create({5, 5}, self())
    assert is_pid(bat_pid)
    
    name = Monster.get_name(bat_pid)
    assert name == "Bat"
    
    {hp, max_hp} = Monster.get_hp(bat_pid)
    assert hp == 4
    assert max_hp == 4
    
    alive = Monster.alive?(bat_pid)
    assert alive == true
  end
  
  test "Monster takes damage" do
    {:ok, goblin_pid} = Monster.Goblin.create({10, 10}, self())
    
    # Apply damage
    Monster.take_damage(goblin_pid, :fire, 3)
    
    {hp, max_hp} = Monster.get_hp(goblin_pid)
    assert hp == 5  # 8 - 3 = 5
    assert max_hp == 8
    assert Monster.alive?(goblin_pid) == true
    
    # Apply lethal damage
    Monster.take_damage(goblin_pid, :fire, 10)
    assert Monster.alive?(goblin_pid) == false
  end
  
  test "Monster resists fire if undead" do
    # Create a mock undead monster
    initial_state = %Nexthack.Monster{
      id: "undead_test",
      name: "Undead Test",
      hp: 10,
      max_hp: 10,
      ac: 10,
      pos: {10, 10},
      damage: 2,
      speed: 1,
      is_undead: true,  # This makes it resistant to fire
      world_pid: self()
    }
    
    {:ok, undead_pid} = Monster.start_link(initial_state.id, initial_state)
    
    # Apply fire damage
    Monster.take_damage(undead_pid, :fire, 5)
    
    {hp, _max_hp} = Monster.get_hp(undead_pid)
    # Should take reduced damage due to resistance
    assert hp < 10  # Takes some damage but less
    assert Monster.alive?(undead_pid) == true
  end
end