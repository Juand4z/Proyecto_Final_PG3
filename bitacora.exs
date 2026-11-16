defmodule Bitacora do
  @moduledoc """
  Proceso independiente (spawn_link + receive, no es GenServer) que registra la actividad de los usuarios.
  El usuario solo envia un mensaje con send y sigue trabajando, no espera a que se escriba el archivo.
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """

  @nombre_proceso :bitacora
  @archivo "actividad.txt"

  # le indica al Supervisor como iniciar este proceso
  def child_spec(_argumentos) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}}
  end

  def start_link() do
    pid = spawn_link(fn -> ciclo_espera() end)
    Process.register(pid, @nombre_proceso)
    {:ok, pid}
  end

  @doc """
  Funcion que envia (de forma asincrona) una accion para guardar en la bitacora.

  Parametros:
  - 'usuario' : nombre del usuario que hizo la accion.
  - 'accion' : comando que escribio el usuario.
  """
  def registrar(usuario, accion) do
    send(@nombre_proceso, {:registrar, usuario, accion})
    :ok
  end

  @doc """
  Funcion que pide las actividades guardadas. Si el usuario es nil retorna todas.
  Retorna: Lista de tuplas {fecha, usuario, accion}.
  """
  def consultar(usuario \\ nil) do
    send(@nombre_proceso, {:consultar, usuario, self()})

    receive do
      {:actividad, actividades} -> actividades
    after
      3000 -> []
    end
  end

  # ciclo recursivo que mantiene vivo el proceso esperando mensajes
  defp ciclo_espera() do
    receive do
      {:registrar, usuario, accion} ->
        Archivo.agregar(Archivo.ruta(@archivo), Enum.join([Util.fecha_actual(), usuario, accion], "@"))
        ciclo_espera()

      {:consultar, usuario, origen} ->
        actividades =
          Archivo.ruta(@archivo)
          |> Archivo.cargar(&parse/1)
          |> Enum.filter(fn {_fecha, quien, _accion} -> usuario == nil or quien == usuario end)

        send(origen, {:actividad, actividades})
        ciclo_espera()
    end
  end

  defp parse(linea) do
    case Util.campos(linea) do
      [fecha, usuario, accion] -> {:ok, {fecha, usuario, accion}}
      _ -> :error
    end
  end
end
