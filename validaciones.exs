defmodule Validacion do

  def cantidad_positiva(cantidad) when is_integer(cantidad) and cantidad > 0, do: :ok
  def cantidad_positiva(_cantidad), do: {:error, :cantidad_invalida}

  def no_negativo(numero) when is_integer(numero) and numero >= 0, do: :ok
  def no_negativo(_numero), do: {:error, :cantidad_negativa}

  def opcion_valida(valor, opciones, motivo) do
    if valor in opciones do
      :ok
    else
      {:error, motivo}
    end
  end


  def transicion_valida(actual, nuevo, transiciones) do
    if nuevo in Map.get(transiciones, actual, []) do
      :ok
    else
      {:error, :transicion_invalida}
    end
  end

  def no_existe(mapa, id) do
    if Map.has_key?(mapa, id) do
      {:error, :id_repetido}
    else
      :ok
    end
  end

  def buscar(mapa, id, motivo) do
    case Map.get(mapa, id) do
      nil -> {:error, motivo}
      elemento -> {:ok, elemento}
    end
  end
end
