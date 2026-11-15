defmodule Albergues do

  use GenServer

  @archivo "albergues.txt"


  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(codigo, nombre, zona, capacidad, ocupacion \\ 0) do
    GenServer.call(__MODULE__, {:registrar, codigo, nombre, zona, capacidad, ocupacion})
  end

  def consultar(codigo), do: GenServer.call(__MODULE__, {:consultar, codigo})

  def ingreso(codigo, documento), do: GenServer.call(__MODULE__, {:ingreso, codigo, documento})

  def salida(codigo, documento), do: GenServer.call(__MODULE__, {:salida, codigo, documento})

  def listar(), do: GenServer.call(__MODULE__, :listar)

  @doc "Funcion que ordena los albergues del mas ocupado al menos ocupado (en porcentaje)."
  def reporte_ocupacion() do
    Enum.sort_by(listar(), fn albergue -> Albergue.porcentaje(albergue) end, :desc)
  end


  @impl true
  def init(:ok) do
    albergues =
      Archivo.ruta(@archivo)
      |> Archivo.cargar(&Albergue.parse/1)
      |> Util.convertir_a_mapa_por(:codigo)

    {:ok, albergues}
  end

  @impl true
  def handle_call({:registrar, codigo, nombre, zona, capacidad, ocupacion}, _from, albergues) do
    with :ok <- Validacion.no_existe(albergues, codigo),
         :ok <- Validacion.cantidad_positiva(capacidad),
         :ok <- Validacion.no_negativo(ocupacion),
         :ok <- cabe(ocupacion, capacidad) do
      albergue = Albergue.crear(codigo, nombre, zona, capacidad, ocupacion)
      {:reply, {:ok, albergue}, poner(albergues, albergue)}
    else
      error -> {:reply, error, albergues}
    end
  end

  def handle_call({:consultar, codigo}, _from, albergues) do
    {:reply, Validacion.buscar(albergues, codigo, :albergue_no_existe), albergues}
  end

  def handle_call({:ingreso, codigo, documento}, _from, albergues) do
    with {:ok, albergue} <- Validacion.buscar(albergues, codigo, :albergue_no_existe),
         :ok <- no_esta_alojada(albergues, documento),
         :ok <- cabe(albergue.ocupacion + 1, albergue.capacidad) do
      actualizado = %{albergue | ocupacion: albergue.ocupacion + 1, personas: MapSet.put(albergue.personas, documento)}
      {:reply, {:ok, actualizado}, poner(albergues, actualizado)}
    else
      error -> {:reply, error, albergues}
    end
  end

  def handle_call({:salida, codigo, documento}, _from, albergues) do
    with {:ok, albergue} <- Validacion.buscar(albergues, codigo, :albergue_no_existe),
         true <- MapSet.member?(albergue.personas, documento) do
      actualizado = %{albergue | ocupacion: albergue.ocupacion - 1, personas: MapSet.delete(albergue.personas, documento)}
      {:reply, {:ok, actualizado}, poner(albergues, actualizado)}
    else
      false -> {:reply, {:error, :persona_no_esta_en_el_albergue}, albergues}
      error -> {:reply, error, albergues}
    end
  end

  def handle_call(:listar, _from, albergues), do: {:reply, Map.values(albergues), albergues}


  # guarda que impide superar la capacidad maxima
  defp cabe(ocupacion, capacidad) when ocupacion <= capacidad, do: :ok
  defp cabe(_ocupacion, _capacidad), do: {:error, :capacidad_superada}

  # una persona no puede estar en dos albergues al mismo tiempo
  defp no_esta_alojada(albergues, documento) do
    if Enum.any?(Map.values(albergues), fn albergue -> MapSet.member?(albergue.personas, documento) end) do
      {:error, :persona_ya_esta_en_un_albergue}
    else
      :ok
    end
  end

  defp poner(albergues, albergue) do
    albergues = Map.put(albergues, albergue.codigo, albergue)
    Archivo.guardar(Archivo.ruta(@archivo), Map.values(albergues), &Albergue.a_linea/1)
    albergues
  end
end
