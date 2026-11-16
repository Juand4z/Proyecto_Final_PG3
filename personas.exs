defmodule Personas do
  @moduledoc """
  GenServer que registra las personas afectadas y el historial de cambios de estado.
  Estado: %{documento => %Persona{}}
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  use GenServer

  @archivo "personas.txt"

  @transiciones %{
    "sin_informacion" => ["reportada", "localizada"],
    "reportada" => ["localizada", "trasladada", "en_albergue"],
    "localizada" => ["trasladada", "en_albergue", "reunificada"],
    "trasladada" => ["localizada", "en_albergue", "reunificada"],
    "en_albergue" => ["trasladada", "reunificada"],
    "reunificada" => []
  }

  #API

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(documento, nombre, edad, zona, estado) do
    GenServer.call(__MODULE__, {:registrar, documento, nombre, edad, zona, estado})
  end

  def buscar(documento), do: GenServer.call(__MODULE__, {:buscar, documento})

  @doc "Funcion que busca personas por filtros. El filtro nombre busca coincidencias parciales."
  def buscar_por(filtros), do: GenServer.call(__MODULE__, {:buscar_por, filtros})

  def cambiar_estado(documento, estado), do: GenServer.call(__MODULE__, {:cambiar_estado, documento, estado})

  def listar(), do: buscar_por([])

  def estados(), do: Map.keys(@transiciones)

  #Servidor

  @impl true
  def init(:ok) do
    personas =
      Archivo.ruta(@archivo)
      |> Archivo.cargar(&Persona.parse/1)
      |> Util.convertir_a_mapa_por(:documento)

    {:ok, personas}
  end

  @impl true
  def handle_call({:registrar, documento, nombre, edad, zona, estado}, _from, personas) do
    with :ok <- Validacion.no_existe(personas, documento),
         :ok <- Validacion.no_negativo(edad),
         :ok <- Validacion.opcion_valida(estado, estados(), :estado_invalido) do
      persona = Persona.crear(documento, nombre, edad, zona, estado)
      {:reply, {:ok, persona}, poner(personas, persona)}
    else
      error -> {:reply, error, personas}
    end
  end

  def handle_call({:buscar, documento}, _from, personas) do
    {:reply, Validacion.buscar(personas, documento, :persona_no_existe), personas}
  end

  def handle_call({:buscar_por, filtros}, _from, personas) do
    # el nombre se compara de forma parcial y el resto de filtros de forma exacta
    {nombre, otros} = Keyword.pop(filtros, :nombre)

    lista =
      personas
      |> Map.values()
      |> Util.filtrar(otros)
      |> Enum.filter(fn persona -> nombre == nil or contiene?(persona.nombre, nombre) end)
      |> Enum.sort_by(fn persona -> persona.nombre end)

    {:reply, lista, personas}
  end

  def handle_call({:cambiar_estado, documento, nuevo}, _from, personas) do
    with {:ok, persona} <- Validacion.buscar(personas, documento, :persona_no_existe),
         :ok <- Validacion.transicion_valida(persona.estado, nuevo, @transiciones) do
      # el historial conserva todos los estados por los que paso la persona
      actualizada = %{persona | estado: nuevo, historial: persona.historial ++ [{nuevo, Util.fecha_actual()}]}
      {:reply, {:ok, actualizada}, poner(personas, actualizada)}
    else
      error -> {:reply, error, personas}
    end
  end

  #Privadas

  defp contiene?(texto, parte), do: String.contains?(String.downcase(texto), String.downcase(parte))

  defp poner(personas, persona) do
    personas = Map.put(personas, persona.documento, persona)
    Archivo.guardar(Archivo.ruta(@archivo), Map.values(personas), &Persona.a_linea/1)
    personas
  end
end
