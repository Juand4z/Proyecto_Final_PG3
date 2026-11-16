defmodule Zona do
  @moduledoc """
  Struct que representa un nodo del arbol de zonas: zona -> sectores -> puntos de atencion.
  Todos los nodos tienen la misma forma, por eso el arbol se puede recorrer con funciones recursivas.
  Formato en el archivo: ruta@nombre@nivel@afectados   (la ruta es "zona", "zona/sector" o "zona/sector/punto")
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  defstruct [:codigo, :nombre, :nivel, :afectados, hijos: []]

  def crear(codigo, nombre, nivel, afectados) do
    %Zona{codigo: codigo, nombre: nombre, nivel: nivel, afectados: afectados, hijos: []}
  end

  @doc """
  Funcion que convierte una linea del archivo en un nodo del arbol.

  Retorna:
  - '{:ok, {ruta, zona}}' donde ruta es la lista de codigos (ej. ["centro", "sector3"]).
  - ':error' si la linea no tiene el formato esperado.
  """
  def parse(linea) do
    with [ruta_texto, nombre, nivel, afectados_texto] <- Util.campos(linea),
         {:ok, afectados} <- Util.texto_a_entero(afectados_texto) do
      ruta = String.split(ruta_texto, "/")
      {:ok, {ruta, crear(List.last(ruta), nombre, nivel, afectados)}}
    else
      _ -> :error
    end
  end

  @doc """
  Funcion recursiva que inserta un nodo nuevo siguiendo una ruta de codigos.
  Con la ruta vacia el nodo se agrega como hijo del nodo actual.

  Retorna:
  - '{:ok, zona_actualizada}' si se pudo insertar.
  - '{:error, :id_repetido}' si ya existe un hijo con ese codigo.
  - '{:error, :zona_no_existe}' si algun codigo de la ruta no existe.

  Parametros:
  - 'nodo' : nodo actual del arbol.
  - 'ruta' : lista de codigos hasta el padre del nuevo nodo.
  - 'nuevo' : nodo a insertar.
  """
  def insertar(nodo, [], nuevo) do
    if Enum.any?(nodo.hijos, fn hijo -> hijo.codigo == nuevo.codigo end) do
      {:error, :id_repetido}
    else
      {:ok, %{nodo | hijos: nodo.hijos ++ [nuevo]}}
    end
  end

  def insertar(nodo, [codigo | resto], nuevo) do
    case Enum.find(nodo.hijos, fn hijo -> hijo.codigo == codigo end) do
      nil ->
        {:error, :zona_no_existe}

      hijo ->
        # se inserta en el hijo y luego se reemplaza el hijo viejo por el actualizado
        with {:ok, hijo_actualizado} <- insertar(hijo, resto, nuevo) do
          hijos = Enum.map(nodo.hijos, fn h -> if h.codigo == codigo, do: hijo_actualizado, else: h end)
          {:ok, %{nodo | hijos: hijos}}
        end
    end
  end

  @doc """
  Funcion recursiva que suma las personas afectadas del nodo y de todos sus descendientes.
  """
  def total_afectados(%Zona{afectados: afectados, hijos: hijos}) do
    afectados + total_hijos(hijos)
  end

  defp total_hijos([]), do: 0
  defp total_hijos([hijo | resto]), do: total_afectados(hijo) + total_hijos(resto)

  @doc """
  Funcion recursiva que convierte el arbol en lineas de texto con sangria segun la profundidad.
  """
  def a_texto(nodo, profundidad \\ 0) do
    sangria = String.duplicate("    ", profundidad)

    linea =
      "#{sangria}- #{nodo.codigo} (#{nodo.nombre}) nivel: #{nodo.nivel} | afectados: #{nodo.afectados} | acumulado: #{total_afectados(nodo)}"

    [linea | Enum.flat_map(nodo.hijos, fn hijo -> a_texto(hijo, profundidad + 1) end)]
  end

  @doc """
  Funcion recursiva que aplana el arbol en lineas para guardarlo en el archivo.
  Los padres quedan antes que los hijos, asi al cargar se pueden insertar en orden.
  """
  def aplanar(nodo, ruta_padre \\ []) do
    ruta = ruta_padre ++ [nodo.codigo]
    linea = Enum.join([Enum.join(ruta, "/"), nodo.nombre, nodo.nivel, nodo.afectados], "@")
    [linea | Enum.flat_map(nodo.hijos, fn hijo -> aplanar(hijo, ruta) end)]
  end
end
