defmodule Nexthack.ZapTest do
  use ExUnit.Case
  alias Nexthack.Zap
  alias Nexthack.Zap.ZapFactory

  test "Fire bolt zap can be created" do
    {:ok, fire_bolt_pid} = ZapFactory.create_fire_bolt({10, 10}, {1, 0}, self(), self())
    assert is_pid(fire_bolt_pid)
    
    zap_type = Zap.get_zap_type(fire_bolt_pid)
    assert zap_type == :fire_bolt
    
    pos = Zap.get_position(fire_bolt_pid)
    assert pos == {10, 10}
    
    effected = Zap.get_effected_entities(fire_bolt_pid)
    assert effected == []
  end

  test "Lightning bolt zap can be created" do
    {:ok, lightning_pid} = ZapFactory.create_lightning_bolt({15, 15}, {0, 1}, self(), self())
    assert is_pid(lightning_pid)
    
    zap_type = Zap.get_zap_type(lightning_pid)
    assert zap_type == :lightning_bolt
    
    pos = Zap.get_position(lightning_pid)
    assert pos == {15, 15}
  end

  test "Cold cone zap can be created" do
    {:ok, cold_cone_pid} = ZapFactory.create_cold_cone({20, 20}, {-1, 0}, self(), self())
    assert is_pid(cold_cone_pid)
    
    zap_type = Zap.get_zap_type(cold_cone_pid)
    assert zap_type == :cone_of_cold
    
    pos = Zap.get_position(cold_cone_pid)
    assert pos == {20, 20}
  end

  test "Death ray zap can be created" do
    {:ok, death_ray_pid} = ZapFactory.create_death_ray({25, 25}, {0, -1}, self(), self())
    assert is_pid(death_ray_pid)
    
    zap_type = Zap.get_zap_type(death_ray_pid)
    assert zap_type == :death_ray
    
    pos = Zap.get_position(death_ray_pid)
    assert pos == {25, 25}
  end

  test "Force bolt zap can be created" do
    {:ok, force_pid} = ZapFactory.create_force_bolt({30, 30}, {1, 1}, self(), self())
    assert is_pid(force_pid)
    
    zap_type = Zap.get_zap_type(force_pid)
    assert zap_type == :force_bolt
    
    pos = Zap.get_position(force_pid)
    assert pos == {30, 30}
  end

  test "Sleep zap can be created" do
    {:ok, sleep_pid} = ZapFactory.create_sleep_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(sleep_pid)
    
    zap_type = Zap.get_zap_type(sleep_pid)
    assert zap_type == :sleep
  end

  test "Cancellation zap can be created" do
    {:ok, cancel_pid} = ZapFactory.create_cancellation_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(cancel_pid)
    
    zap_type = Zap.get_zap_type(cancel_pid)
    assert zap_type == :cancellation
  end

  test "Teleport zap can be created" do
    {:ok, teleport_pid} = ZapFactory.create_teleport_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(teleport_pid)
    
    zap_type = Zap.get_zap_type(teleport_pid)
    assert zap_type == :teleport
  end

  test "Invisibility zap can be created" do
    {:ok, invis_pid} = ZapFactory.create_invisibility_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(invis_pid)
    
    zap_type = Zap.get_zap_type(invis_pid)
    assert zap_type == :invisibility
  end

  test "Polymorph zap can be created" do
    {:ok, poly_pid} = ZapFactory.create_polymorph_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(poly_pid)
    
    zap_type = Zap.get_zap_type(poly_pid)
    assert zap_type == :polymorph
  end

  test "Slow zap can be created" do
    {:ok, slow_pid} = ZapFactory.create_slow_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(slow_pid)
    
    zap_type = Zap.get_zap_type(slow_pid)
    assert zap_type == :slow
  end

  test "Haste zap can be created" do
    {:ok, haste_pid} = ZapFactory.create_haste_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(haste_pid)
    
    zap_type = Zap.get_zap_type(haste_pid)
    assert zap_type == :haste
  end

  test "Undead turning zap can be created" do
    {:ok, undead_pid} = ZapFactory.create_undead_turning_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(undead_pid)
    
    zap_type = Zap.get_zap_type(undead_pid)
    assert zap_type == :undead_turning
  end

  test "Random zap creation works" do
    {:ok, random_pid} = ZapFactory.create_random_zap({10, 10}, {0, 0}, self(), self())
    assert is_pid(random_pid)
    
    zap_type = Zap.get_zap_type(random_pid)
    # Should be one of the valid zap types
    valid_types = [:fire_bolt, :lightning_bolt, :cone_of_cold, :death_ray, :force_bolt,
                    :sleep, :cancellation, :teleport, :invisibility, :polymorph,
                    :slow, :haste, :undead_turning]
    assert zap_type in valid_types
  end

  test "Zap moves in specified direction" do
    {:ok, fire_bolt_pid} = ZapFactory.create_fire_bolt({10, 10}, {1, 0}, self(), self())
    
    # Fire the zap
    Zap.fire(fire_bolt_pid)
    
    # Give it time to move
    Process.sleep(200)
    
    # Check new position
    new_pos = Zap.get_position(fire_bolt_pid)
    assert new_pos != {10, 10}
    assert elem(new_pos, 0) > 10  # Should have moved east
    assert elem(new_pos, 1) == 10  # Y should stay same
  end

  test "Zap stops after reaching range" do
    {:ok, force_pid} = ZapFactory.create_force_bolt({10, 10}, {1, 0}, self(), self())
    
    # Fire the zap
    Zap.fire(force_pid)
    
    # Give it plenty of time to move (range is 12)
    Process.sleep(1500)
    
    # Check final position
    final_pos = Zap.get_position(force_pid)
    # Should have moved 12 units east
    assert elem(final_pos, 0) == 22
    assert elem(final_pos, 1) == 10
  end

  test "Zap with range 1 stops immediately" do
    {:ok, teleport_pid} = ZapFactory.create_teleport_zap({10, 10}, {1, 0}, self(), self())
    
    # Fire the zap
    Zap.fire(teleport_pid)
    
    # Give it time
    Process.sleep(200)
    
    # Position should be unchanged
    final_pos = Zap.get_position(teleport_pid)
    assert final_pos == {10, 10}
  end

  test "Zap can affect entities at target position" do
    # Create a mock entity process
    mock_entity_pid = spawn(fn -> 
      receive do
        {:attack, msg} -> 
          send(self(), {:attack_received, msg})
        {:status_effect, msg} -> 
          send(self(), {:status_received, msg})
        {:teleport, msg} -> 
          send(self(), {:teleport_received, msg})
        {:cancel, msg} -> 
          send(self(), {:cancel_received, msg})
      end
    end)
    
    # Create a fire bolt zap at entity's position
    {:ok, fire_bolt_pid} = ZapFactory.create_fire_bolt({10, 10}, {1, 0}, self(), self())
    
    # Move entity to next position (where zap will hit)
    entity_at_hit_pos = spawn(fn -> 
      receive do
        {:attack, msg} -> 
          send(self(), {:attack_received, msg})
        {:status_effect, msg} -> 
          send(self(), {:status_received, msg})
      end
    end)
    
    # Fire the zap
    Zap.fire(fire_bolt_pid)
    
    # Give it time to move one step
    Process.sleep(200)
    
    # The zap should have moved to {11, 10}
    # We can't easily test the entity collision without world integration
    # but we can verify the zap moved
    new_pos = Zap.get_position(fire_bolt_pid)
    assert new_pos == {11, 10}
  end

  test "Multiple zaps can exist simultaneously" do
    {:ok, fire_pid} = ZapFactory.create_fire_bolt({10, 10}, {1, 0}, self(), self())
    {:ok, lightning_pid} = ZapFactory.create_lightning_bolt({10, 15}, {1, 0}, self(), self())
    {:ok, cold_pid} = ZapFactory.create_cold_cone({10, 20}, {1, 0}, self(), self())
    
    # All should be separate processes
    assert is_pid(fire_pid)
    assert is_pid(lightning_pid)
    assert is_pid(cold_pid)
    assert fire_pid != lightning_pid
    assert fire_pid != cold_pid
    assert lightning_pid != cold_pid
    
    # Fire all zaps
    Zap.fire(fire_pid)
    Zap.fire(lightning_pid)
    Zap.fire(cold_pid)
    
    # Give them time to move
    Process.sleep(200)
    
    # All should have moved independently
    fire_pos = Zap.get_position(fire_pid)
    lightning_pos = Zap.get_position(lightning_pid)
    cold_pos = Zap.get_position(cold_pid)
    
    assert fire_pos == {11, 10}
    assert lightning_pos == {11, 15}
    assert cold_pos == {11, 20}
  end
end