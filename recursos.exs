defmodule Recursos do

  use GenServer

  @archivo "recursos.txt"
  @archivo_movimientos "movimientos.txt"
  @umbral_critico 20

  #API

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(%Recurso{} = recurso), do: GenServer.call(__MODULE__, {:registrar, recurso})

  def entrada(codigo, cantidad), do: GenServer.call(__MODULE__, {:entrada, codigo, cantidad})

  def salida(codigo, cantidad), do: GenServer.call(__MODULE__, {:salida, codigo, cantidad})

  def tomar(codigo_o_nombre, cantidad, detalle) do
    GenServer.call(__MODULE__, {:tomar, codigo_o_nombre, cantidad, detalle})
  end

  def transferir(codigo, origen, destino, cantidad) do
    GenServer.call(__MODULE__, {:transferir, codigo, origen, destino, cantidad})
  end

  @doc "Funcion que lista los recursos aplicando filtros [{campo, valor}]."
  def listar(filtros \\ []), do: GenServer.call(__MODULE__, {:listar, filtros})

  @doc "Funcion que lista los recursos con menos unidades que el umbral critico."
  def criticos(), do: GenServer.call(__MODULE__, :criticos)

  def historial(codigo), do: GenServer.call(__MODULE__, {:historial, codigo})

  def umbral_critico(), do: @umbral_critico

  #Servidor

  @impl true
  def init(:ok) do
    recursos =
      Archivo.ruta(@archivo)
      |> Archivo.cargar(&Recurso.parse/1)
      |> Util.convertir_a_mapa_por(:codigo)

    movimientos = Archivo.cargar(Archivo.ruta(@archivo_movimientos), &Movimiento.parse/1)

    {:ok, %{recursos: recursos, movimientos: movimientos}}
  end

  @impl true
  def handle_call({:registrar, recurso}, _from, estado) do
    with :ok <- Validacion.no_existe(estado.recursos, recurso.codigo),
         :ok <- Validacion.no_negativo(recurso.cantidad) do
      nuevo_estado =
        estado
        |> poner(recurso)
        |> movimiento(recurso.codigo, "registro", recurso.cantidad, "inventario inicial")

      {:reply, {:ok, recurso}, nuevo_estado}
    else
      error -> {:reply, error, estado}
    end
  end

  def handle_call({:entrada, codigo, cantidad}, _from, estado) do
    with {:ok, recurso} <- Validacion.buscar(estado.recursos, codigo, :recurso_no_existe),
         :ok <- Validacion.cantidad_positiva(cantidad) do
      actualizado = %{recurso | cantidad: recurso.cantidad + cantidad}
      nuevo_estado = estado |> poner(actualizado) |> movimiento(codigo, "entrada", cantidad, "entrada de inventario")
      {:reply, {:ok, actualizado}, nuevo_estado}
    else
      error -> {:reply, error, estado}
    end
  end

  def handle_call({:salida, codigo, cantidad}, _from, estado) do
    with {:ok, recurso} <- Validacion.buscar(estado.recursos, codigo, :recurso_no_existe),
         :ok <- Validacion.cantidad_positiva(cantidad),
         :ok <- alcanza(recurso, cantidad) do
      actualizado = %{recurso | cantidad: recurso.cantidad - cantidad}
      nuevo_estado = estado |> poner(actualizado) |> movimiento(codigo, "salida", cantidad, "salida de inventario")
      {:reply, {:ok, actualizado}, nuevo_estado}
    else
      error -> {:reply, error, estado}
    end
  end

  def handle_call({:tomar, clave, cantidad, detalle}, _from, estado) do
    with {:ok, recurso} <- buscar_por_codigo_o_nombre(estado.recursos, clave),
         :ok <- Validacion.cantidad_positiva(cantidad),
         :ok <- alcanza(recurso, cantidad) do
      actualizado = %{recurso | cantidad: recurso.cantidad - cantidad}
      nuevo_estado = estado |> poner(actualizado) |> movimiento(recurso.codigo, "asignacion", cantidad, detalle)
      {:reply, {:ok, actualizado}, nuevo_estado}
    else
      error -> {:reply, error, estado}
    end
  end

  def handle_call({:transferir, codigo, origen, destino, cantidad}, _from, estado) do
    with {:ok, recurso} <- Validacion.buscar(estado.recursos, codigo, :recurso_no_existe),
         :ok <- validar_origen(recurso, origen, destino),
         :ok <- Validacion.cantidad_positiva(cantidad),
         :ok <- alcanza(recurso, cantidad) do
      origen_actualizado = %{recurso | cantidad: recurso.cantidad - cantidad}
      en_destino = recurso_en_destino(estado.recursos, recurso, destino)
      destino_actualizado = %{en_destino | cantidad: en_destino.cantidad + cantidad}

      nuevo_estado =
        estado
        |> poner(origen_actualizado)
        |> poner(destino_actualizado)
        |> movimiento(codigo, "transferencia", cantidad, "enviado a #{destino}")
        |> movimiento(destino_actualizado.codigo, "transferencia", cantidad, "recibido de #{origen}")

      {:reply, {:ok, origen_actualizado, destino_actualizado}, nuevo_estado}
    else
      error -> {:reply, error, estado}
    end
  end

  def handle_call({:listar, filtros}, _from, estado) do
    lista =
      estado.recursos
      |> Map.values()
      |> Util.filtrar(filtros)
      |> Enum.sort_by(fn recurso -> recurso.codigo end)

    {:reply, lista, estado}
  end

  def handle_call(:criticos, _from, estado) do
    lista =
      estado.recursos
      |> Map.values()
      |> Enum.filter(fn recurso -> recurso.cantidad < @umbral_critico end)
      |> Enum.sort_by(fn recurso -> recurso.cantidad end)

    {:reply, lista, estado}
  end

  def handle_call({:historial, codigo}, _from, estado) do
    {:reply, Enum.filter(estado.movimientos, fn mov -> mov.codigo == codigo end), estado}
  end

  #Privadas

  # busca por codigo, si no existe toma el recurso con ese nombre que tenga mas unidades
  defp buscar_por_codigo_o_nombre(recursos, clave) do
    case Map.get(recursos, clave) do
      nil ->
        recursos
        |> Map.values()
        |> Enum.filter(fn recurso -> recurso.nombre == clave end)
        |> Enum.sort_by(fn recurso -> recurso.cantidad end, :desc)
        |> case do
          [] -> {:error, :recurso_no_existe}
          [recurso | _resto] -> {:ok, recurso}
        end

      recurso ->
        {:ok, recurso}
    end
  end

  # guarda que impide que el inventario quede negativo
  defp alcanza(recurso, cantidad) when cantidad <= recurso.cantidad, do: :ok
  defp alcanza(_recurso, _cantidad), do: {:error, :inventario_insuficiente}

  defp validar_origen(recurso, origen, destino) do
    cond do
      recurso.ubicacion != origen -> {:error, :origen_incorrecto}
      origen == destino -> {:error, :origen_y_destino_iguales}
      true -> :ok
    end
  end

  # si en el destino ya hay un recurso con el mismo nombre se usa ese, si no se crea uno con codigo "CODIGO-destino"
  defp recurso_en_destino(recursos, recurso, destino) do
    existente =
      Enum.find(Map.values(recursos), fn r -> r.nombre == recurso.nombre and r.ubicacion == destino end)

    existente || %{recurso | codigo: "#{recurso.codigo}-#{destino}", cantidad: 0, ubicacion: destino}
  end

  defp poner(estado, recurso) do
    recursos = Map.put(estado.recursos, recurso.codigo, recurso)
    Archivo.guardar(Archivo.ruta(@archivo), Map.values(recursos), &Recurso.a_linea/1)
    %{estado | recursos: recursos}
  end

  defp movimiento(estado, codigo, tipo, cantidad, detalle) do
    mov = Movimiento.crear(codigo, tipo, cantidad, detalle)
    Archivo.agregar(Archivo.ruta(@archivo_movimientos), Movimiento.a_linea(mov))
    %{estado | movimientos: estado.movimientos ++ [mov]}
  end
end
