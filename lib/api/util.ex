defmodule Gateway.Router.Util do
  import Plug.Conn

  @spec respond(Plug.Conn.t(), {:ok}) :: Plug.Conn.t()
  def respond(conn, {:ok}) do
    conn
    |> send_resp(204, "")
  end

  @spec respond(Plug.Conn.t(), {:ok, any}) :: Plug.Conn.t()
  def respond(conn, {:ok, data}) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{success: true, data: data}))
  end

  @spec respond(Plug.Conn.t(), {:error, atom, binary}) :: Plug.Conn.t()
  def respond(conn, {:error, code, reason}) do
    respond(conn, {:error, 404, code, reason})
  end

  @spec respond(Plug.Conn.t(), {:error, integer, atom, binary}) :: Plug.Conn.t()
  def respond(conn, {:error, http_code, code, reason}) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      http_code,
      Jason.encode!(%{
        success: false,
        error: %{
          code: Atom.to_string(code),
          message: reason
        }
      })
    )
  end

  @spec not_found(Plug.Conn.t()) :: Plug.Conn.t()
  def not_found(conn) do
    respond(conn, {:error, 404, :not_found, "Route does not exist"})
  end

  @spec no_permission(Plug.Conn.t()) :: Plug.Conn.t()
  def no_permission(conn) do
    respond(
      conn,
      {:error, 401, :no_permission, "Invalid key"}
    )
  end
end
