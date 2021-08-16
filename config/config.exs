use Mix.Config

config :gateway,
  port: String.to_integer(System.get_env("PORT") || "5050"),
  metrics_port: String.to_integer(System.get_env("METRICS_PORT") || "5051"),
  redis_uri:
    System.get_env("REDIS_URI") ||
      "redis://redis:6379",
  rabbit_uri:
    System.get_env("RABBIT_URI") ||
      "amqp://rabbit:docker@rabbit:5672"
