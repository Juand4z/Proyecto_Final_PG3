defmodule Main do
  @moduledoc """
  Modo local del sistema (un solo computador, sin nodos). Sirve para probar todos los comandos
  rapidamente. Inicia el Supervisor y lee los comandos del teclado con Util.ingresar/2.
  Ejecutar (despues de compilar): elixir main.exs
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """

  def main() do
    {:ok, _supervisor} = Sistema.iniciar()

    """

     Sistema de Coordinacion y Gestion de Emergencias


    Escriba 'help' para ver los comandos y 'exit' para salir.
    Primero conectese: connect usuario clave [tipo] [zona]
    """
    |> Util.mostrar_mensaje()

    ciclo(nil)
  end

  # ciclo recursivo: cada vuelta recibe el usuario conectado (nil si no hay nadie)
  defp ciclo(usuario) do
    case Util.ingresar(prompt(usuario), :texto) do
      "exit" ->
        salir(usuario)

      linea ->
        {texto, nuevo_usuario} = Comandos.procesar(linea, usuario)
        if texto != "", do: Util.mostrar_mensaje(texto)
        ciclo(nuevo_usuario)
    end
  end

  defp salir(nil), do: Util.mostrar_mensaje("Hasta pronto.")

  defp salir(usuario) do
    Comandos.procesar("disconnect", usuario)
    Util.mostrar_mensaje("Sesion cerrada. Hasta pronto.")
  end

  defp prompt(nil), do: "> "
  defp prompt(usuario), do: "#{usuario}> "
end

Main.main()
