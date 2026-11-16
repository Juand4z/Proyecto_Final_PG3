defmodule Zonas do
  @moduledoc """
  GenServer que administra las zonas afectadas como arboles: zona -> sectores -> puntos de atencion.
  Estado: %{codigo_zona => %Zona{}}
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """
  use GenServer

  @archivo "zonas.txt"
  @niveles ["critico", "alto", "medio", "bajo"]

  #API

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar_zona(codigo, nombre, nivel, afectados) do
    GenServer.call(__MODULE__, {:registrar_zona, codigo, nombre, nivel, afectados})
  end

  @doc "Funcion que registra un sector dentro de una zona."
  def registrar_sector(zona, codigo, nivel, afectados) do
    GenServer.call(__MODULE__, {:registrar_hijo, [zona], codigo, nivel, afectados})
  end

  @doc "Funcion que registra un punto de atencion dentro de un sector."
  def registrar_punto(zona, sector, codigo, afectados) do
    GenServer.call(__MODULE__, {:registrar_hijo, [zona, sector], codigo, "-", afectados})
  end

  def cambiar_nivel(zona, nivel), do: GenServer.call(__MODULE__, {:cambiar_nivel, zona, nivel})

  def obtener(zona), do: GenServer.call(__MODULE__, {:obtener, zona})

  def listar(), do: GenServer.call(__MODULE__, :listar)

  #Servidor

  @impl true
  def init(:ok) do
    # cada linea trae su ruta, los padres vienen antes que los hijos, asi que se insertan en orden
    zonas =
      Archivo.ruta(@archivo)
      |> Archivo.cargar(&Zona.parse/1)
      |> Enum.reduce(%{}, fn {ruta, nodo}, acc -> agregar_nodo(acc, ruta, nodo) end)

    {:ok, zonas}
  end

  @impl true
  def handle_call({:registrar_zona, codigo, nombre, nivel, afectados}, _from, zonas) do
    with :ok <- Validacion.no_existe(zonas, codigo),
         :ok <- Validacion.opcion_valida(nivel, @niveles, :nivel_invalido),
         :ok <- Validacion.no_negativo(afectados) do
      zona = Zona.crear(codigo, nombre, nivel, afectados)
      guardar_y_responder(Map.put(zonas, codigo, zona), zona)
    else
      error -> {:reply, error, zonas}
    end
  end

  def handle_call({:registrar_hijo, [zona | resto], codigo, nivel, afectados}, _from, zonas) do
    with {:ok, raiz} <- Validacion.buscar(zonas, zona, :zona_no_existe),
         :ok <- validar_nivel_hijo(nivel),
         :ok <- Validacion.no_negativo(afectados),
         {:ok, actualizada} <- Zona.insertar(raiz, resto, Zona.crear(codigo, codigo, nivel, afectados)) do
      guardar_y_responder(Map.put(zonas, zona, actualizada), actualizada)
    else
      error -> {:reply, error, zonas}
    end
  end

  def handle_call({:cambiar_nivel, codigo, nivel}, _from, zonas) do
    with {:ok, zona} <- Validacion.buscar(zonas, codigo, :zona_no_existe),
         :ok <- Validacion.opcion_valida(nivel, @niveles, :nivel_invalido) do
      actualizada = %{zona | nivel: nivel}
      guardar_y_responder(Map.put(zonas, codigo, actualizada), actualizada)
    else
      error -> {:reply, error, zonas}
    end
  end

  def handle_call({:obtener, codigo}, _from, zonas) do
    {:reply, Validacion.buscar(zonas, codigo, :zona_no_existe), zonas}
  end

  def handle_call(:listar, _from, zonas), do: {:reply, Map.values(zonas), zonas}

  #Privadas

  # una ruta de un solo codigo es una zona nueva, una ruta mas larga se inserta dentro de su zona
  defp agregar_nodo(zonas, [_codigo], nodo), do: Map.put(zonas, nodo.codigo, nodo)

  defp agregar_nodo(zonas, [zona | resto], nodo) do
    case Zona.insertar(Map.get(zonas, zona), Enum.drop(resto, -1), nodo) do
      {:ok, actualizada} -> Map.put(zonas, zona, actualizada)
      _ -> zonas
    end
  end

  # los puntos de atencion no tienen nivel propio, se guardan con "-"
  defp validar_nivel_hijo("-"), do: :ok
  defp validar_nivel_hijo(nivel), do: Validacion.opcion_valida(nivel, @niveles, :nivel_invalido)

  defp guardar_y_responder(zonas, respuesta) do
    lineas = Enum.flat_map(Map.values(zonas), fn zona -> Zona.aplanar(zona) end)
    Archivo.guardar(Archivo.ruta(@archivo), lineas, fn linea -> linea end)
    {:reply, {:ok, respuesta}, zonas}
  end
end
