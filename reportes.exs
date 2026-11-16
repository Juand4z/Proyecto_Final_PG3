defmodule Reportes do
  @moduledoc """
  Modulo que arma los textos que se le muestran al usuario: una linea por cada elemento
  (necesidad, recurso, persona, mensaje, mascota, albergue) y los reportes del sistema
  (resumen global, estado de una zona, comprobante de albergue, recursos criticos).
  Todas las funciones son puras: reciben datos y retornan un String.
  - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
  - Fecha: Noviembre 2026
  - Licencia: GNU GPL v3
  """

  #Una linea por elemento

  def necesidad(n) do
    albergue = if n.albergue != "", do: " | albergue #{n.albergue}", else: ""

    "#{n.id} [#{n.prioridad}] #{n.tipo} #{n.asignado}/#{n.cantidad} | zona #{n.zona} | #{n.estado} | por #{n.responsable}#{albergue} | #{n.descripcion}"
  end

  def recurso(r) do
    "#{r.codigo} #{r.nombre}: #{r.cantidad} #{r.unidad} | categoria #{r.categoria} | en #{r.ubicacion} | zona #{r.zona}"
  end

  def persona(p), do: "#{p.documento} #{p.nombre} (#{p.edad} anos) | zona #{p.zona} | #{p.estado}"

  def mensaje(m), do: "#{m.id} [#{m.estado}] #{m.fecha} de #{m.remitente} para #{m.destinatario}: #{m.contenido}"

  def mascota(m) do
    pareja = if m.pareja != "", do: " (pareja #{m.pareja})", else: ""

    "#{m.id} #{m.tipo} | #{m.especie} '#{m.nombre}' #{m.color} #{m.tamano} | zona #{m.zona} | contacto #{m.contacto} | #{m.estado}#{pareja}"
  end

  def albergue(a) do
    "#{a.codigo} #{a.nombre} | zona #{a.zona} | ocupacion #{a.ocupacion}/#{a.capacidad} (#{Util.formater(Albergue.porcentaje(a))}%) | cupos: #{Albergue.cupos(a)}"
  end

  def movimiento(m), do: "#{m.fecha} | #{m.tipo} | #{m.cantidad} | #{m.detalle}"

  def zona(z), do: z |> Zona.a_texto() |> Enum.join("\n")

  def coincidencia({perdida, encontrada, puntos}) do
    "Puntaje #{puntos}: perdida #{perdida.id} ('#{perdida.nombre}') <-> encontrada #{encontrada.id} | #{perdida.especie} #{perdida.color} #{perdida.tamano} | contactos: #{perdida.contacto} / #{encontrada.contacto}"
  end

  @doc """
  Funcion que convierte una lista de elementos en un texto, una linea por elemento.

  Retorna: El texto con las lineas o el mensaje 'vacio' si la lista no tiene elementos.

  Parametros:
  - 'lista' : lista de elementos.
  - 'formato' : funcion que convierte un elemento en texto (ej. &Reportes.recurso/1).
  - 'vacio' : texto que se muestra si la lista esta vacia.
  """
  def lista([], _formato, vacio), do: vacio
  def lista(elementos, formato, _vacio), do: Enum.map_join(elementos, "\n", formato)

  @doc "Funcion que convierte un motivo de error (atomo) en texto, ej. :inventario_insuficiente -> \"inventario insuficiente\"."
  def error(motivo) when is_atom(motivo), do: motivo |> Atom.to_string() |> String.replace("_", " ")
  def error(motivo), do: motivo

  #Reportes del sistema

  @doc """
  Funcion que genera el reporte del estado de una zona, con su arbol y lo que tiene asociado.

  Parametros:
  - 'zona' : struct Zona (raiz del arbol).
  - 'datos' : mapa con las listas de necesidades, recursos, albergues, personas y mascotas de la zona.
  """
  def estado_zona(zona, datos) do
    sin_atender = Enum.count(datos.necesidades, fn n -> n.estado in ["pendiente", "asignada", "en_atencion"] end)

    "\n----------ZONA #{zona.codigo}----------\n" <>
      "#{zona.nombre} - nivel #{zona.nivel}\n" <>
      "#{zona(zona)}\n" <>
      "Afectados acumulados (zona + sectores + puntos): #{Zona.total_afectados(zona)}\n" <>
      "Necesidades: #{length(datos.necesidades)} (#{sin_atender} sin atender)\n" <>
      "Recursos: #{length(datos.recursos)} registros con #{sumar(datos.recursos, :cantidad)} unidades\n" <>
      "Albergues: #{length(datos.albergues)} con #{sumar(datos.albergues, :ocupacion)} personas alojadas\n" <>
      "Personas reportadas: #{length(datos.personas)}\n" <>
      "Reportes de mascotas: #{length(datos.mascotas)}"
  end

  @doc "Funcion que genera el reporte de un albergue con sus personas, recursos y necesidades."
  def estado_albergue(albergue, recursos, necesidades) do
    personas = albergue.personas |> MapSet.to_list() |> Enum.join(", ")

    "\n----------ALBERGUE #{albergue.codigo}----------\n" <>
      "#{albergue(albergue)}\n" <>
      "Personas registradas: #{if personas == "", do: "ninguna", else: personas}\n" <>
      "Recursos en el albergue:\n#{lista(recursos, fn r -> "    " <> recurso(r) end, "    ninguno")}\n" <>
      "Necesidades del albergue:\n#{lista(necesidades, fn n -> "    " <> necesidad(n) end, "    ninguna")}"
  end

  @doc """
  Funcion que genera el resumen global: recursos restantes, necesidades pendientes, personas localizadas,
  mensajes y reportes de mascotas.

  Parametros:
  - 'datos' : mapa con las listas de zonas, recursos, pendientes, personas, mensajes, mascotas y albergues.
  """
  def resumen(datos) do
    localizadas =
      Enum.count(datos.personas, fn p -> p.estado in ["localizada", "trasladada", "en_albergue", "reunificada"] end)

    afectados = Enum.reduce(datos.zonas, 0, fn zona, total -> total + Zona.total_afectados(zona) end)
    mensajes_pendientes = Enum.count(datos.mensajes, fn m -> m.estado == "pendiente" end)

    "\n----------RESUMEN GLOBAL----------\n" <>
      "Zonas: #{length(datos.zonas)} | afectados estimados: #{afectados}\n" <>
      "Recursos restantes:\n#{lista(datos.recursos, fn r -> "    " <> recurso(r) end, "    ninguno")}\n" <>
      "Necesidades sin atender: #{length(datos.pendientes)} (#{contar_por(datos.pendientes, :prioridad)})\n" <>
      "Personas reportadas: #{length(datos.personas)} | localizadas: #{localizadas}\n" <>
      "Mensajes: #{length(datos.mensajes)} | pendientes de entrega: #{mensajes_pendientes}\n" <>
      "Mascotas: #{length(datos.mascotas)} (#{contar_por(datos.mascotas, :estado)})\n" <>
      "Albergues: #{length(datos.albergues)} | ocupacion #{sumar(datos.albergues, :ocupacion)}/#{sumar(datos.albergues, :capacidad)}\n" <>
      "----------------------------------"
  end

  @doc "Funcion que genera el reporte de las asignaciones simultaneas del Coordinador."
  def asignacion_concurrente(resultados) do
    lineas =
      Enum.map(resultados, fn
        {id, cantidad, {:ok, _necesidad, rec}} -> "    #{id} pidio #{cantidad}: CONFIRMADO (quedan #{rec.cantidad} en #{rec.codigo})"
        {id, cantidad, {:error, motivo}} -> "    #{id} pidio #{cantidad}: RECHAZADO (#{error(motivo)})"
      end)

    "\n----------ASIGNACION SIMULTANEA----------\n" <> Enum.join(lineas, "\n")
  end

  #Privadas

  # funcion recursiva que suma un campo numerico de una lista de structs
  defp sumar([], _campo), do: 0
  defp sumar([cabeza | cola], campo), do: Map.get(cabeza, campo) + sumar(cola, campo)

  # cuenta cuantos elementos hay por cada valor de un campo, ej. "critica: 2, alta: 1"
  defp contar_por([], _campo), do: "ninguno"

  defp contar_por(lista, campo) do
    lista
    |> Enum.frequencies_by(fn elemento -> Map.get(elemento, campo) end)
    |> Enum.map_join(", ", fn {valor, cantidad} -> "#{valor}: #{cantidad}" end)
  end
end
