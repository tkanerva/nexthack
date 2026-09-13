defmodule Nexthack.TrapTest do
  use ExUnit.Case
  alias Nexthack.Trap
  alias Nexthack.Trap.TrapFactory

  test "Pit trap can be created" do
    {:ok, pit_pid} = TrapFactory.create_pit_trap({10, 10}, self())
    assert is_pid(pit_pid)
    
    trap_type = Trap.get_trap_type(pit_pid)
    assert trap_type == :pit
    
    pos = Trap.get_position(pit_pid)
    assert pos == {10, 10}
    
    assert not Trap.triggered?(pit_pid)
    assert not Trap.disarmed?(pit_pid)
  end

  test "Spiked pit trap can be created" do
    {:ok, spiked_pit_pid} = TrapFactory.create_spiked_pit_trap({15, 15}, self())
    assert is_pid(spiked_pit_pid)
    
    trap_type = Trap.get_trap_type(spiked_pit_pid)
    assert trap_type == :spiked_pit
    
    pos = Trap.get_position(spiked_pit_pid)
    assert pos == {15, 15}
    
    assert not Trap.triggered?(spiked_pit_pid)
    assert not Trap.disarmed?(spiked_pit_pid)
  end

  test "Arrow trap can be created" do
    {:ok, arrow_trap_pid} = TrapFactory.create_arrow_trap({20, 20}, self())
    assert is_pid(arrow_trap_pid)
    
    trap_type = Trap.get_trap_type(arrow_trap_pid)
    assert trap_type == :arrow_trap
    
    pos = Trap.get_position(arrow_trap_pid)
    assert pos == {20, 20}
  end

  test "Fire trap can be created" do
    {:ok, fire_trap_pid} = TrapFactory.create_fire_trap({25, 25}, self())
    assert is_pid(fire_trap_pid)
    
    trap_type = Trap.get_trap_type(fire_trap_pid)
    assert trap_type == :fire_trap
    
    pos = Trap.get_position(fire_trap_pid)
    assert pos == {25, 25}
  end

  test "Random trap creation works" do
    {:ok, random_trap_pid} = TrapFactory.create_random_trap({30, 30}, self())
    assert is_pid(random_trap_pid)
    
    trap_type = Trap.get_trap_type(random_trap_pid)
    # Should be one of the valid trap types
    valid_types = [:pit, :spiked_pit, :arrow_trap, :dart_trap, :fire_trap,
                   :sleeping_gas, :teleportation, :anti_magic, :web, :rolling_boulder,
                   :magic_portal, :trapdoor, :stairs_down, :level_teleporter, :stairs_up]
    assert trap_type in valid_types
  end

  test "Trap can be disarmed" do
    {:ok, pit_pid} = TrapFactory.create_pit_trap({10, 10}, self())
    
    # Disarm the trap
    Trap.disarm(pit_pid, "player")
    
    assert Trap.disarmed?(pit_pid)
    assert not Trap.triggered?(pit_pid)
  end

  test "Disarmed trap cannot be triggered" do
    {:ok, pit_pid} = TrapFactory.create_pit_trap({10, 10}, self())
    
    # Create a mock entity process
    mock_entity_pid = spawn(fn -> 
      receive do
        {:attack, msg} -> 
          send(self(), {:attack_received, msg})
        {:status_effect, msg} ->
          send(self(), {:status_received, msg})
      end
    end)
    
    # Disarm the trap
    Trap.disarm(pit_pid, "player")
    
    # Try to trigger it
    Trap.trigger(pit_pid, mock_entity_pid)
    
    # Entity should not receive any messages
    refute_received {:attack_received, _}
    refute_received {:status_received, _}
    
    assert Trap.triggered?(pit_pid) == false
  end

  test "Triggered trap sends attack message" do
    {:ok, pit_pid} = TrapFactory.create_pit_trap({10, 10}, self())
    
    # Create a mock entity process that forwards messages
    mock_entity_pid = spawn(fn -> 
      receive do
        {:attack, msg} -> 
          send(self(), {:attack_received, msg})
        {:status_effect, msg} ->
          send(self(), {:status_received, msg})
      end
    end)
    
    # Trigger the trap
    Trap.trigger(pit_pid, mock_entity_pid)
    
    # Entity should receive attack message
    assert_received {:attack_received, attack_msg}
    assert attack_msg.damage_type == :acid
    assert attack_msg.power >= 1 and attack_msg.power <= 6
    assert attack_msg.source == Trap.get_trap_type(pit_pid)
    
    # Entity should also receive stuck status effect
    assert_received {:status_received, status_msg}
    assert status_msg.effect == :stuck
    assert status_msg.duration == 10
    
    assert Trap.triggered?(pit_pid)
  end

  test "Arrow trap sends attack message on hit" do
    {:ok, arrow_trap_pid} = TrapFactory.create_arrow_trap({10, 10}, self())
    
    # Create a mock entity process
    mock_entity_pid = spawn(fn -> 
      receive do
        {:attack, msg} -> 
          send(self(), {:attack_received, msg})
      end
    end)
    
    # Trigger the trap
    Trap.trigger(arrow_trap_pid, mock_entity_pid)
    
    # Entity should receive attack message (70% chance)
    # We'll check if it was received, but it might miss
    receive do
      {:attack_received, attack_msg} ->
        assert attack_msg.damage_type == :acid
        assert attack_msg.power >= 1 and attack_msg.power <= 6
      after
        100 -> # Timeout, trap missed
          :ok
    end
    
    assert Trap.triggered?(arrow_trap_pid)
  end

  test "Sleeping gas trap sends sleep status effect" do
    {:ok, gas_trap_pid} = TrapFactory.create_sleeping_gas_trap({10, 10}, self())
    
    # Create a mock entity process
    mock_entity_pid = spawn(fn -> 
      receive do
        {:status_effect, msg} -> 
          send(self(), {:status_received, msg})
      end
    end)
    
    # Trigger the trap
    Trap.trigger(gas_trap_pid, mock_entity_pid)
    
    # Entity should receive sleep status effect
    assert_received {:status_received, status_msg}
    assert status_msg.effect == :sleep
    assert status_msg.duration == 25
    
    assert Trap.triggered?(gas_trap_pid)
  end

  test "Teleportation trap sends teleport message" do
    {:ok, teleport_trap_pid} = TrapFactory.create_teleportation_trap({10, 10}, self())
    
    # Create a mock entity process
    mock_entity_pid = spawn(fn -> 
      receive do
        {:teleport, msg} -> 
          send(self(), {:teleport_received, msg})
      end
    end)
    
    # Trigger the trap
    Trap.trigger(teleport_trap_pid, mock_entity_pid)
    
    # Entity should receive teleport message
    assert_received {:teleport_received, teleport_msg}
    assert teleport_msg.new_pos != {10, 10}  # Should be at new position
    assert elem(teleport_msg.new_pos, 0) >= 0 and elem(teleport_msg.new_pos, 0) < 80
    assert elem(teleport_msg.new_pos, 1) >= 0 and elem(teleport_msg.new_pos, 1) < 24
    
    assert Trap.triggered?(teleport_trap_pid)
  end

  test "Anti-magic trap sends cancel message" do
    {:ok, anti_magic_trap_pid} = TrapFactory.create_anti_magic_trap({10, 10}, self())
    
    # Create a mock entity process
    mock_entity_pid = spawn(fn -> 
      receive do
        {:cancel, msg} -> 
          send(self(), {:cancel_received, msg})
      end
    end)
    
    # Trigger the trap
    Trap.trigger(anti_magic_trap_pid, mock_entity_pid)
    
    # Entity should receive cancel message
    assert_received {:cancel_received, cancel_msg}
    assert cancel_msg.source == Trap.get_trap_type(anti_magic_trap_pid)
    
    assert Trap.triggered?(anti_magic_trap_pid)
  end

  test "Web trap sends stuck and slow status effects" do
    {:ok, web_trap_pid} = TrapFactory.create_web_trap({10, 10}, self())
    
    # Create a mock entity process
    mock_entity_pid = spawn(fn -> 
      receive do
        {:status_effect, msg} -> 
          send(self(), {:status_received, msg})
      end
    end)
    
    # Trigger the trap
    Trap.trigger(web_trap_pid, mock_entity_pid)
    
    # Entity should receive stuck status effect
    assert_received {:status_received, stuck_msg}
    assert stuck_msg.effect == :stuck
    assert stuck_msg.duration == 15
    
    # Entity should also receive slow status effect
    assert_received {:status_received, slow_msg}
    assert slow_msg.effect == :slow
    assert slow_msg.duration == 20
    
    assert Trap.triggered?(web_trap_pid)
  end

  test "Rolling boulder trap sends heavy attack message" do
    {:ok, boulder_trap_pid} = TrapFactory.create_rolling_boulder_trap({10, 10}, self())
    
    # Create a mock entity process
    mock_entity_pid = spawn(fn -> 
      receive do
        {:attack, msg} -> 
          send(self(), {:attack_received, msg})
      end
    end)
    
    # Trigger the trap
    Trap.trigger(boulder_trap_pid, mock_entity_pid)
    
    # Entity should receive heavy attack message (4-20 damage)
    assert_received {:attack_received, attack_msg}
    assert attack_msg.damage_type == :acid
    assert attack_msg.power >= 4 and attack_msg.power <= 20
    
    assert Trap.triggered?(boulder_trap_pid)
  end
end