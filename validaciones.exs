defmodule Validacion do
  @moduledoc """
  Modulo de validaciones que comparten todos los procesos del sistema.
  Cada funcion retorna ':ok' si el dato cumple la regla, o '{:error, motivo}' si no la cumple,
  para poder encadenarlas con la estructura "with".
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """

  @doc """
  Funcion que verifica que una cantidad sea un entero mayor que cero.

  Retorna:
  - ':ok' si la cantidad es mayor que cero.
  - '{:error, :cantidad_invalida}' si es cero, negativa o no es un entero.

  Parametros:
  - 'cantidad' : numero a verificar.
  """
  def cantidad_positiva(cantidad) when is_integer(cantidad) and cantidad > 0, do: :ok
  def cantidad_positiva(_cantidad), do: {:error, :cantidad_invalida}

  @doc """
  Funcion que verifica que un numero no sea negativo (sirve para afectados, edad, ocupacion, inventario inicial).

  Retorna:
  - ':ok' si el numero es mayor o igual a cero.
  - '{:error, :cantidad_negativa}' en caso contrario.

  Parametros:
  - 'numero' : numero a verificar.
  """
  def no_negativo(numero) when is_integer(numero) and numero >= 0, do: :ok
  def no_negativo(_numero), do: {:error, :cantidad_negativa}

  @doc """
  Funcion que verifica que un valor este dentro de una lista de opciones permitidas.

  Retorna:
  - ':ok' si el valor esta en la lista.
  - '{:error, motivo}' si no esta.

  Parametros:
  - 'valor' : valor ingresado por el usuario.
  - 'opciones' : lista de valores permitidos.
  - 'motivo' : atomo que se retorna como error (ej. :prioridad_invalida).
  """
  def opcion_valida(valor, opciones, motivo) do
    if valor in opciones do
      :ok
    else
      {:error, motivo}
    end
  end

  @doc """
  Funcion que verifica que un cambio de estado este permitido.

  Retorna:
  - ':ok' si el nuevo estado esta en la lista de estados siguientes del estado actual.
  - '{:error, :transicion_invalida}' en caso contrario.

  Parametros:
  - 'actual' : estado actual del elemento.
  - 'nuevo' : estado al que se quiere pasar.
  - 'transiciones' : mapa %{estado => [estados permitidos]}.
  """
  def transicion_valida(actual, nuevo, transiciones) do
    if nuevo in Map.get(transiciones, actual, []) do
      :ok
    else
      {:error, :transicion_invalida}
    end
  end

  @doc """
  Funcion que verifica que un identificador no exista todavia en un mapa.

  Retorna:
  - ':ok' si el identificador es nuevo.
  - '{:error, :id_repetido}' si ya existe.

  Parametros:
  - 'mapa' : mapa con los elementos registrados.
  - 'id' : identificador a verificar.
  """
  def no_existe(mapa, id) do
    if Map.has_key?(mapa, id) do
      {:error, :id_repetido}
    else
      :ok
    end
  end

  @doc """
  Funcion que busca un elemento por su identificador.

  Retorna:
  - '{:ok, elemento}' si existe.
  - '{:error, motivo}' si no existe.

  Parametros:
  - 'mapa' : mapa con los elementos registrados.
  - 'id' : identificador a buscar.
  - 'motivo' : atomo que se retorna como error (ej. :recurso_no_existe).
  """
  def buscar(mapa, id, motivo) do
    case Map.get(mapa, id) do
      nil -> {:error, motivo}
      elemento -> {:ok, elemento}
    end
  end
end
