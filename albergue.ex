defmodule Albergue do
  @moduledoc """
  Struct que representa un albergue. Las personas alojadas se guardan en un MapSet (no admite repetidos).
  Formato en el archivo: codigo@nombre@zona@capacidad@ocupacion@personas   (personas: "doc1,doc2,doc3")
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  defstruct [:codigo, :nombre, :zona, :capacidad, :ocupacion, personas: MapSet.new()]

  def crear(codigo, nombre, zona, capacidad, ocupacion) do
    %Albergue{codigo: codigo, nombre: nombre, zona: zona, capacidad: capacidad, ocupacion: ocupacion, personas: MapSet.new()}
  end

  def parse(linea) do
    with [codigo, nombre, zona, capacidad_txt, ocupacion_txt, personas_txt] <- Util.campos(linea),
         {:ok, capacidad} <- Util.texto_a_entero(capacidad_txt),
         {:ok, ocupacion} <- Util.texto_a_entero(ocupacion_txt) do
      personas = personas_txt |> String.split(",", trim: true) |> MapSet.new()
      {:ok, %{crear(codigo, nombre, zona, capacidad, ocupacion) | personas: personas}}
    else
      _ -> :error
    end
  end

  def a_linea(a) do
    personas = a.personas |> MapSet.to_list() |> Enum.join(",")
    Enum.join([a.codigo, a.nombre, a.zona, a.capacidad, a.ocupacion, personas], "@")
  end

  @doc "Funcion que calcula los cupos disponibles del albergue."
  def cupos(albergue), do: albergue.capacidad - albergue.ocupacion

  @doc "Funcion que calcula el porcentaje de ocupacion del albergue."
  def porcentaje(%Albergue{capacidad: 0}), do: 0.0
  def porcentaje(albergue), do: albergue.ocupacion * 100 / albergue.capacidad
end
