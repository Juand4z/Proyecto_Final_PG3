# Proyecto Final — Programación III (Elixir)

**Universidad del Quindío** · Programa de Ingeniería de Sistemas y Computación

Sistema Distribuido de Coordinación y Gestión de Emergencias, para la atención posterior a un terremoto. Permite registrar y consultar zonas afectadas, necesidades, recursos, albergues, personas afectadas, mensajes entre familiares y mascotas perdidas o encontradas. Usa **programación funcional**, **recursividad**, **concurrencia** (`spawn`, `send`, `receive`), **GenServer**, **Supervisor**, **persistencia en archivos de texto** y **comunicación entre nodos**.

- **Modo local:** un solo computador, para probar todos los comandos rápidamente.
- **Modo distribuido:** un nodo servidor y varios nodos cliente (un usuario por cliente) trabajando al mismo tiempo.

---

## Requisitos

- Elixir 1.14 o superior (verificar con `elixir --version`).
- Para el modo distribuido: una terminal para el servidor y una por cada cliente.

---

## Estructura del repositorio

```
Proyecto_Claudio_2.0/
├── README.md
├── LICENSE
├── Util.ex                  # Módulo Util del curso + funciones agregadas por el equipo
│
├── usuario.ex               # Struct Usuario + parse/1
├── zona.ex                  # Struct Zona (árbol zona -> sector -> punto) + funciones recursivas
├── necesidad.ex             # Struct Necesidad + parse/1
├── recurso.ex               # Struct Recurso + parse/1
├── movimiento.ex            # Struct Movimiento (historial de inventario) + parse/1
├── persona.ex               # Struct Persona (con historial de estados) + parse/1
├── mensaje.ex               # Struct Mensaje + parse/1
├── mascota.ex               # Struct Mascota + parse/1
├── albergue.ex              # Struct Albergue (personas en un MapSet) + parse/1
│
├── validaciones.exs         # Reglas de validación compartidas
├── archivo.exs              # Lectura (recursiva) y escritura de archivos de texto
├── usuarios.exs             # GenServer de usuarios y permisos
├── zonas.exs                # GenServer de zonas
├── necesidades.exs          # GenServer de necesidades
├── recursos.exs             # GenServer de recursos (regla de concurrencia)
├── personas.exs             # GenServer de personas afectadas
├── mensajes.exs             # GenServer de mensajes entre familiares
├── mascotas.exs             # GenServer de mascotas y coincidencias
├── albergues.exs            # GenServer de albergues
├── bitacora.exs             # Proceso spawn + receive que registra la actividad
├── coordinador.exs          # Asignaciones simultáneas con spawn (conflicto concurrente)
├── sistema.exs              # Supervisor principal
├── reportes.exs             # Textos y reportes que se muestran al usuario
├── comandos.exs             # Interpreta los comandos, valida y revisa permisos
│
├── main.exs                 # Modo local
├── pruebas.exs              # Pruebas con ExUnit
├── cookie.exs               # Genera la cookie de los nodos
├── diagramas/               # PDF de diagramas + imágenes PNG de cada uno
├── nodo-servidor/
│   ├── cookie
│   ├── nodo_servidor.exs    # Módulo Servidor
│   └── resources/           # Archivos de datos (se crean y actualizan solos)
│       ├── usuarios.txt
│       └── zonas.txt
└── nodo-cliente/
    ├── cookie
    └── nodo_cliente.exs     # Módulo Cliente
```

### Responsabilidad de cada módulo

| Módulo | Archivo | Responsabilidad |
|---|---|---|
| `Util` | `Util.ex` | Entrada y salida por consola (`ingresar/2`, `mostrar_mensaje/1`, `mostrar_error/1`), conversión de textos, `campos/1`, `convertir_a_mapa_por/2`, `filtrar/2` (**recursiva**) e ids. |
| `Usuario`, `Zona`, `Necesidad`, `Recurso`, `Movimiento`, `Persona`, `Mensaje`, `Mascota`, `Albergue` | `*.ex` | Structs con `crear`, `parse/1` (línea → `{:ok, struct}` o `:error`) y `a_linea/1` (struct → línea). |
| `Zona` | `zona.ex` | Funciones **recursivas** sobre el árbol: `insertar/3`, `total_afectados/1`, `a_texto/2` y `aplanar/2`. |
| `Validacion` | `validaciones.exs` | Reglas que retornan `:ok` o `{:error, motivo}` para usarlas con `with`. |
| `Archivo` | `archivo.exs` | `leer_con_rechazos/2` recorre las líneas **recursivamente** con `procesar_lineas/4`; `guardar/3` y `agregar/2` escriben los archivos. |
| `Usuarios`, `Zonas`, `Necesidades`, `Recursos`, `Personas`, `Mensajes`, `Mascotas`, `Albergues` | `*.exs` | **GenServer**: guardan el estado, atienden una solicitud a la vez y persisten cada cambio. |
| `Bitacora` | `bitacora.exs` | Proceso creado con `spawn_link` que registra la actividad con un ciclo `receive` **recursivo**. |
| `Coordinador` | `coordinador.exs` | `asignar_concurrente/2` lanza un proceso por solicitud con `spawn` y recibe los resultados con `esperar_resultados/2` (**recursiva**). |
| `Sistema` | `sistema.exs` | Inicia el **Supervisor** (`:one_for_one`) con los 9 procesos. |
| `Reportes` | `reportes.exs` | Arma los textos: una línea por elemento, resumen global, estado de zona y de albergue. |
| `Comandos` | `comandos.exs` | Separa la línea, valida las entradas, revisa los permisos y llama al proceso correspondiente. |
| `Main` | `main.exs` | Modo local. |
| `Servidor` | `nodo-servidor/nodo_servidor.exs` | Inicia el sistema, registra `:servicio_emergencias` y atiende cada solicitud en un proceso nuevo con `procesar_mensajes/0` **recursivo**. |
| `Cliente` | `nodo-cliente/nodo_cliente.exs` | Registra `:servicio_respuesta`, se conecta al servidor, envía los comandos y recibe las respuestas. |

---

## Formato de los archivos de datos

Los archivos están en `nodo-servidor/resources/`, no tienen encabezado, cada línea es un registro y los campos se separan con `@`. Si un archivo no existe, el proceso empieza vacío y lo crea al primer cambio. Las líneas mal formadas se descartan y se cuenta cuántas fueron.

| Archivo | Formato |
|---|---|
| `usuarios.txt` | `usuario@clave@nombre@tipo@zona` |
| `zonas.txt` | `ruta@nombre@nivel@afectados` (la ruta es `zona`, `zona/sector` o `zona/sector/punto`) |
| `necesidades.txt` | `id@tipo@cantidad@asignado@prioridad@zona@descripcion@responsable@estado@albergue` |
| `recursos.txt` | `codigo@nombre@categoria@cantidad@unidad@ubicacion@zona` |
| `movimientos.txt` | `fecha@codigo@tipo@cantidad@detalle` |
| `personas.txt` | `documento@nombre@edad@zona@estado@historial` (historial: `estado,fecha;estado,fecha`) |
| `mensajes.txt` | `id@fecha@remitente@destinatario@contenido@estado` |
| `mascotas.txt` | `id@tipo@especie@nombre@color@tamano@zona@contacto@caracteristicas@estado@pareja` |
| `albergues.txt` | `codigo@nombre@zona@capacidad@ocupacion@personas` (personas: `doc1,doc2`) |
| `actividad.txt` | `fecha@usuario@accion` |

Datos iniciales incluidos: el usuario `admin` (clave `admin`, administrador) y las zonas `centro` (con un sector y un punto de atención) y `zona_norte`.

---

## Compilación (paso previo a todo)

Desde la carpeta del proyecto (`Proyecto_Claudio_2.0/`):

```bash
elixirc util.ex validaciones.exs archivo.exs usuario.ex zona.ex necesidad.ex recurso.ex movimiento.ex persona.ex mensaje.ex mascota.ex albergue.ex usuarios.exs zonas.exs recursos.exs necesidades.exs personas.exs mensajes.exs mascotas.exs albergues.exs bitacora.exs coordinador.exs sistema.exs reportes.exs comandos.exs
```

Esto genera los archivos `Elixir.*.beam`.

---

## Modo local

```bash
elixir main.exs
```

---

## Modo distribuido (servidor y clientes)

### Nodos y cookie

| Rol | Nombre del nodo | Proceso registrado |
|---|---|---|
| Servidor | `nodoservidor@localhost` | `:servicio_emergencias` |
| Cliente 1, 2, ... | `nodocliente1@localhost`, `nodocliente2@localhost`, ... | `:servicio_respuesta` |

Todos los nodos deben usar **la misma cookie** (`nodo-servidor/cookie` y `nodo-cliente/cookie` son iguales). Para generar una nueva: `elixir cookie.exs` y copiar el resultado en los dos archivos. Si la cookie no coincide, el cliente muestra `No se pudo conectar con el nodo servidor`.

### Ejecución

Todas las terminales en la carpeta del proyecto. Iniciar primero el servidor.

**Terminal 1: servidor**

```bash
elixir --sname nodoservidor@localhost --cookie "$(cat nodo-servidor/cookie)" nodo-servidor/nodo_servidor.exs
```

Debe mostrar `Servidor iniciado en nodoservidor@localhost. Esperando consultas`. No cierre esta terminal: ahí se ve cada solicitud que llega.

**Terminal 2: cliente 1**

```bash
elixir --sname nodocliente1@localhost --cookie "$(cat nodo-cliente/cookie)" nodo-cliente/nodo_cliente.exs
```

**Terminal 3: cliente 2** (cada cliente debe tener un nombre de nodo distinto)

```bash
elixir --sname nodocliente2@localhost --cookie "$(cat nodo-cliente/cookie)" nodo-cliente/nodo_cliente.exs
```

### Funcionamiento

1. El cliente envía `{destino_respuesta, {:comando, usuario, linea}}`, donde `destino_respuesta = {:servicio_respuesta, Node.self()}`.
2. El servidor crea un proceso con `spawn` por cada solicitud, así atiende a varios usuarios al mismo tiempo, y vuelve a esperar con una llamada recursiva a `procesar_mensajes/0`.
3. El proceso nuevo llama a `Comandos.procesar/2` y responde `{:respuesta, texto, usuario}`.
4. Los GenServer atienden una operación a la vez, por eso aunque dos usuarios pidan el mismo recurso al mismo tiempo, nunca se asigna más de lo que hay.

---

## Comandos

Escribir `help` dentro del programa para verlos todos.

| Tema | Comandos |
|---|---|
| Usuarios | `connect usuario clave [tipo] [zona] ["nombre"]`, `disconnect`, `users`, `activity [usuario]`, `exit` |
| Zonas | `register_zone`, `register_sector`, `register_point`, `set_zone_level`, `list_zones`, `zone_status` |
| Necesidades | `register_need`, `list_needs [zona=x] [prioridad=x] ...`, `pending_needs`, `next_need`, `update_need`, `assign_resource`, `concurrent_assign` |
| Recursos | `register_resource`, `list_resources`, `resource_in`, `resource_out`, `transfer_resource`, `resource_history`, `critical_resources` |
| Familiares | `report_person`, `update_person`, `find_person`, `search_persons`, `send_family_message`, `list_family_messages`, `mark_message` |
| Mascotas | `report_pet lost\|found ...`, `list_pets`, `match_pets`, `confirm_match` |
| Albergues | `register_shelter`, `check_shelter`, `register_entry`, `register_exit`, `shelters_report` |
| Resumen | `summary` |

**Tipos de usuario:** `ciudadano` (consultas y reportes), `voluntario` (además cambia estados, ingresos/salidas de albergues y confirma coincidencias), `coordinador` (además zonas, recursos, asignaciones, albergues y bitácora) y `administrador` (todo, incluido `users`).

---

## Flujo de ejemplo (conflicto concurrente)

```
connect laura 1234 coordinador centro
register_need agua 30 critica centro "Punto de atencion sector 3"
register_need agua 25 alta centro "Familias sector 2"
register_resource R001 agua 50 litros centro_acopio_1
concurrent_assign agua N001:30 N002:25
summary
```

Resultado esperado de `concurrent_assign`:

```
----------ASIGNACION SIMULTANEA----------
    N001 pidio 30: CONFIRMADO (quedan 20 en R001)
    N002 pidio 25: RECHAZADO (inventario insuficiente)
```

También se puede demostrar con dos clientes: cada uno ejecuta `assign_resource` sobre el mismo recurso al mismo tiempo y solo uno lo logra.

---

## Pruebas

Después de compilar:

```bash
elixir pruebas.exs
```

Son 21 pruebas con ExUnit: funciones puras y recursivas, conflictos concurrentes (20 procesos sobre el mismo recurso, ingresos simultáneos a un albergue), validaciones, reinicio de un proceso por el Supervisor y permisos por rol. Usan la carpeta temporal `pruebas-resources`, que se borra al terminar.

---

## Conceptos aplicados

- **Funciones recursivas propias:** `Archivo.procesar_lineas/4`, `Zona.insertar/3`, `Zona.total_afectados/1`, `Zona.a_texto/2`, `Zona.aplanar/2`, `Util.filtrar/2`, `Mascotas.coincidencias/2`, `Coordinador.esperar_resultados/2`, `Comandos.leer_pares/1`, y los ciclos `receive` de `Bitacora`, `Servidor` y `Cliente`.
- **Estructuras de datos:** structs (registros inmutables), mapas (estado de cada GenServer, búsqueda por id), listas (historiales y árbol de zonas), tuplas (`{:ok, _}`, `{:error, motivo}` e historial `{estado, fecha}`) y MapSet (usuarios conectados y personas en un albergue).
- **Concurrencia:** `spawn`/`send`/`receive` en `Bitacora`, `Coordinador` y `Servidor`; 8 GenServer; Supervisor `:one_for_one`; nodos con `Node.connect/1`.

---

## Diagramas

En la carpeta `diagramas/` están `Diagramas_Proyecto_Claudio_2.0.pdf` (arquitectura de módulos, modelo de datos, diagrama de secuencia, árbol de supervisión OTP y estructura del proyecto) y cada diagrama en PNG para pegarlo en la plantilla.

---

## Autores

- Luis Miguel García Villanueva
- Juan David Arias Sánchez
