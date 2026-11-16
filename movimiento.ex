defmodule Movimiento do
  @moduledoc """
  Struct que representa un movimiento del inventario de un recurso (historial).
  Tipos: registro, entrada, salida, asignacion y transferencia.
  Formato en el archivo: fecha@codigo@tipo@cantidad@detalle
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  defstruct [:fecha, :codigo, :tipo, :cantidad, :detalle]

  def crear(codigo, tipo, cantidad, detalle) do
    %Movimiento{fecha: Util.fecha_actual(), codigo: codigo, tipo: tipo, cantidad: cantidad, detalle: detalle}
  end

  def parse(linea) do
    with [fecha, codigo, tipo, cantidad_txt, detalle] <- Util.campos(linea),
         {:ok, cantidad} <- Util.texto_a_entero(cantidad_txt) do
      {:ok, %Movimiento{fecha: fecha, codigo: codigo, tipo: tipo, cantidad: cantidad, detalle: detalle}}
    else
      _ -> :error
    end
  end

  def a_linea(m), do: Enum.join([m.fecha, m.codigo, m.tipo, m.cantidad, m.detalle], "@")
end
