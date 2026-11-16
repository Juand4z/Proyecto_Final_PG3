defmodule Sistema do
  @moduledoc """
  Modulo que arranca el sistema: inicia el Supervisor principal con todos los procesos.
  Estrategia :one_for_one -> si un proceso falla, el Supervisor reinicia solo ese proceso
  y este vuelve a cargar su estado desde su archivo de texto.
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """

  @doc """
  Funcion que inicia el Supervisor con sus 9 hijos.
  Retorna: '{:ok, pid_del_supervisor}'.
  """
  def iniciar() do
    hijos = [
      # proceso independiente (spawn + receive)
      Bitacora,
      # procesos con estado (GenServer)
      Usuarios,
      Zonas,
      Recursos,
      Necesidades,
      Personas,
      Mensajes,
      Mascotas,
      Albergues
    ]

    Supervisor.start_link(hijos, strategy: :one_for_one, name: :supervisor_emergencias)
  end
end
