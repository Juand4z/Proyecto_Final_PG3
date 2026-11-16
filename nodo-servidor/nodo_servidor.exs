defmodule Servidor do
  @moduledoc """
  Nodo servidor del sistema distribuido. Inicia el Supervisor con todos los procesos, registra el servicio
  :servicio_emergencias y atiende las solicitudes de los nodos cliente.
  Cada solicitud se atiende en su propio proceso (spawn), asi varios usuarios trabajan al mismo tiempo.
  Ejecutar: elixir --sname nodoservidor@localhost --cookie "$(cat nodo-servidor/cookie)" nodo-servidor/nodo_servidor.exs
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  @nombre_servicio_local :servicio_emergencias

  def main() do
    Util.mostrar_mensaje("PROCESO SERVIDOR: iniciando el sistema de emergencias")
    {:ok, _supervisor} = Sistema.iniciar()

    registrar_servicio(@nombre_servicio_local)
    Util.mostrar_mensaje("Servidor iniciado en #{Node.self()}. Esperando consultas")
    procesar_mensajes()
  end

  defp registrar_servicio(nombre_servicio_local),
    do: Process.register(self(), nombre_servicio_local)

  defp procesar_mensajes() do
    receive do
      {cliente, {:comando, usuario, linea}} ->
        # se crea un proceso por solicitud para no hacer esperar a los demas usuarios
        spawn(fn -> atender(cliente, usuario, linea) end)

        # llama recursivamente para seguir atendiendo consultas
        procesar_mensajes()

      mensaje ->
        Util.mostrar_error("Mensaje desconocido: #{inspect(mensaje)}")
        procesar_mensajes()
    end
  end

  defp atender({_servicio, nodo} = cliente, usuario, linea) do
    Util.mostrar_mensaje("[#{nodo}] #{usuario || "sin sesion"}: #{linea}")
    {texto, nuevo_usuario} = Comandos.procesar(linea, usuario)
    send(cliente, {:respuesta, texto, nuevo_usuario})
  end
end

Servidor.main()
