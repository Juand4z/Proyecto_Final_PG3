defmodule Usuario do

  defstruct [:usuario, :clave, :nombre, :tipo, :zona]

  def crear(usuario, clave, nombre, tipo, zona) do
    %Usuario{usuario: usuario, clave: clave, nombre: nombre, tipo: tipo, zona: zona}
  end

  def parse(linea) do
    case Util.campos(linea) do
      [usuario, clave, nombre, tipo, zona] -> {:ok, crear(usuario, clave, nombre, tipo, zona)}
      _ -> :error
    end
  end

  def a_linea(u), do: Enum.join([u.usuario, u.clave, u.nombre, u.tipo, u.zona], "@")
end
