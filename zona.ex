defmodule Zona do

  defstruct [:codigo, :nombre, :nivel, :afectados, hijos: []]

  def crear(codigo, nombre, nivel, afectados) do
    %Zona{codigo: codigo, nombre: nombre, nivel: nivel, afectados: afectados, hijos: []}
  end

  def parse(linea) do
    with [ruta_texto, nombre, nivel, afectados_texto] <- Util.campos(linea),
         {:ok, afectados} <- Util.texto_a_entero(afectados_texto) do
      ruta = String.split(ruta_texto, "/")
      {:ok, {ruta, crear(List.last(ruta), nombre, nivel, afectados)}}
    else
      _ -> :error
    end
  end

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


  def total_afectados(%Zona{afectados: afectados, hijos: hijos}) do
    afectados + total_hijos(hijos)
  end

  defp total_hijos([]), do: 0
  defp total_hijos([hijo | resto]), do: total_afectados(hijo) + total_hijos(resto)


  def a_texto(nodo, profundidad \\ 0) do
    sangria = String.duplicate("    ", profundidad)

    linea =
      "#{sangria}- #{nodo.codigo} (#{nodo.nombre}) nivel: #{nodo.nivel} | afectados: #{nodo.afectados} | acumulado: #{total_afectados(nodo)}"

    [linea | Enum.flat_map(nodo.hijos, fn hijo -> a_texto(hijo, profundidad + 1) end)]
  end


  def aplanar(nodo, ruta_padre \\ []) do
    ruta = ruta_padre ++ [nodo.codigo]
    linea = Enum.join([Enum.join(ruta, "/"), nodo.nombre, nodo.nivel, nodo.afectados], "@")
    [linea | Enum.flat_map(nodo.hijos, fn hijo -> aplanar(hijo, ruta) end)]
  end
end
