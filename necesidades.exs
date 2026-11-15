defmodule Necesidades do

  use GenServer

  @archivo "necesidades.txt"
  @tipos ["agua", "alimentos", "medicamentos", "primeros_auxilios", "refugio", "transporte", "rescate", "otra"]
  @prioridades %{"critica" => 1, "alta" => 2, "media" => 3, "baja" => 4}

  # transiciones de estado permitidas
  @transiciones %{
    "pendiente" => ["asignada", "cancelada"],
    "asignada" => ["en_atencion", "cancelada"],
    "en_atencion" => ["atendida", "cancelada"],
    "atendida" => [],
    "cancelada" => []
  }

  #API

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)


  def registrar(datos), do: GenServer.call(__MODULE__, {:registrar, datos})

  def listar(filtros \\ []), do: GenServer.call(__MODULE__, {:listar, filtros})

  def pendientes(), do: GenServer.call(__MODULE__, :pendientes)


  def siguiente() do
    case pendientes() do
      [] -> {:error, :sin_necesidades_pendientes}
      [primera | _resto] -> {:ok, primera}
    end
  end

  def cambiar_estado(id, nuevo_estado), do: GenServer.call(__MODULE__, {:cambiar_estado, id, nuevo_estado})


  def asignar(id, recurso, cantidad), do: GenServer.call(__MODULE__, {:asignar, id, recurso, cantidad})

  def tipos(), do: @tipos

  @doc "Funcion pura que ordena una lista de necesidades por prioridad y luego por id."
  def ordenar_por_prioridad(lista) do
    Enum.sort_by(lista, fn necesidad -> {Map.get(@prioridades, necesidad.prioridad), necesidad.id} end)
  end

  #Servidor

  @impl true
  def init(:ok) do
    necesidades =
      Archivo.ruta(@archivo)
      |> Archivo.cargar(&Necesidad.parse/1)
      |> Util.convertir_a_mapa_por(:id)

    {:ok, necesidades}
  end

  @impl true
  def handle_call({:registrar, datos}, _from, necesidades) do
    with :ok <- Validacion.opcion_valida(datos.tipo, @tipos, :tipo_de_necesidad_invalido),
         :ok <- Validacion.cantidad_positiva(datos.cantidad),
         :ok <- Validacion.opcion_valida(datos.prioridad, Map.keys(@prioridades), :prioridad_invalida) do
      necesidad =
        Necesidad.crear(
          Util.nuevo_id("N", necesidades),
          datos.tipo,
          datos.cantidad,
          datos.prioridad,
          datos.zona,
          datos.descripcion,
          datos.responsable,
          datos.albergue
        )

      {:reply, {:ok, necesidad}, poner(necesidades, necesidad)}
    else
      error -> {:reply, error, necesidades}
    end
  end

  def handle_call({:listar, filtros}, _from, necesidades) do
    lista = necesidades |> Map.values() |> Util.filtrar(filtros) |> ordenar_por_prioridad()
    {:reply, lista, necesidades}
  end

  def handle_call(:pendientes, _from, necesidades) do
    lista =
      necesidades
      |> Map.values()
      |> Enum.filter(fn necesidad -> necesidad.estado in ["pendiente", "asignada", "en_atencion"] end)
      |> ordenar_por_prioridad()

    {:reply, lista, necesidades}
  end

  def handle_call({:cambiar_estado, id, nuevo_estado}, _from, necesidades) do
    with {:ok, necesidad} <- Validacion.buscar(necesidades, id, :necesidad_no_existe),
         :ok <- Validacion.transicion_valida(necesidad.estado, nuevo_estado, @transiciones) do
      actualizada = %{necesidad | estado: nuevo_estado}
      {:reply, {:ok, actualizada}, poner(necesidades, actualizada)}
    else
      error -> {:reply, error, necesidades}
    end
  end

  def handle_call({:asignar, id, recurso, cantidad}, _from, necesidades) do
    # se revisa la necesidad y luego se toma el recurso, si algo falla el with retorna el error
    with {:ok, necesidad} <- Validacion.buscar(necesidades, id, :necesidad_no_existe),
         :ok <- puede_recibir(necesidad),
         :ok <- Validacion.cantidad_positiva(cantidad),
         :ok <- no_excede(necesidad, cantidad),
         {:ok, recurso_actualizado} <- Recursos.tomar(recurso, cantidad, "asignado a #{id}") do
      actualizada = %{necesidad | asignado: necesidad.asignado + cantidad, estado: "asignada"}
      {:reply, {:ok, actualizada, recurso_actualizado}, poner(necesidades, actualizada)}
    else
      error -> {:reply, error, necesidades}
    end
  end

  #Privadas

  # una necesidad atendida, cancelada o en atencion no vuelve a consumir recursos
  defp puede_recibir(%Necesidad{estado: estado}) when estado in ["pendiente", "asignada"], do: :ok
  defp puede_recibir(_necesidad), do: {:error, :necesidad_cerrada}

  # no se puede asignar mas de lo que falta para completar la necesidad
  defp no_excede(necesidad, cantidad) do
    if cantidad <= necesidad.cantidad - necesidad.asignado do
      :ok
    else
      {:error, :cantidad_mayor_a_la_requerida}
    end
  end

  defp poner(necesidades, necesidad) do
    necesidades = Map.put(necesidades, necesidad.id, necesidad)
    Archivo.guardar(Archivo.ruta(@archivo), Map.values(necesidades), &Necesidad.a_linea/1)
    necesidades
  end
end
