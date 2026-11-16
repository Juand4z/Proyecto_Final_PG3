defmodule Archivo do
  @moduledoc """
  Modulo encargado de la persistencia en archivos de texto plano.
  Cada registro es una linea y los campos se separan con "@" (igual que en el parcial II).
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """

  @carpeta_por_defecto "nodo-servidor/resources"

  @doc """
  Funcion que arma la ruta de un archivo de datos.
  Las pruebas cambian la carpeta con Application.put_env/3 para no tocar los datos reales.

  Parametros:
  - 'nombre' : nombre del archivo (ej. "recursos.txt").
  """
  def ruta(nombre) do
    Application.get_env(:emergencias, :carpeta_datos, @carpeta_por_defecto)
    |> Path.join(nombre)
  end

  @doc """
  Funcion que lee un archivo y separa los registros validos de los rechazados.

  Retorna:
  - '{:ok, validos, rechazados}' donde validos es una lista de structs y rechazados la cantidad de lineas malas.
  - '{:error, ruta}' si el archivo no se pudo leer.

  Parametros:
  - 'ruta' : ruta del archivo.
  - 'funcion_parse' : funcion que convierte una linea en '{:ok, dato}' o ':error' (ej. &Recurso.parse/1).
  """
  def leer_con_rechazos(ruta, funcion_parse) do
    case File.read(ruta) do
      {:ok, contenido} ->
        lineas = String.split(contenido, "\n", trim: true)
        {validos, rechazados} = procesar_lineas(lineas, funcion_parse, [], 0)
        {:ok, Enum.reverse(validos), rechazados}

      {:error, _} ->
        {:error, ruta}
    end
  end

  # Funcion recursiva que recorre las lineas una por una.
  # Si la linea se puede convertir la agrega a validos, si no suma uno a rechazados.
  defp procesar_lineas([], _funcion, validos, rechazados), do: {validos, rechazados}

  defp procesar_lineas([linea | resto], funcion, validos, rechazados) do
    case funcion.(linea) do
      {:ok, dato} -> procesar_lineas(resto, funcion, [dato | validos], rechazados)
      :error -> procesar_lineas(resto, funcion, validos, rechazados + 1)
    end
  end

  @doc """
  Funcion que carga los registros de un archivo al iniciar un proceso.
  Si el archivo todavia no existe se empieza con una lista vacia.

  Retorna: Lista con los registros validos.

  Parametros:
  - 'ruta' : ruta del archivo.
  - 'funcion_parse' : funcion que convierte una linea en un struct.
  """
  def cargar(ruta, funcion_parse) do
    case leer_con_rechazos(ruta, funcion_parse) do
      {:ok, validos, 0} ->
        validos

      {:ok, validos, rechazados} ->
        Util.mostrar_error("Aviso: se descartaron #{rechazados} linea(s) mal formadas de #{ruta}")
        validos

      {:error, _ruta} ->
        []
    end
  end

  @doc """
  Funcion que reescribe un archivo completo con los elementos recibidos.

  Parametros:
  - 'ruta' : ruta del archivo.
  - 'elementos' : lista de structs a guardar.
  - 'funcion_linea' : funcion que convierte un struct en una linea (ej. &Recurso.a_linea/1).
  """
  def guardar(ruta, elementos, funcion_linea) do
    File.mkdir_p!(Path.dirname(ruta))
    texto = Enum.map_join(elementos, "", fn elemento -> funcion_linea.(elemento) <> "\n" end)
    File.write!(ruta, texto)
  end

  @doc """
  Funcion que agrega una linea al final de un archivo (para los historiales).

  Parametros:
  - 'ruta' : ruta del archivo.
  - 'linea' : texto a agregar.
  """
  def agregar(ruta, linea) do
    File.mkdir_p!(Path.dirname(ruta))
    File.write!(ruta, linea <> "\n", [:append])
  end
end
