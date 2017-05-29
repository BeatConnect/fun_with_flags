use Mix.Config

# config :fun_with_flags, :persistence,
#   [adapter: FunWithFlags.Store.Persistent.Redis]
# config :fun_with_flags, :cache_bust_notifications,
#   [enabled: true, adapter: FunWithFlags.Notifications.Redis]


# -------------------------------------------------
# Extract from the ENV

with_cache =
  case System.get_env("CACHE_ENABLED") do
    "false" -> false
    "0"     -> false
    _       -> true # default
  end

with_phx_pubsub =
  case System.get_env("PUBSUB_BROKER") do
    "phoenix_pubsub" -> true
    _ -> false
  end

with_ecto =
  case System.get_env("PERSISTENCE") do
    "ecto" -> true
    _      -> false # default
  end


# -------------------------------------------------
# Configuration

config :fun_with_flags, :cache,
  enabled: with_cache,
  ttl: 60


if with_phx_pubsub do
  config :fun_with_flags, :cache_bust_notifications, [
    adapter: FunWithFlags.Notifications.PhoenixPubSub,
    client: :fwf_test
  ]
end


if with_ecto do
  config :fun_with_flags, :persistence,
    adapter: FunWithFlags.Store.Persistent.Ecto

  config :fun_with_flags, ecto_repos: [FunWithFlags.Dev.EctoRepo]

  config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
    adapter: Ecto.Adapters.Postgres,
    username: "postgres",
    password: "postgres",
    database: "fun_with_flags_dev",
    hostname: "localhost",
    pool_size: 10
end

# -------------------------------------------------
# Import

case Mix.env do
  :test -> import_config "test.exs"
  _     -> nil
end
