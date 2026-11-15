defmodule Mensajes do

  use GenServer

  @archivo "mensajes.txt"
  @estados ["pendiente", "entregado"]

  #API

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def enviar(remitente, destinatario, contenido) do
    GenServer.call(__MODULE__, {:enviar, remitente, destinatario, contenido})
  end

  @doc "Funcion que lista los mensajes de un destinatario, si es nil lista todos."
  def listar(destinatario \\ nil), do: GenServer.call(__MODULE__, {:listar, destinatario})

  def marcar(id, estado), do: GenServer.call(__MODULE__, {:marcar, id, estado})

  #Servidor

  @impl true
  def init(:ok) do
    mensajes =
      Archivo.ruta(@archivo)
      |> Archivo.cargar(&Mensaje.parse/1)
      |> Util.convertir_a_mapa_por(:id)

    {:ok, mensajes}
  end

  @impl true
  def handle_call({:enviar, remitente, destinatario, contenido}, _from, mensajes) do
    if String.trim(contenido) == "" do
      {:reply, {:error, :mensaje_vacio}, mensajes}
    else
      mensaje = Mensaje.crear(Util.nuevo_id("M", mensajes), remitente, destinatario, contenido)
      {:reply, {:ok, mensaje}, poner(mensajes, mensaje)}
    end
  end

  def handle_call({:listar, destinatario}, _from, mensajes) do
    lista =
      mensajes
      |> Map.values()
      |> Enum.filter(fn mensaje -> destinatario == nil or mensaje.destinatario == destinatario end)
      |> Enum.sort_by(fn mensaje -> mensaje.id end)

    {:reply, lista, mensajes}
  end

  def handle_call({:marcar, id, estado}, _from, mensajes) do
    with :ok <- Validacion.opcion_valida(estado, @estados, :estado_invalido),
         {:ok, mensaje} <- Validacion.buscar(mensajes, id, :mensaje_no_existe),
         :ok <- estado_diferente(mensaje, estado) do
      actualizado = %{mensaje | estado: estado}
      {:reply, {:ok, actualizado}, poner(mensajes, actualizado)}
    else
      error -> {:reply, error, mensajes}
    end
  end

  #Privadas

  defp estado_diferente(%Mensaje{estado: estado}, estado), do: {:error, :mensaje_ya_tiene_ese_estado}
  defp estado_diferente(_mensaje, _estado), do: :ok

  defp poner(mensajes, mensaje) do
    mensajes = Map.put(mensajes, mensaje.id, mensaje)
    Archivo.guardar(Archivo.ruta(@archivo), Map.values(mensajes), &Mensaje.a_linea/1)
    mensajes
  end
end
