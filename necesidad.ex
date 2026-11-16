defmodule Necesidad do
  @moduledoc """
  Struct que representa una necesidad puntual (solicitud de ayuda).
  Formato en el archivo: id@tipo@cantidad@asignado@prioridad@zona@descripcion@responsable@estado@albergue
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  defstruct [:id, :tipo, :cantidad, :asignado, :prioridad, :zona, :descripcion, :responsable, :estado, :albergue]

  def crear(id, tipo, cantidad, prioridad, zona, descripcion, responsable, albergue) do
    %Necesidad{
      id: id,
      tipo: tipo,
      cantidad: cantidad,
      asignado: 0,
      prioridad: prioridad,
      zona: zona,
      descripcion: descripcion,
      responsable: responsable,
      estado: "pendiente",
      albergue: albergue
    }
  end

  def parse(linea) do
    with [id, tipo, cantidad_txt, asignado_txt, prioridad, zona, descripcion, responsable, estado, albergue] <-
           Util.campos(linea),
         {:ok, cantidad} <- Util.texto_a_entero(cantidad_txt),
         {:ok, asignado} <- Util.texto_a_entero(asignado_txt) do
      necesidad = crear(id, tipo, cantidad, prioridad, zona, descripcion, responsable, albergue)
      {:ok, %{necesidad | asignado: asignado, estado: estado}}
    else
      _ -> :error
    end
  end

  def a_linea(n) do
    Enum.join(
      [n.id, n.tipo, n.cantidad, n.asignado, n.prioridad, n.zona, n.descripcion, n.responsable, n.estado, n.albergue],
      "@"
    )
  end
end
