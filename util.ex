defmodule Util do
  @moduledoc """
  Módulo con funciones que se reutilizan
  - Autor: Robinson Arias Muñoz.
  - Fecha: Septiembre del 2026
  - Licencia: GNU GPL v3
  """

  @doc """
  Función para mostrar un mensaje en la pantalla.
  ## Parámetros
   - mensaje, texto que se le presenta al usuario
  ## Ejemplos

    ```elixir
    iex> Util.mostrar_mensaje("Hola Mundo")
    ```

    o puede usar

    ```elixir
    "Hola Mundo"
    |> Util.mostrar_mensaje()
    ```
  """
  def mostrar_mensaje(mensaje) do
    mensaje
    |> IO.puts()
  end

  @doc """
  Función para mostrar un mensaje de error en la pantalla.
  ## Parámetros
   - mensaje, texto que se le presenta al usuario como error
  ## Ejemplos

    ```elixir
    iex> Util.mostrar_error("Dato inválido")
    ```

    o puede usar

    ```elixir
    "Dato inválido"
    |> Util.mostrar_error()
    ```
  """
  def mostrar_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end

  @doc """
  Función para ingresar un dato (:texto, :entero o :real) desde el teclado.
  Para :entero y :real se repite la solicitud hasta que el usuario ingrese un valor válido.
  ## Parámetros
   - mensaje, texto que se le presenta al usuario
   - tipo, :texto, :entero o :real
  ## Ejemplos

    ```elixir
    iex> Util.ingresar("Ingrese el nombre: ", :texto)
    ```
    ```elixir
    iex> Util.ingresar("Ingrese la edad: ", :entero)
    ```
    ```elixir
    iex> Util.ingresar("Ingrese la altura: ", :real)
    ```
    o puede usar

    ```elixir
    "Ingrese la edad: "
    |> Util.ingresar(:entero)
    ```
  """
  def ingresar(mensaje, :texto) do
    case IO.gets(mensaje) do
      texto when is_binary(texto) -> String.trim(texto)
      _ -> ""
    end
  end

  def ingresar(mensaje, :entero) do
    ingresar(mensaje, &String.to_integer/1, :entero)
  end

  def ingresar(mensaje, :real) do
    ingresar(mensaje, &texto_a_real/1, :real)
  end

  # Función privada de apoyo: lectura con validación y reintento para enteros y reales.
  defp ingresar(mensaje, parser, tipo_dato) do
    try do
      mensaje
      |> ingresar(:texto)
      |> parser.()
    rescue
      ArgumentError ->
        "Error, se espera que ingrese un número #{tipo_dato}\n"
        |> mostrar_error()

        mensaje
        |> ingresar(parser, tipo_dato)
    end
  end

  # Acepta "3" y "3.5" como reales; lanza ArgumentError si no es un número.
  defp texto_a_real(texto) do
    case Float.parse(texto) do
      {real, ""} -> real
      _ -> raise ArgumentError, "no es un número real"
    end
  end

  @doc """
  Convierte una cadena de texto en un número (entero o real).
  ## Parámetros
   - texto, cadena a convertir
  ## Retorna
   - {:ok, numero} si el texto es un número válido
   - :error en caso contrario
  ## Ejemplos

    ```elixir
    iex> Util.texto_a_numero("42")
    {:ok, 42}
    iex> Util.texto_a_numero(" 3.5 ")
    {:ok, 3.5}
    iex> Util.texto_a_numero("abc")
    :error
    ```
  """
  def texto_a_numero(texto) do
    texto = String.trim(texto)

    case Integer.parse(texto) do
      {entero, ""} ->
        {:ok, entero}

      _ ->
        case Float.parse(texto) do
          {real, ""} -> {:ok, real}
          _ -> :error
        end
    end
  end

  # ------------------------------------------------------------------------------------------
  # Funciones agregadas por el equipo para el proyecto final (las de arriba son las del profesor)
  # ------------------------------------------------------------------------------------------

  @doc """
  Funcion que convierte una cadena de texto en un numero entero.

  Retorna:
  - {:ok, entero} si el texto es un entero valido.
  - :error en caso contrario.

  Parametros:
  - 'texto' : cadena de texto a convertir.
  """
  def texto_a_entero(texto) do
    case Integer.parse(String.trim(texto)) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  @doc """
  Funcion que separa una linea de un archivo en sus campos. Los campos se separan con "@"
  y a cada uno se le quitan los espacios del inicio y del final.

  Retorna: Lista de textos, uno por campo.

  Parametros:
  - 'linea' : linea del archivo (ej. "R001@agua@agua@50@litros@centro_acopio_1@centro").
  """
  def campos(linea) do
    linea
    |> String.split("@")
    |> Enum.map(fn campo -> String.trim(campo) end)
  end

  @doc """
  Funcion que convierte una lista de mapas (o structs) en un solo mapa, indexado por el valor de una clave
  de cada elemento. Permite buscar un elemento por su codigo o id con Map.get/2 en lugar de recorrer la lista.

  Retorna: Un mapa donde cada clave es el valor de 'clave' de un elemento y el valor es el elemento completo.

  Parametros:
  - 'elementos' : lista de mapas que se quiere indexar.
  - 'clave' : atomo con el nombre del campo que se usara como clave (ej. :codigo, :id).
  """
  def convertir_a_mapa_por(elementos, clave) do
    Map.new(elementos, fn elemento -> {Map.get(elemento, clave), elemento} end)
  end

  @doc """
  Funcion que genera un identificador consecutivo a partir de la cantidad de elementos de un mapa.

  Retorna: Un texto como "N001", "M002" o "P010".

  Parametros:
  - 'prefijo' : letra inicial del identificador.
  - 'mapa' : mapa con los elementos que ya existen.
  """
  def nuevo_id(prefijo, mapa) do
    prefijo <> String.pad_leading(Integer.to_string(map_size(mapa) + 1), 3, "0")
  end

  @doc """
  Funcion que retorna la fecha y la hora actual como texto (ej. "2026-11-14 10:30:00").
  """
  def fecha_actual() do
    NaiveDateTime.local_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
  end

  @doc """
  Funcion que deja un valor numerico (entero o float) con solo dos decimales, util para mostrar
  porcentajes por consola sin la notacion de la terminal.

  Parametros:
  - 'valor' : numero que se quiere mostrar con dos decimales.
  """
  def formater(valor) do
    # Si es entero, lo divide por 1 para volverlo float (ej. 50 -> 50.0). Si ya es float, lo deja igual.
    float_valor = if is_integer(valor), do: valor / 1, else: valor

    :io_lib.format("~.2f", [float_valor])
    |> List.to_string()
  end

  @doc """
  Funcion recursiva que aplica una lista de filtros {campo, valor} sobre una lista de mapas o structs.
  Cada llamada aplica un filtro y se vuelve a llamar con los filtros que faltan.

  Retorna: Lista con los elementos que cumplen todos los filtros.

  Parametros:
  - 'lista' : lista de mapas o structs.
  - 'filtros' : lista de tuplas {campo, valor} (ej. [zona: "centro", prioridad: "critica"]).
  """
  def filtrar(lista, []), do: lista

  def filtrar(lista, [{campo, valor} | resto]) do
    lista
    |> Enum.filter(fn elemento -> to_string(Map.get(elemento, campo)) == valor end)
    |> filtrar(resto)
  end
end
