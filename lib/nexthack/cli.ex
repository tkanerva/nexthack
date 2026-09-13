defmodule Nexthack.CLI do
  @moduledoc """
  Simple CLI interface for the game
  """
  
  @doc """
  Start the game in terminal mode
  """
  def start do
    # Clear screen
    clear_screen()
    
    # Start world supervisor
    {:ok, _} = Nexthack.World.Supervisor.start_link([])
    
    # Create world and player
    {:ok, world_pid, player_pid} = Nexthack.World.Supervisor.create_world()
    
    # Start game
    Nexthack.World.start_game(world_pid)
    
    # Main game loop
    main_loop(world_pid, player_pid)
  end

  defp main_loop(world_pid, player_pid) do
    loop_iteration(world_pid, player_pid, 0)
  end

  defp loop_iteration(world_pid, player_pid, tick_count) do
    # Clear screen
    clear_screen()
    
    # Get game state
    player_hp = Nexthack.World.get_player_hp(world_pid)
    player_alive = Nexthack.World.player_alive?(world_pid)
    monsters_alive = Nexthack.World.any_monsters_alive?(world_pid)
    messages = Nexthack.World.get_broadcast_messages(world_pid)
    
    # Display game status
    IO.puts("🎮 NextHack - Actor-Based Roguelike")
    IO.puts("=" * 60)
    IO.puts()
    IO.puts("🗺️  Cave Map (80x24)")
    IO.puts("   @ = Hero | M = Monster | # = Wall")
    IO.puts()
    
    # Simple map representation
    display_simple_map(player_hp, player_alive, monsters_alive)
    
    IO.puts()
    IO.puts("📊 Status: HP: #{player_hp |> elem(0)}/#{player_hp |> elem(1)}")
    IO.puts("📜 Broadcast Log:")
    
    # Display recent messages
    Enum.each(Enum.take(messages, 10), fn message ->
      IO.puts("   #{message}")
    end)
    
    if not messages do
      IO.puts("   No events yet.")
    end
    
    IO.puts()
    IO.puts("🎯 Controls:")
    IO.puts("   WASD/Arrows to move | Q to quit")
    IO.puts("   (Monsters move automatically)")
    IO.puts()
    IO.puts("   Move: ", end: "")
    
    # Get user input
    case IO.gets("") do
      "w\r\n" -> handle_move(player_pid, 0, -1)
      "W\r\n" -> handle_move(player_pid, 0, -1)
      "s\r\n" -> handle_move(player_pid, 0, 1)
      "S\r\n" -> handle_move(player_pid, 0, 1)
      "a\r\n" -> handle_move(player_pid, -1, 0)
      "A\r\n" -> handle_move(player_pid, -1, 0)
      "d\r\n" -> handle_move(player_pid, 1, 0)
      "D\r\n" -> handle_move(player_pid, 1, 0)
      "q\r\n" -> handle_quit()
      "Q\r\n" -> handle_quit()
      _ -> :ok
    end
    
    # Check game over conditions
    if not player_alive or not monsters_alive do
      display_game_over(player_alive, world_pid)
      Nexthack.World.stop_game(world_pid)
      return :game_over
    end
    
    # Continue loop
    Process.sleep(100)
    loop_iteration(world_pid, player_pid, tick_count + 1)
  end

  defp display_simple_map({hp, max_hp}, player_alive, monsters_alive) do
    # Create a simple 10x10 representation of the map for display
    # In a real game, this would use the actual map data
    
    map_lines = for y <- 0..9, into: [] do
      line = for x <- 0..9, into: "" do
        # Simple pattern to show walls and empty space
        if x == 0 or x == 9 or y == 0 or y == 9 do
          "#"  # Wall
        else
          if {x + 20, y + 5} == Nexthack.Player.get_position(:player) && player_alive do
            "@"  # Player
          else
            if Enum.random([true, false, false, false, false]) && monsters_alive do
              "M"  # Monster
            else
              " "  # Empty
            end
          end
        end
      end
      line
    end
    
    Enum.each(map_lines, fn line -> IO.puts("   " <> line) end)
  end

  defp handle_move(player_pid, dx, dy) do
    Nexthack.Player.move(player_pid, dx, dy)
    Process.sleep(200)
  end

  defp handle_quit() do
    IO.puts("Quitting game...")
    System.halt(0)
  end

  defp display_game_over(player_alive, world_pid) do
    clear_screen()
    
    if player_alive do
      IO.puts("🎉 ALL MONSTERS DEFEATED!")
      IO.puts("   You have conquered the cave!")
    else
      IO.puts("💀 GAME OVER")
      IO.puts("   The hero has fallen...")
    end
    
    messages = Nexthack.World.get_broadcast_messages(world_pid)
    IO.puts()
    IO.puts("Final Events:")
    Enum.each(Enum.take(messages, 15), fn msg -> IO.puts("  #{msg}") end)
    
    IO.puts()
    IO.puts("Press Enter to continue...", end: "")
    IO.gets("")
  end

  defp clear_screen() do
    # Cross-platform screen clearing
    case :os.type() do
      {:win32, _} -> System.cmd("cmd",/"/c cls")
      _ -> System.cmd("clear", [""])
    end
  end
end