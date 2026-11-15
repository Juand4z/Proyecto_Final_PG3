defmodule Persona do

  defstruct [:documento, :nombre, :edad, :zona, :estado, historial: []]

  def crear(documento, nombre, edad, zona, estado) do
    %Persona{
      documento: documento,
      nombre: nombre,
      edad: edad,
      zona: zona,
      estado: estado,
      historial: [{estado, Util.fecha_actual()}]
    }
  end

  def parse(linea) do
    with [documento, nombre, edad_txt, zona, estado, historial_txt] <- Util.campos(linea),
         {:ok, edad} <- Util.texto_a_entero(edad_txt) do
      {:ok,
       %Persona{
         documento: documento,
         nombre: nombre,
         edad: edad,
         zona: zona,
         estado: estado,
         historial: leer_historial(historial_txt)
       }}
    else
      _ -> :error
    end
  end

  def a_linea(p) do
    historial = Enum.map_join(p.historial, ";", fn {estado, fecha} -> estado <> "," <> fecha end)
    Enum.join([p.documento, p.nombre, p.edad, p.zona, p.estado, historial], "@")
  end

  # convierte "estado,fecha;estado,fecha" en [{estado, fecha}, {estado, fecha}]
  defp leer_historial(texto) do
    texto
    |> String.split(";", trim: true)
    |> Enum.map(fn parte ->
      [estado, fecha] = String.split(parte, ",", parts: 2)
      {estado, fecha}
    end)
  end
end
