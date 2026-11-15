defmodule Recurso do

  defstruct [:codigo, :nombre, :categoria, :cantidad, :unidad, :ubicacion, :zona]

  def crear(codigo, nombre, categoria, cantidad, unidad, ubicacion, zona) do
    %Recurso{
      codigo: codigo,
      nombre: nombre,
      categoria: categoria,
      cantidad: cantidad,
      unidad: unidad,
      ubicacion: ubicacion,
      zona: zona
    }
  end

  def parse(linea) do
    with [codigo, nombre, categoria, cantidad_txt, unidad, ubicacion, zona] <- Util.campos(linea),
         {:ok, cantidad} <- Util.texto_a_entero(cantidad_txt) do
      {:ok, crear(codigo, nombre, categoria, cantidad, unidad, ubicacion, zona)}
    else
      _ -> :error
    end
  end

  def a_linea(r), do: Enum.join([r.codigo, r.nombre, r.categoria, r.cantidad, r.unidad, r.ubicacion, r.zona], "@")
end
