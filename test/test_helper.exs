ExUnit.configure formatters: [ExUnit.CLIFormatter, JUnitFormatter]
ExUnit.start

Ecto.Adapters.SQL.Sandbox.mode(Foodguy.Repo, :manual)
