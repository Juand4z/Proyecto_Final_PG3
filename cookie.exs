defmodule Cookie do
  @moduledoc """
  Genera una llave aleatoria para usarla como cookie de los nodos.
  El resultado se copia en nodo-servidor/cookie y nodo-cliente/cookie (deben ser iguales).
  Ejecutar (despues de compilar Util.ex): elixir cookie.exs
  """
  @longitud_llave 128

  def main() do
    :crypto.strong_rand_bytes(@longitud_llave)
    |> Base.encode64()
    |> Util.mostrar_mensaje()
  end
end

Cookie.main()
