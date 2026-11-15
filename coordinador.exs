defmodule Coordinador do

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
