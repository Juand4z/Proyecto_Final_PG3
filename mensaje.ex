defmodule Mensaje do
  @moduledoc """
  Struct que representa un mensaje dejado para una persona o familia.
  Formato en el archivo: id@fecha@remitente@destinatario@contenido@estado
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  defstruct [:id, :fecha, :remitente, :destinatario, :contenido, :estado]

  def crear(id, remitente, destinatario, contenido) do
    %Mensaje{
      id: id,
      fecha: Util.fecha_actual(),
      remitente: remitente,
      destinatario: destinatario,
      contenido: contenido,
      estado: "pendiente"
    }
  end

  def parse(linea) do
    case Util.campos(linea) do
      [id, fecha, remitente, destinatario, contenido, estado] ->
        {:ok,
         %Mensaje{
           id: id,
           fecha: fecha,
           remitente: remitente,
           destinatario: destinatario,
           contenido: contenido,
           estado: estado
         }}

      _ ->
        :error
    end
  end

  def a_linea(m), do: Enum.join([m.id, m.fecha, m.remitente, m.destinatario, m.contenido, m.estado], "@")
end
