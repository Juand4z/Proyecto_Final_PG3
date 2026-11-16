# Pruebas del sistema con ExUnit (sin Mix).
# Ejecutar despues de compilar los modulos:  elixir pruebas.exs
# Las pruebas usan la carpeta "pruebas-resources" para no tocar los datos reales de nodo-servidor/resources.
# - Autores: Luis Miguel Garcia Villanueva, Juan David Arias Sanchez.
# - Fecha: Noviembre 2026
# - Licencia: GNU GPL v3

Application.put_env(:emergencias, :carpeta_datos, "pruebas-resources")
File.rm_rf!("pruebas-resources")
{:ok, _supervisor} = Sistema.iniciar()

# autorun: false -> las pruebas se ejecutan al final de este archivo con ExUnit.run(),
# mientras el Supervisor sigue vivo
ExUnit.start(autorun: false)

defmodule PruebasFuncionesPuras do
  use ExUnit.Case

  test "Util.filtrar aplica varios filtros de forma recursiva" do
    lista = [%{zona: "centro", tipo: "agua"}, %{zona: "centro", tipo: "alimentos"}, %{zona: "norte", tipo: "agua"}]
    assert Util.filtrar(lista, zona: "centro", tipo: "agua") == [%{zona: "centro", tipo: "agua"}]
    assert length(Util.filtrar(lista, [])) == 3
  end

  test "Util.texto_a_entero y Util.campos no lanzan errores" do
    assert Util.texto_a_entero(" 25 ") == {:ok, 25}
    assert Util.texto_a_entero("diez") == :error
    assert Util.campos("R001 @ agua@50") == ["R001", "agua", "50"]
  end

  test "parse de un struct: linea valida y linea mal formada" do
    assert {:ok, %Recurso{codigo: "R001", cantidad: 50}} =
             Recurso.parse("R001@agua@agua@50@litros@centro_acopio_1@centro")

    assert Recurso.parse("R001@agua@agua@cincuenta@litros@acopio@centro") == :error
    assert Recurso.parse("R001@agua") == :error
  end

  test "Archivo.leer_con_rechazos cuenta las lineas rechazadas (recursiva)" do
    ruta = "pruebas-resources/lectura.txt"
    File.mkdir_p!("pruebas-resources")
    File.write!(ruta, "R1@agua@agua@5@l@a@z\nmala\nR2@arroz@comida@3@kg@a@z\n")
    assert {:ok, [%Recurso{codigo: "R1"}, %Recurso{codigo: "R2"}], 1} = Archivo.leer_con_rechazos(ruta, &Recurso.parse/1)
    assert {:error, _ruta} = Archivo.leer_con_rechazos("no_existe.txt", &Recurso.parse/1)
  end

  test "arbol de zona: insertar, total acumulado, texto y aplanar (recursivas)" do
    zona = Zona.crear("centro", "Centro", "alto", 10)
    {:ok, zona} = Zona.insertar(zona, [], Zona.crear("s1", "s1", "medio", 20))
    {:ok, zona} = Zona.insertar(zona, ["s1"], Zona.crear("p1", "p1", "-", 5))

    assert Zona.total_afectados(zona) == 35
    assert length(Zona.a_texto(zona)) == 3
    assert Zona.aplanar(zona) == ["centro@Centro@alto@10", "centro/s1@s1@medio@20", "centro/s1/p1@p1@-@5"]
    assert {:error, :zona_no_existe} = Zona.insertar(zona, ["x"], Zona.crear("y", "y", "-", 1))
    assert {:error, :id_repetido} = Zona.insertar(zona, [], Zona.crear("s1", "s1", "-", 1))
  end

  test "puntaje y coincidencias de mascotas" do
    perdida = %{especie: "perro", zona: "norte", color: "negra", tamano: "mediana"}
    igual = %{especie: "perro", zona: "norte", color: "negra", tamano: "mediana"}
    otro_color = %{igual | color: "blanca"}
    gato = %{igual | especie: "gato"}

    assert Mascotas.puntaje(perdida, igual) == 100
    assert Mascotas.puntaje(perdida, otro_color) == 80
    assert Mascotas.puntaje(perdida, gato) == 0
    assert length(Mascotas.coincidencias([perdida], [igual, otro_color, gato])) == 2
  end

  test "las necesidades se ordenan por prioridad" do
    lista = [%{id: "N1", prioridad: "baja"}, %{id: "N2", prioridad: "critica"}, %{id: "N3", prioridad: "media"}]
    assert Enum.map(Necesidades.ordenar_por_prioridad(lista), fn n -> n.id end) == ["N2", "N3", "N1"]
  end

  test "validaciones y permisos por tipo de usuario" do
    assert Validacion.transicion_valida("pendiente", "asignada", %{"pendiente" => ["asignada"]}) == :ok
    assert Validacion.cantidad_positiva(-3) == {:error, :cantidad_invalida}
    assert Usuarios.puede?("ciudadano", "report_person")
    refute Usuarios.puede?("ciudadano", "assign_resource")
    refute Usuarios.puede?("coordinador", "users")
  end

  test "separar respeta los textos entre comillas" do
    assert Comandos.separar(~s(register_shelter A01 "Albergue Norte" zona_norte 150)) ==
             ["register_shelter", "A01", "Albergue Norte", "zona_norte", "150"]
  end
end

defmodule PruebasConcurrencia do
  use ExUnit.Case

  defp necesidad(cantidad) do
    datos = %{tipo: "agua", cantidad: cantidad, prioridad: "critica", zona: "centro", descripcion: "prueba", responsable: "t", albergue: ""}
    {:ok, necesidad} = Necesidades.registrar(datos)
    necesidad.id
  end

  test "dos solicitudes simultaneas de 30 y 25 sobre 50 litros: solo una se confirma" do
    {:ok, _} = Recursos.registrar(Recurso.crear("C001", "agua_c1", "agua", 50, "litros", "acopio", "centro"))
    n1 = necesidad(30)
    n2 = necesidad(25)

    resultados = Coordinador.asignar_concurrente("C001", [{n1, 30}, {n2, 25}])
    confirmadas = Enum.filter(resultados, fn {_id, _cantidad, resultado} -> elem(resultado, 0) == :ok end)

    assert length(confirmadas) == 1
    assert [%Recurso{cantidad: restante}] = Recursos.listar(codigo: "C001")
    assert restante in [20, 25]
  end

  test "20 procesos piden 10 unidades de un recurso con 100: solo 10 lo logran" do
    {:ok, _} = Recursos.registrar(Recurso.crear("C002", "agua_c2", "agua", 100, "litros", "acopio", "centro"))
    yo = self()

    Enum.each(1..20, fn _ -> spawn(fn -> send(yo, Recursos.tomar("C002", 10, "prueba")) end) end)
    resultados = Enum.map(1..20, fn _ -> receive do: (resultado -> resultado) end)

    assert Enum.count(resultados, fn r -> match?({:ok, _}, r) end) == 10
    assert [%Recurso{cantidad: 0}] = Recursos.listar(codigo: "C002")
  end

  test "ingresos simultaneos a un albergue no superan la capacidad" do
    {:ok, _} = Albergues.registrar("CA1", "Albergue prueba", "norte", 5)
    yo = self()

    Enum.each(1..20, fn i -> spawn(fn -> send(yo, Albergues.ingreso("CA1", "doc#{i}")) end) end)
    resultados = Enum.map(1..20, fn _ -> receive do: (resultado -> resultado) end)

    assert Enum.count(resultados, fn r -> match?({:ok, _}, r) end) == 5
    assert {:ok, %Albergue{ocupacion: 5}} = Albergues.consultar("CA1")
  end
end

defmodule PruebasDominio do
  use ExUnit.Case

  test "connect registra un usuario nuevo y valida la clave despues" do
    assert {:ok, :registrado, _} = Usuarios.conectar("ana", "1", "voluntario", "norte", "Ana")
    assert {:ok, :conectado, %Usuario{tipo: "voluntario"}} = Usuarios.conectar("ana", "1", "", "", "")
    assert {:error, :clave_incorrecta} = Usuarios.conectar("ana", "otra", "", "", "")
    assert {:error, :tipo_de_usuario_invalido} = Usuarios.conectar("beto", "1", "jefe", "norte", "Beto")
  end

  test "recursos: no se repiten codigos ni quedan cantidades negativas" do
    recurso = Recurso.crear("D001", "arroz", "alimentos", 10, "kg", "acopio", "centro")
    assert {:ok, _} = Recursos.registrar(recurso)
    assert {:error, :id_repetido} = Recursos.registrar(recurso)
    assert {:error, :cantidad_negativa} = Recursos.registrar(%{recurso | codigo: "D002", cantidad: -1})
    assert {:error, :inventario_insuficiente} = Recursos.salida("D001", 11)
    assert {:ok, _, %Recurso{codigo: "D001-albergue_x", cantidad: 4}} = Recursos.transferir("D001", "acopio", "albergue_x", 4)
    assert length(Recursos.historial("D001")) == 2
  end

  test "una necesidad atendida no vuelve a consumir recursos ni se cierra dos veces" do
    {:ok, _} = Recursos.registrar(Recurso.crear("D010", "suero", "medicamentos", 10, "und", "acopio", "centro"))
    datos = %{tipo: "medicamentos", cantidad: 5, prioridad: "alta", zona: "centro", descripcion: "x", responsable: "t", albergue: ""}
    {:ok, n} = Necesidades.registrar(datos)

    assert {:error, :cantidad_mayor_a_la_requerida} = Necesidades.asignar(n.id, "D010", 6)
    assert {:ok, %Necesidad{estado: "asignada"}, %Recurso{cantidad: 5}} = Necesidades.asignar(n.id, "D010", 5)
    assert {:ok, _} = Necesidades.cambiar_estado(n.id, "en_atencion")
    assert {:ok, _} = Necesidades.cambiar_estado(n.id, "atendida")
    assert {:error, :transicion_invalida} = Necesidades.cambiar_estado(n.id, "atendida")
    assert {:error, :necesidad_cerrada} = Necesidades.asignar(n.id, "D010", 1)
  end

  test "personas: historial de estados y transiciones validas" do
    assert {:ok, _} = Personas.registrar("D100", "Andres", 30, "norte", "reportada")
    assert {:error, :id_repetido} = Personas.registrar("D100", "Otro", 1, "norte", "reportada")
    assert {:ok, _} = Personas.cambiar_estado("D100", "localizada")
    assert {:ok, _} = Personas.cambiar_estado("D100", "reunificada")
    assert {:error, :transicion_invalida} = Personas.cambiar_estado("D100", "localizada")
    assert {:ok, %Persona{historial: historial}} = Personas.buscar("D100")
    assert Enum.map(historial, fn {estado, _fecha} -> estado end) == ["reportada", "localizada", "reunificada"]
    assert [%Persona{documento: "D100"}] = Personas.buscar_por(nombre: "andr")
  end

  test "mensajes a familiares" do
    {:ok, m} = Mensajes.enviar("laura", "D200", "Estoy bien")
    assert {:ok, %Mensaje{estado: "entregado"}} = Mensajes.marcar(m.id, "entregado")
    assert {:error, :mensaje_ya_tiene_ese_estado} = Mensajes.marcar(m.id, "entregado")
    assert {:error, :mensaje_vacio} = Mensajes.enviar("laura", "D200", "  ")
  end

  test "mascotas: un reporte resuelto no se resuelve dos veces" do
    base = %{especie: "perro", nombre: "Luna", color: "negra", tamano: "mediana", zona: "zona_m", contacto: "300", caracteristicas: ""}
    {:ok, p} = Mascotas.reportar(Map.put(base, :tipo, "perdida"))
    {:ok, e} = Mascotas.reportar(Map.put(base, :tipo, "encontrada"))

    assert Enum.any?(Mascotas.buscar_coincidencias(), fn {a, b, _} -> a.id == p.id and b.id == e.id end)
    assert {:ok, %Mascota{estado: "resuelta"}, %Mascota{estado: "resuelta"}} = Mascotas.confirmar(p.id, e.id)
    assert {:error, :reporte_ya_resuelto} = Mascotas.confirmar(p.id, e.id)
  end

  test "albergues: capacidad, ingreso y salida" do
    assert {:error, :cantidad_invalida} = Albergues.registrar("D300", "A", "norte", -5)
    assert {:ok, _} = Albergues.registrar("D300", "A", "norte", 1)
    assert {:ok, _} = Albergues.ingreso("D300", "p1")
    assert {:error, :capacidad_superada} = Albergues.ingreso("D300", "p2")
    assert {:ok, %Albergue{ocupacion: 0}} = Albergues.salida("D300", "p1")
    assert {:error, :persona_no_esta_en_el_albergue} = Albergues.salida("D300", "p1")
  end

  test "el supervisor reinicia un proceso caido y este recupera sus datos del archivo" do
    {:ok, _} = Albergues.registrar("D400", "Albergue Sur", "sur", 10)
    pid_anterior = Process.whereis(Albergues)

    Process.exit(pid_anterior, :kill)
    Process.sleep(100)

    assert Process.whereis(Albergues) != pid_anterior
    assert {:ok, %Albergue{nombre: "Albergue Sur"}} = Albergues.consultar("D400")
  end

  test "flujo por comandos con permisos por rol" do
    {_, usuario} = Comandos.procesar("connect ciudadano1 x ciudadano centro", nil)
    {texto, _} = Comandos.procesar("register_resource Z1 agua 5 litros a", usuario)
    assert texto =~ "Permiso denegado"

    {_, nil} = Comandos.procesar("disconnect", usuario)
    {texto, _} = Comandos.procesar("summary", nil)
    assert texto =~ "Debe conectarse"

    {_, usuario} = Comandos.procesar("connect coord1 x coordinador centro", nil)
    {texto, _} = Comandos.procesar("register_resource Z1 agua 5 litros a", usuario)
    assert texto =~ "Recurso registrado"
    {texto, _} = Comandos.procesar("summary", usuario)
    assert texto =~ "RESUMEN GLOBAL"
  end
end

ExUnit.run()
# al terminar se borra la carpeta de datos de prueba
File.rm_rf!("pruebas-resources")
