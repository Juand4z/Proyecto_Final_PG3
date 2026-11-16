defmodule Mascota do
  @moduledoc """
  Struct que representa un reporte de mascota perdida o encontrada.
  Formato en el archivo: id@tipo@especie@nombre@color@tamano@zona@contacto@caracteristicas@estado@pareja
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  defstruct [:id, :tipo, :especie, :nombre, :color, :tamano, :zona, :contacto, :caracteristicas, :estado, :pareja]

  def crear(id, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas) do
    %Mascota{
      id: id,
      tipo: tipo,
      # se guardan en minuscula para que la comparacion no dependa de las mayusculas
      especie: String.downcase(especie),
      nombre: nombre,
      color: String.downcase(color),
      tamano: String.downcase(tamano),
      zona: zona,
      contacto: contacto,
      caracteristicas: caracteristicas,
      estado: "activa",
      pareja: ""
    }
  end

  def parse(linea) do
    case Util.campos(linea) do
      [id, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas, estado, pareja] ->
        mascota = crear(id, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas)
        {:ok, %{mascota | estado: estado, pareja: pareja}}

      _ ->
        :error
    end
  end

  def a_linea(m) do
    Enum.join(
      [m.id, m.tipo, m.especie, m.nombre, m.color, m.tamano, m.zona, m.contacto, m.caracteristicas, m.estado, m.pareja],
      "@"
    )
  end
end
