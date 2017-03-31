defmodule Foodguy.Speech do
  @speech Poison.Parser.parse!(File.read!("speech.json"))

  def get_speech(key) do
    Enum.take_random(@speech[key], 1)
  end
end
