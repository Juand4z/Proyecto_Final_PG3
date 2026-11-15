defmodule Mascotas do

  use GenServer

  @archivo "mascotas.txt"
  @puntaje_minimo 60
  @pesos [{:especie, 40}, {:zona, 25}, {:color, 20}, {:tamano, 15}]

  #API

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def reportar(datos), do: GenServer.call(__MODULE__, {:reportar, datos})

  def listar(filtros \\ []), do: GenServer.call(__MODULE__, {:listar, filtros})

  def buscar_coincidencias(), do: GenServer.call(__MODULE__, :coincidencias)

  def confirmar(id_perdida, id_encontrada), do: GenServer.call(__MODULE__, {:confirmar, id_perdida, id_encontrada})


  def puntaje(%{especie: especie1}, %{especie: especie2}) when especie1 != especie2, do: 0

  def puntaje(perdida, encontrada) do
    Enum.reduce(@pesos, 0, fn {campo, peso}, total ->
      if Map.get(perdida, campo) == Map.get(encontrada, campo), do: total + peso, else: total
    end)
  end


  def coincidencias([], _encontradas), do: []

  def coincidencias([perdida | resto], encontradas) do
    parejas =
      encontradas
      |> Enum.map(fn encontrada -> {perdida, encontrada, puntaje(perdida, encontrada)} end)
      |> Enum.filter(fn {_perdida, _encontrada, puntos} -> puntos >= @puntaje_minimo end)

    parejas ++ coincidencias(resto, encontradas)
  end

  #Servidor

  @impl true
  def init(:ok) do
    mascotas =
      Archivo.ruta(@archivo)
      |> Archivo.cargar(&Mascota.parse/1)
      |> Util.convertir_a_mapa_por(:id)

    {:ok, mascotas}
  end

  @impl true
  def handle_call({:reportar, datos}, _from, mascotas) do
    with :ok <- Validacion.opcion_valida(datos.tipo, ["perdida", "encontrada"], :tipo_de_reporte_invalido) do
      reporte =
        Mascota.crear(
          Util.nuevo_id("P", mascotas),
          datos.tipo,
          datos.especie,
          datos.nombre,
          datos.color,
          datos.tamano,
          datos.zona,
          datos.contacto,
          datos.caracteristicas
        )

      {:reply, {:ok, reporte}, guardar(Map.put(mascotas, reporte.id, reporte))}
    else
      error -> {:reply, error, mascotas}
    end
  end

  def handle_call({:listar, filtros}, _from, mascotas) do
    lista = mascotas |> Map.values() |> Util.filtrar(filtros) |> Enum.sort_by(fn m -> m.id end)
    {:reply, lista, mascotas}
  end

  def handle_call(:coincidencias, _from, mascotas) do
    abiertas = mascotas |> Map.values() |> Enum.filter(fn m -> m.estado != "resuelta" end)
    perdidas = Enum.filter(abiertas, fn m -> m.tipo == "perdida" end)
    encontradas = Enum.filter(abiertas, fn m -> m.tipo == "encontrada" end)

    parejas =
      perdidas
      |> coincidencias(encontradas)
      |> Enum.sort_by(fn {_perdida, _encontrada, puntos} -> puntos end, :desc)

    # los reportes que aparecen en alguna pareja pasan a posible_coincidencia
    ids = Enum.flat_map(parejas, fn {perdida, encontrada, _puntos} -> [perdida.id, encontrada.id] end)

    actualizadas =
      Enum.reduce(ids, mascotas, fn id, acc ->
        Map.update!(acc, id, fn reporte -> %{reporte | estado: "posible_coincidencia"} end)
      end)

    {:reply, parejas, guardar(actualizadas)}
  end

  def handle_call({:confirmar, id_perdida, id_encontrada}, _from, mascotas) do
    with {:ok, perdida} <- Validacion.buscar(mascotas, id_perdida, :reporte_no_existe),
         {:ok, encontrada} <- Validacion.buscar(mascotas, id_encontrada, :reporte_no_existe),
         :ok <- validar_pareja(perdida, encontrada) do
      perdida = %{perdida | estado: "resuelta", pareja: encontrada.id}
      encontrada = %{encontrada | estado: "resuelta", pareja: perdida.id}
      nuevas = mascotas |> Map.put(perdida.id, perdida) |> Map.put(encontrada.id, encontrada)
      {:reply, {:ok, perdida, encontrada}, guardar(nuevas)}
    else
      error -> {:reply, error, mascotas}
    end
  end

  #Privadas

  defp validar_pareja(perdida, encontrada) do
    cond do
      perdida.tipo != "perdida" or encontrada.tipo != "encontrada" -> {:error, :pareja_invalida}
      perdida.estado == "resuelta" or encontrada.estado == "resuelta" -> {:error, :reporte_ya_resuelto}
      perdida.especie != encontrada.especie -> {:error, :especies_diferentes}
      true -> :ok
    end
  end

  defp guardar(mascotas) do
    Archivo.guardar(Archivo.ruta(@archivo), Map.values(mascotas), &Mascota.a_linea/1)
    mascotas
  end
end
