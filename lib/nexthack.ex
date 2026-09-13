defmodule Nexthack do
  @moduledoc """
  Main module for the NextHack game.
  """
  
  @doc """
  Start the game
  """
  def start do
    IO.puts("🎮 Welcome to NextHack!")
    IO.puts("   An actor-based roguelike game written in Elixir")
    IO.puts()
    IO.puts("Starting game...")
    
    # Start the CLI
    Nexthack.CLI.start()
  end
end