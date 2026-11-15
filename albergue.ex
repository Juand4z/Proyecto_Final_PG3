defmodule Albergue do
  defstruct [:codigo, :nombre, :zona, :capacidad, :ocupacion, personas: MapSet.new()]

  def crear(codigo, nombre, zona, capacidad, ocupacion) do
    %Albergue{codigo: codigo, nombre: nombre, zona: zona, capacidad: capacidad, ocupacion: ocupacion, personas: MapSet.new()}
  end

  def parse(linea) do
    with [codigo, nombre, zona, capacidad_txt, ocupacion_txt, personas_txt] <- Util.campos(linea),
    {:ok, capacidad} <- Util.texto_a_entero(capacidad_txt)
    {:ok, ocupacion} <- Util.texto_a_entero(ocupacion_txt)
    personas = personas_txt |>String.split(",", trim: true) |> MapSet.new()
    {:ok, %{crear(codigo, nombre, zona, capacidad, ocupacion) | personas: personas}}
  else
    _ -> :error

  end

  def a_linea(a) do
    personas = a.personas |> MapSet.to_list() |> Enum.join(",")
    Enum.join([a.codigo, a.nombre, a.zona, a.capacidad, a.ocupacion, personas], "@")
  end

  def cupos(albergue), do: albergue.capacidad - albergue.ocupacion

  def porcentaje(%Albergue{capacidad: 0}), do: 0.0
  def porcentaje(albergue), do: albergue.ocupacion * 100 / albergue.capacidad
end
