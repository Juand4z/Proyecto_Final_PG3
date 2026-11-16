defmodule Cliente do
  @moduledoc """
  Nodo cliente del sistema distribuido. Cada usuario abre su propio nodo cliente, se conecta al nodo servidor
  y le envia los comandos que escribe. El servidor responde con el texto y el usuario conectado.
  Ejecutar (cada cliente con un nombre distinto):
  elixir --sname nodocliente1@localhost --cookie "$(cat nodo-cliente/cookie)" nodo-cliente/nodo_cliente.exs
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  @nombre_servicio_local :servicio_respuesta
  @nodo_remoto :nodoservidor@localhost
  @servicio_remoto {:servicio_emergencias, @nodo_remoto}

  def main() do
    Util.mostrar_mensaje("PROCESO CLIENTE #{Node.self()}")

    @nombre_servicio_local
    |> registrar_servicio()

    establecer_conexion(@nodo_remoto)
    |> iniciar_sesion()
  end

  defp registrar_servicio(nombre_servicio_local),
    do: Process.register(self(), nombre_servicio_local)

  defp establecer_conexion(nodo_remoto), do: Node.connect(nodo_remoto)

  defp iniciar_sesion(true) do
    """
    Conectado al servidor #{@nodo_remoto}
    Escriba 'help' para ver los comandos y 'exit' para salir.
    Primero conectese: connect usuario clave [tipo] [zona]
    """
    |> Util.mostrar_mensaje()

    ciclo(nil)
  end

  # cubre false (no hubo conexion) y :ignored (el nodo no se inicio con --sname)
  defp iniciar_sesion(_),
    do: Util.mostrar_error("No se pudo conectar con el nodo servidor")

  # ciclo recursivo: lee un comando, lo envia al servidor y espera la respuesta
  defp ciclo(usuario) do
    case Util.ingresar(prompt(usuario), :texto) do
      "exit" ->
        if usuario != nil, do: enviar_comando(usuario, "disconnect")
        Util.mostrar_mensaje("Comunicacion finalizada.")

      linea ->
        case enviar_comando(usuario, linea) do
          {:ok, texto, nuevo_usuario} ->
            if texto != "", do: Util.mostrar_mensaje(texto)
            ciclo(nuevo_usuario)

          :sin_respuesta ->
            Util.mostrar_error("El servidor no respondio")
            ciclo(usuario)
        end
    end
  end

  defp enviar_comando(usuario, linea) do
    send(@servicio_remoto, {servicio_local(), {:comando, usuario, linea}})
    recibir_respuesta()
  end

  defp recibir_respuesta() do
    receive do
      {:respuesta, texto, nuevo_usuario} -> {:ok, texto, nuevo_usuario}
    after
      10_000 -> :sin_respuesta
    end
  end

  # el servidor necesita el nombre del proceso y el nodo para poder responder
  defp servicio_local(), do: {@nombre_servicio_local, Node.self()}

  defp prompt(nil), do: "> "
  defp prompt(usuario), do: "#{usuario}> "
end

Cliente.main()
