defmodule Mensaje do

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
