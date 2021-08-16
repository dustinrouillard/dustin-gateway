defmodule Gateway.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  match "/health" do
    send_resp(conn, 200, "OK")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
