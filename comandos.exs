defmodule Comandos do
  @moduledoc """
  Modulo que interpreta los comandos que escribe el usuario: separa la linea, valida las entradas,
  revisa los permisos segun el tipo de usuario y llama al proceso que corresponde.
  Lo usan tanto el modo local (main.exs) como el nodo servidor (nodo_servidor.exs).
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """

  @usos [
    {"help", "help"},
    {"connect", "connect usuario clave [tipo] [zona] [\"nombre completo\"]"},
    {"disconnect", "disconnect"},
    {"users", "users"},
    {"activity", "activity [usuario]"},
    {"register_zone", "register_zone codigo \"nombre\" nivel [afectados]"},
    {"register_sector", "register_sector zona codigo nivel afectados"},
    {"register_point", "register_point zona sector codigo afectados"},
    {"set_zone_level", "set_zone_level zona nivel"},
    {"list_zones", "list_zones"},
    {"zone_status", "zone_status zona"},
    {"register_need", "register_need tipo cantidad prioridad zona \"descripcion\" [albergue]"},
    {"list_needs", "list_needs [zona=x] [tipo=x] [prioridad=x] [estado=x]"},
    {"pending_needs", "pending_needs"},
    {"next_need", "next_need"},
    {"update_need", "update_need id estado"},
    {"assign_resource", "assign_resource id_necesidad recurso(codigo o nombre) cantidad"},
    {"concurrent_assign", "concurrent_assign recurso id:cantidad id:cantidad ..."},
    {"register_resource", "register_resource codigo nombre cantidad unidad ubicacion [zona] [categoria]"},
    {"list_resources", "list_resources [nombre=x] [zona=x] [ubicacion=x] [categoria=x]"},
    {"resource_in", "resource_in codigo cantidad"},
    {"resource_out", "resource_out codigo cantidad"},
    {"transfer_resource", "transfer_resource codigo origen destino cantidad"},
    {"resource_history", "resource_history codigo"},
    {"critical_resources", "critical_resources"},
    {"report_person", "report_person documento \"nombre\" zona estado [edad]"},
    {"update_person", "update_person documento estado"},
    {"find_person", "find_person documento"},
    {"search_persons", "search_persons [nombre=x] [zona=x] [estado=x]"},
    {"send_family_message", "send_family_message destinatario \"mensaje\""},
    {"list_family_messages", "list_family_messages destinatario"},
    {"mark_message", "mark_message id entregado|pendiente"},
    {"report_pet", "report_pet lost|found especie nombre color tamano zona contacto [\"caracteristicas\"]"},
    {"list_pets", "list_pets [especie=x] [zona=x] [estado=x] [tipo=x]"},
    {"match_pets", "match_pets"},
    {"confirm_match", "confirm_match id_perdida id_encontrada"},
    {"register_shelter", "register_shelter codigo \"nombre\" zona capacidad [ocupacion]"},
    {"check_shelter", "check_shelter codigo"},
    {"register_entry", "register_entry albergue documento"},
    {"register_exit", "register_exit albergue documento"},
    {"shelters_report", "shelters_report"},
    {"summary", "summary"},
    {"exit", "exit"}
  ]

  @doc """
  Funcion principal: procesa una linea escrita por el usuario.

  Retorna: Tupla {texto_respuesta, usuario}, donde usuario es el nombre del usuario conectado
  despues del comando (nil si nadie esta conectado).

  Parametros:
  - 'linea' : texto escrito por el usuario (ej. "register_need agua 30 critica centro \"Punto 3\"").
  - 'usuario' : nombre del usuario conectado o nil.
  """
  def procesar(linea, usuario) do
    case separar(linea) do
      [] -> {"", usuario}
      [comando | argumentos] -> ejecutar_con_permisos(comando, argumentos, usuario, linea)
    end
  end

  @doc """
  Funcion que separa la linea en palabras respetando los textos entre comillas.
  Tambien quita los "@" porque es el separador de los archivos.
  """
  def separar(linea) do
    Regex.scan(~r/"[^"]*"|\S+/, linea)
    |> List.flatten()
    |> Enum.map(fn palabra -> palabra |> String.trim("\"") |> String.replace(["@", "\n", "\r"], " ") end)
  end

  defp ejecutar_con_permisos(comando, argumentos, usuario, linea) do
    if comando in ["help", "connect"] do
      responder(ejecutar(comando, argumentos, usuario), usuario)
    else
      # el resto de comandos necesita una sesion activa y permiso segun el tipo de usuario
      case Usuarios.sesion(usuario) do
        {:error, :sin_sesion} ->
          {"Debe conectarse primero: connect usuario clave [tipo] [zona]", nil}

        {:ok, sesion} ->
          if Usuarios.puede?(sesion.tipo, comando) do
            Bitacora.registrar(sesion.usuario, linea)
            responder(ejecutar(comando, argumentos, sesion), usuario)
          else
            {"Permiso denegado: un #{sesion.tipo} no puede usar '#{comando}'", usuario}
          end
      end
    end
  end

  defp responder({:sesion, texto, nuevo_usuario}, _usuario), do: {texto, nuevo_usuario}
  defp responder({:ok, texto}, usuario), do: {texto, usuario}
  defp responder({:error, motivo}, usuario), do: {"Error: " <> Reportes.error(motivo), usuario}

  #USUARIOS

  defp ejecutar("help", _argumentos, _sesion) do
    {:ok, "Comandos disponibles:\n" <> Enum.map_join(@usos, "\n", fn {_comando, uso} -> "    " <> uso end)}
  end

  defp ejecutar("connect", _argumentos, usuario) when usuario != nil, do: {:error, :ya_hay_una_sesion_activa}

  defp ejecutar("connect", [usuario, clave | resto], nil) when length(resto) <= 3 do
    tipo = Enum.at(resto, 0, "ciudadano")
    zona = Enum.at(resto, 1, "general")
    nombre = Enum.at(resto, 2, usuario)

    case Usuarios.conectar(usuario, clave, tipo, zona, nombre) do
      {:ok, accion, u} ->
        Bitacora.registrar(usuario, "connect")
        saludo = if accion == :registrado, do: "Usuario registrado y conectado", else: "Bienvenido de nuevo"
        {:sesion, "#{saludo}: #{u.nombre} (#{u.tipo}, zona #{u.zona})", u.usuario}

      error ->
        error
    end
  end

  defp ejecutar("disconnect", [], sesion) do
    Usuarios.desconectar(sesion.usuario)
    {:sesion, "Sesion de #{sesion.usuario} cerrada", nil}
  end

  defp ejecutar("users", [], _sesion) do
    {usuarios, conectados} = Usuarios.listar()

    texto =
      Reportes.lista(usuarios, fn u ->
        marca = if u.usuario in conectados, do: " [conectado]", else: ""
        "#{u.usuario} - #{u.nombre} (#{u.tipo}, zona #{u.zona})#{marca}"
      end, "No hay usuarios")

    {:ok, texto}
  end

  defp ejecutar("activity", argumentos, _sesion) when length(argumentos) <= 1 do
    actividades = Bitacora.consultar(List.first(argumentos))
    {:ok, Reportes.lista(actividades, fn {fecha, u, accion} -> "#{fecha} | #{u} | #{accion}" end, "Sin actividad")}
  end

  #ZONAS

  defp ejecutar("register_zone", [codigo, nombre, nivel | resto], _sesion) when length(resto) <= 1 do
    with {:ok, afectados} <- entero_opcional(resto, 0),
         {:ok, zona} <- Zonas.registrar_zona(codigo, nombre, nivel, afectados) do
      {:ok, "Zona registrada:\n" <> Reportes.zona(zona)}
    end
  end

  defp ejecutar("register_sector", [zona, codigo, nivel, afectados_txt], _sesion) do
    with {:ok, afectados} <- entero(afectados_txt),
         {:ok, raiz} <- Zonas.registrar_sector(zona, codigo, nivel, afectados) do
      {:ok, "Sector registrado:\n" <> Reportes.zona(raiz)}
    end
  end

  defp ejecutar("register_point", [zona, sector, codigo, afectados_txt], _sesion) do
    with {:ok, afectados} <- entero(afectados_txt),
         {:ok, raiz} <- Zonas.registrar_punto(zona, sector, codigo, afectados) do
      {:ok, "Punto de atencion registrado:\n" <> Reportes.zona(raiz)}
    end
  end

  defp ejecutar("set_zone_level", [codigo, nivel], _sesion) do
    with {:ok, zona} <- Zonas.cambiar_nivel(codigo, nivel) do
      {:ok, "Nivel de #{zona.codigo} actualizado a #{zona.nivel}"}
    end
  end

  defp ejecutar("list_zones", [], _sesion) do
    {:ok, Reportes.lista(Zonas.listar(), &Reportes.zona/1, "No hay zonas registradas")}
  end

  defp ejecutar("zone_status", [codigo], _sesion) do
    with {:ok, zona} <- Zonas.obtener(codigo) do
      datos = %{
        necesidades: Necesidades.listar(zona: codigo),
        recursos: Recursos.listar(zona: codigo),
        albergues: Enum.filter(Albergues.listar(), fn a -> a.zona == codigo end),
        personas: Personas.buscar_por(zona: codigo),
        mascotas: Mascotas.listar(zona: codigo)
      }

      {:ok, Reportes.estado_zona(zona, datos)}
    end
  end

  #NECESIDADES

  defp ejecutar("register_need", [tipo, cantidad_txt, prioridad, zona, descripcion | resto], sesion)
       when length(resto) <= 1 do
    albergue = List.first(resto, "")

    with {:ok, cantidad} <- entero(cantidad_txt),
         :ok <- albergue_existe(albergue),
         {:ok, necesidad} <-
           Necesidades.registrar(%{
             tipo: tipo,
             cantidad: cantidad,
             prioridad: prioridad,
             zona: zona,
             descripcion: descripcion,
             responsable: sesion.usuario,
             albergue: albergue
           }) do
      {:ok, "Necesidad registrada: " <> Reportes.necesidad(necesidad)}
    end
  end

  defp ejecutar("list_needs", argumentos, _sesion) do
    with {:ok, filtros} <- leer_filtros(argumentos, ["zona", "tipo", "prioridad", "estado"]) do
      {:ok, Reportes.lista(Necesidades.listar(filtros), &Reportes.necesidad/1, "No hay necesidades")}
    end
  end

  defp ejecutar("pending_needs", [], _sesion) do
    {:ok, Reportes.lista(Necesidades.pendientes(), &Reportes.necesidad/1, "No hay necesidades pendientes")}
  end

  defp ejecutar("next_need", [], _sesion) do
    with {:ok, necesidad} <- Necesidades.siguiente() do
      {:ok, "Necesidad mas urgente: " <> Reportes.necesidad(necesidad)}
    end
  end

  defp ejecutar("update_need", [id, estado], _sesion) do
    with {:ok, necesidad} <- Necesidades.cambiar_estado(id, estado) do
      {:ok, "Necesidad actualizada: " <> Reportes.necesidad(necesidad)}
    end
  end

  defp ejecutar("assign_resource", [id, recurso, cantidad_txt], _sesion) do
    with {:ok, cantidad} <- entero(cantidad_txt),
         {:ok, necesidad, rec} <- Necesidades.asignar(id, recurso, cantidad) do
      {:ok,
       "Asignadas #{cantidad} #{rec.unidad} de #{rec.codigo} a #{id}. Quedan #{rec.cantidad} en #{rec.codigo}.\n" <>
         Reportes.necesidad(necesidad)}
    end
  end

  defp ejecutar("concurrent_assign", [recurso | pares], _sesion) when pares != [] do
    with {:ok, solicitudes} <- leer_pares(pares) do
      {:ok, Reportes.asignacion_concurrente(Coordinador.asignar_concurrente(recurso, solicitudes))}
    end
  end

  #RECURSOS

  defp ejecutar("register_resource", [codigo, nombre, cantidad_txt, unidad, ubicacion | resto], sesion)
       when length(resto) <= 2 do
    zona = Enum.at(resto, 0, sesion.zona)
    categoria = Enum.at(resto, 1, nombre)

    with {:ok, cantidad} <- entero(cantidad_txt),
         {:ok, recurso} <- Recursos.registrar(Recurso.crear(codigo, nombre, categoria, cantidad, unidad, ubicacion, zona)) do
      {:ok, "Recurso registrado: " <> Reportes.recurso(recurso)}
    end
  end

  defp ejecutar("list_resources", argumentos, _sesion) do
    with {:ok, filtros} <- leer_filtros(argumentos, ["nombre", "zona", "ubicacion", "categoria"]) do
      recursos = Recursos.listar(filtros)
      total = Enum.reduce(recursos, 0, fn r, acc -> acc + r.cantidad end)
      pie = if filtros != [] and recursos != [], do: "\nTotal disponible: #{total}", else: ""
      {:ok, Reportes.lista(recursos, &Reportes.recurso/1, "No hay recursos") <> pie}
    end
  end

  defp ejecutar("resource_in", [codigo, cantidad_txt], _sesion) do
    with {:ok, cantidad} <- entero(cantidad_txt),
         {:ok, recurso} <- Recursos.entrada(codigo, cantidad) do
      {:ok, "Entrada registrada: " <> Reportes.recurso(recurso)}
    end
  end

  defp ejecutar("resource_out", [codigo, cantidad_txt], _sesion) do
    with {:ok, cantidad} <- entero(cantidad_txt),
         {:ok, recurso} <- Recursos.salida(codigo, cantidad) do
      {:ok, "Salida registrada: " <> Reportes.recurso(recurso)}
    end
  end

  defp ejecutar("transfer_resource", [codigo, origen, destino, cantidad_txt], _sesion) do
    with {:ok, cantidad} <- entero(cantidad_txt),
         {:ok, de, a} <- Recursos.transferir(codigo, origen, destino, cantidad) do
      {:ok, "Transferencia realizada:\n    Origen:  #{Reportes.recurso(de)}\n    Destino: #{Reportes.recurso(a)}"}
    end
  end

  defp ejecutar("resource_history", [codigo], _sesion) do
    {:ok, Reportes.lista(Recursos.historial(codigo), &Reportes.movimiento/1, "Sin movimientos para #{codigo}")}
  end

  defp ejecutar("critical_resources", [], _sesion) do
    vacio = "No hay recursos por debajo de #{Recursos.umbral_critico()} unidades"
    {:ok, Reportes.lista(Recursos.criticos(), &Reportes.recurso/1, vacio)}
  end

  #PERSONAS Y MENSAJES

  defp ejecutar("report_person", [documento, nombre, zona, estado | resto], _sesion) when length(resto) <= 1 do
    with {:ok, edad} <- entero_opcional(resto, 0),
         {:ok, persona} <- Personas.registrar(documento, nombre, edad, zona, estado) do
      {:ok, "Persona registrada: " <> Reportes.persona(persona)}
    end
  end

  defp ejecutar("update_person", [documento, estado], _sesion) do
    with {:ok, persona} <- Personas.cambiar_estado(documento, estado) do
      {:ok, "Persona actualizada: " <> Reportes.persona(persona)}
    end
  end

  defp ejecutar("find_person", [documento], _sesion) do
    with {:ok, persona} <- Personas.buscar(documento) do
      historial = Enum.map_join(persona.historial, "\n", fn {estado, fecha} -> "        #{fecha} -> #{estado}" end)

      {:ok,
       Reportes.persona(persona) <>
         "\n    Historial:\n" <> historial <> "\n    Mensajes recibidos: #{length(Mensajes.listar(documento))}"}
    end
  end

  defp ejecutar("search_persons", argumentos, _sesion) do
    with {:ok, filtros} <- leer_filtros(argumentos, ["nombre", "zona", "estado", "documento"]) do
      {:ok, Reportes.lista(Personas.buscar_por(filtros), &Reportes.persona/1, "No se encontraron personas")}
    end
  end

  defp ejecutar("send_family_message", [destinatario, contenido], sesion) do
    with {:ok, mensaje} <- Mensajes.enviar(sesion.usuario, destinatario, contenido) do
      {:ok, "Mensaje enviado: " <> Reportes.mensaje(mensaje)}
    end
  end

  defp ejecutar("list_family_messages", [destinatario], _sesion) do
    {:ok, Reportes.lista(Mensajes.listar(destinatario), &Reportes.mensaje/1, "No hay mensajes para #{destinatario}")}
  end

  defp ejecutar("mark_message", [id, estado], _sesion) do
    with {:ok, mensaje} <- Mensajes.marcar(id, estado) do
      {:ok, "Mensaje actualizado: " <> Reportes.mensaje(mensaje)}
    end
  end

  #MASCOTAS

  defp ejecutar("report_pet", [tipo, especie, nombre, color, tamano, zona, contacto | resto], _sesion)
       when length(resto) <= 1 do
    datos = %{
      tipo: tipo_reporte(tipo),
      especie: especie,
      nombre: nombre,
      color: color,
      tamano: tamano,
      zona: zona,
      contacto: contacto,
      caracteristicas: List.first(resto, "")
    }

    with {:ok, reporte} <- Mascotas.reportar(datos) do
      {:ok, "Reporte registrado: " <> Reportes.mascota(reporte)}
    end
  end

  defp ejecutar("list_pets", argumentos, _sesion) do
    with {:ok, filtros} <- leer_filtros(argumentos, ["especie", "zona", "estado", "tipo"]) do
      {:ok, Reportes.lista(Mascotas.listar(filtros), &Reportes.mascota/1, "No hay reportes de mascotas")}
    end
  end

  defp ejecutar("match_pets", [], _sesion) do
    vacio = "No se encontraron posibles coincidencias"
    {:ok, Reportes.lista(Mascotas.buscar_coincidencias(), &Reportes.coincidencia/1, vacio)}
  end

  defp ejecutar("confirm_match", [id_perdida, id_encontrada], _sesion) do
    with {:ok, perdida, encontrada} <- Mascotas.confirmar(id_perdida, id_encontrada) do
      {:ok,
       "Coincidencia confirmada. Reportes cerrados:\n    #{Reportes.mascota(perdida)}\n    #{Reportes.mascota(encontrada)}"}
    end
  end

  #ALBERGUES

  defp ejecutar("register_shelter", [codigo, nombre, zona, capacidad_txt | resto], _sesion) when length(resto) <= 1 do
    with {:ok, capacidad} <- entero(capacidad_txt),
         {:ok, ocupacion} <- entero_opcional(resto, 0),
         {:ok, albergue} <- Albergues.registrar(codigo, nombre, zona, capacidad, ocupacion) do
      {:ok, "Albergue registrado: " <> Reportes.albergue(albergue)}
    end
  end

  defp ejecutar("check_shelter", [codigo], _sesion) do
    with {:ok, albergue} <- Albergues.consultar(codigo) do
      {:ok, Reportes.estado_albergue(albergue, Recursos.listar(ubicacion: codigo), Necesidades.listar(albergue: codigo))}
    end
  end

  defp ejecutar("register_entry", [codigo, documento], _sesion) do
    with {:ok, albergue} <- Albergues.ingreso(codigo, documento) do
      {:ok, "Ingreso registrado: " <> Reportes.albergue(albergue)}
    end
  end

  defp ejecutar("register_exit", [codigo, documento], _sesion) do
    with {:ok, albergue} <- Albergues.salida(codigo, documento) do
      {:ok, "Salida registrada: " <> Reportes.albergue(albergue)}
    end
  end

  defp ejecutar("shelters_report", [], _sesion) do
    {:ok, Reportes.lista(Albergues.reporte_ocupacion(), &Reportes.albergue/1, "No hay albergues registrados")}
  end

  #RESUMEN

  defp ejecutar("summary", [], _sesion) do
    datos = %{
      zonas: Zonas.listar(),
      recursos: Recursos.listar(),
      pendientes: Necesidades.pendientes(),
      personas: Personas.listar(),
      mensajes: Mensajes.listar(),
      mascotas: Mascotas.listar(),
      albergues: Albergues.listar()
    }

    {:ok, Reportes.resumen(datos)}
  end

  # cualquier otro caso: comando conocido con parametros incorrectos o comando desconocido
  defp ejecutar(comando, _argumentos, _sesion) do
    case List.keyfind(@usos, comando, 0) do
      {_comando, uso} -> {:error, "parametros incorrectos. Uso: " <> uso}
      nil -> {:error, "comando desconocido '#{comando}'. Escriba help para ver los comandos"}
    end
  end

  #AUXILIARES

  # convierte el texto en entero usando Util, si falla retorna un error controlado
  defp entero(texto) do
    case Util.texto_a_entero(texto) do
      {:ok, numero} -> {:ok, numero}
      :error -> {:error, "'#{texto}' no es un numero entero"}
    end
  end

  defp entero_opcional([], por_defecto), do: {:ok, por_defecto}
  defp entero_opcional([texto], _por_defecto), do: entero(texto)

  defp albergue_existe(""), do: :ok

  defp albergue_existe(codigo) do
    case Albergues.consultar(codigo) do
      {:ok, _albergue} -> :ok
      error -> error
    end
  end

  defp tipo_reporte(tipo) when tipo in ["lost", "perdida"], do: "perdida"
  defp tipo_reporte(tipo) when tipo in ["found", "encontrada"], do: "encontrada"
  defp tipo_reporte(tipo), do: tipo

  # convierte ["zona=centro", "prioridad=critica"] en [zona: "centro", prioridad: "critica"]
  defp leer_filtros(argumentos, permitidos) do
    pares = Enum.map(argumentos, fn argumento -> String.split(argumento, "=", parts: 2) end)

    if Enum.all?(pares, fn par -> match?([_, _], par) and hd(par) in permitidos end) do
      {:ok, Enum.map(pares, fn [campo, valor] -> {String.to_atom(campo), valor} end)}
    else
      {:error, "filtros validos: " <> Enum.map_join(permitidos, ", ", fn p -> p <> "=valor" end)}
    end
  end

  # funcion recursiva que convierte ["N001:30", "N002:25"] en [{"N001", 30}, {"N002", 25}]
  defp leer_pares([]), do: {:ok, []}

  defp leer_pares([texto | resto]) do
    with [id, cantidad_txt] <- String.split(texto, ":"),
         {:ok, cantidad} <- Util.texto_a_entero(cantidad_txt),
         {:ok, otros} <- leer_pares(resto) do
      {:ok, [{id, cantidad} | otros]}
    else
      {:error, motivo} -> {:error, motivo}
      _ -> {:error, "formato invalido '#{texto}', use id:cantidad"}
    end
  end
end
