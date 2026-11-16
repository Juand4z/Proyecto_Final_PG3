defmodule Coordinador do
  @moduledoc """
  Modulo que demuestra el conflicto concurrente: lanza varias asignaciones del mismo recurso AL MISMO TIEMPO,
  cada una en su propio proceso (spawn), y espera los resultados con receive.
  Como Necesidades y Recursos son GenServer, nunca se asigna mas de lo que hay en el inventario.
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """

  @doc """
  Funcion que lanza un trabajador por cada solicitud y espera todas las respuestas.

  Retorna: Lista de tuplas {id_necesidad, cantidad, resultado}.

  Parametros:
  - 'recurso' : codigo o nombre del recurso que todos quieren tomar.
  - 'solicitudes' : lista de tuplas {id_necesidad, cantidad} (ej. [{"N001", 30}, {"N002", 25}]).
  """
  def asignar_concurrente(recurso, solicitudes) do
    coordinador = self()

    # trabajadores concurrentes, todos se lanzan antes de esperar las respuestas
    Enum.each(solicitudes, fn {id, cantidad} ->
      spawn(fn ->
        send(coordinador, {:resultado, id, cantidad, Necesidades.asignar(id, recurso, cantidad)})
      end)
    end)

    esperar_resultados(length(solicitudes), [])
  end

  # funcion recursiva que recibe los resultados en cualquier orden hasta tenerlos todos
  defp esperar_resultados(0, resultados), do: Enum.reverse(resultados)

  defp esperar_resultados(pendientes, resultados) do
    receive do
      {:resultado, id, cantidad, resultado} ->
        esperar_resultados(pendientes - 1, [{id, cantidad, resultado} | resultados])
    after
      5000 -> Enum.reverse(resultados)
    end
  end
end
