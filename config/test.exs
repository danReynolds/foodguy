use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :foodguy, Foodguy.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :foodguy, Foodguy.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "foodguy_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :foodguy, :zomato, api_token: System.get_env("ZOMATO_API_TOKEN")

# Used to generate a JUnit XML format of test results for services like CircleCi
config :junit_formatter,
  report_file: "report_file_test.xml",
  report_dir: "#{System.get_env("CIRCLE_TEST_REPORTS")}/exunit",
  print_report_file: true
