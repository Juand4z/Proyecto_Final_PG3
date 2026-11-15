defmodule Usuarios do

  use GenServer

  @archivo "usuarios.txt"
  @tipos ["ciudadano", "voluntario", "coordinador", "administrador"]

  @voluntario ["voluntario", "coordinador", "administrador"]
  @coordinador ["coordinador", "administrador"]
  @administrador ["administrador"]


  @permisos %{
    "update_need" => @voluntario,
    "update_person" => @voluntario,
    "mark_message" => @voluntario,
    "register_entry" => @voluntario,
    "register_exit" => @voluntario,
    "confirm_match" => @voluntario,
    "register_zone" => @coordinador,
    "register_sector" => @coordinador,
    "register_point" => @coordinador,
    "set_zone_level" => @coordinador,
    "register_resource" => @coordinador,
    "resource_in" => @coordinador,
    "resource_out" => @coordinador,
    "transfer_resource" => @coordinador,
    "resource_history" => @coordinador,
    "assign_resource" => @coordinador,
    "concurrent_assign" => @coordinador,
    "register_shelter" => @coordinador,
    "activity" => @coordinador,
    "users" => @administrador
  }

  #API

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def conectar(usuario, clave, tipo, zona, nombre) do
    GenServer.call(__MODULE__, {:conectar, usuario, clave, tipo, zona, nombre})
  end

  def desconectar(usuario), do: GenServer.call(__MODULE__, {:desconectar, usuario})


  def sesion(usuario), do: GenServer.call(__MODULE__, {:sesion, usuario})

  def listar(), do: GenServer.call(__MODULE__, :listar)

  def tipos(), do: @tipos

  def puede?(tipo, comando) do
    case Map.get(@permisos, comando) do
      nil -> true
      permitidos -> tipo in permitidos
    end
  end

  #Servidor

  @impl true
  def init(:ok) do
    usuarios =
      Archivo.ruta(@archivo)
      |> Archivo.cargar(&Usuario.parse/1)
      |> Util.convertir_a_mapa_por(:usuario)

    {:ok, %{usuarios: usuarios, conectados: MapSet.new()}}
  end

  @impl true
  def handle_call({:conectar, usuario, clave, tipo, zona, nombre}, _from, estado) do
    case Map.get(estado.usuarios, usuario) do
      # no existe: se registra automaticamente
      nil ->
        with :ok <- Validacion.opcion_valida(tipo, @tipos, :tipo_de_usuario_invalido) do
          nuevo = Usuario.crear(usuario, clave, nombre, tipo, zona)
          usuarios = Map.put(estado.usuarios, usuario, nuevo)
          Archivo.guardar(Archivo.ruta(@archivo), Map.values(usuarios), &Usuario.a_linea/1)

          {:reply, {:ok, :registrado, nuevo},
           %{usuarios: usuarios, conectados: MapSet.put(estado.conectados, usuario)}}
        else
          error -> {:reply, error, estado}
        end

      # existe y la clave coincide (pattern matching con ^clave)
      %Usuario{clave: ^clave} = existente ->
        {:reply, {:ok, :conectado, existente}, %{estado | conectados: MapSet.put(estado.conectados, usuario)}}

      _otro ->
        {:reply, {:error, :clave_incorrecta}, estado}
    end
  end

  def handle_call({:desconectar, usuario}, _from, estado) do
    {:reply, :ok, %{estado | conectados: MapSet.delete(estado.conectados, usuario)}}
  end

  def handle_call({:sesion, usuario}, _from, estado) do
    if MapSet.member?(estado.conectados, usuario) do
      {:reply, {:ok, Map.get(estado.usuarios, usuario)}, estado}
    else
      {:reply, {:error, :sin_sesion}, estado}
    end
  end

  def handle_call(:listar, _from, estado) do
    {:reply, {Map.values(estado.usuarios), MapSet.to_list(estado.conectados)}, estado}
  end
end
