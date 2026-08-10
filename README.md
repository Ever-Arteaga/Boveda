# Mi Servidor Web — desde cero, con Node.js puro

Este proyecto es la base de aprendizaje para construir el servidor web del NAS/Homelab.
No usa ningún framework (ni Express) — todo con el módulo `http` nativo de Node, para
entender qué pasa realmente "por debajo" antes de usar herramientas que lo abstraen.

## Configuración de VS Code (abrir la carpeta raíz `mi-servidor-web/`)

### 1) Instalá la extensión REST Client

Buscá **"REST Client"** (de Huao Ho) en la pestaña de Extensiones. Con esto, cada
carpeta trae un archivo `pruebas.http` — arriba de cada bloque de petición aparece
un link **"Send Request"** que la ejecuta y muestra la respuesta en un panel al lado,
sin salir del editor y sin usar curl ni Postman.

VS Code va a sugerirte instalarla automáticamente al abrir la carpeta (gracias a
`.vscode/extensions.json`), o instalala a mano si no aparece el aviso.

### 2) Correr un servidor con auto-reinicio al guardar

En vez de `node servidor.js`, usá:
```bash
npm run dev
```
Esto usa la flag `--watch` de Node: cada vez que guardás un cambio en `servidor.js`,
el servidor se reinicia solo. Ideal para no tener que parar/arrancar a mano.

### 3) Debugging con breakpoints reales (en vez de console.log)

Abrí el panel **Run and Debug** (ícono de la barra lateral, o `Ctrl+Shift+D`),
elegí el servidor que quieras del menú desplegable arriba (ej: "▶ 04-autenticacion")
y dale al botón verde ▶. Después hacé clic a la izquierda del número de línea en
cualquier parte del código para poner un breakpoint — cuando llegue una petición
que pase por ahí, la ejecución se pausa y podés inspeccionar `req`, variables, etc.
en el panel lateral.

## Estructura

```
mi-servidor-web/
├── 01-basico/       -> servidor HTTP mínimo (Hola Mundo)
├── 02-rutas/        -> routing manual + respuestas JSON tipo API
└── 03-archivos/     -> subida, descarga y borrado de archivos con streams
```

Cada carpeta es un paso independiente y ejecutable. Están pensadas para recorrerse en orden.

## Cómo correr cada uno

```bash
cd 01-basico
node servidor.js
# abrí http://localhost:3000 en el navegador
```

Igual para `02-rutas` y `03-archivos` (cambiá de carpeta y corré `node servidor.js`).

## Paso 1 — Servidor básico

Lo mínimo posible: escucha en un puerto y responde texto plano a cualquier petición.
Sirve para entender `http.createServer`, `req`/`res`, y `listen()`.

## Paso 2 — Rutas (routing manual)

Reproduce lo que hace Express automáticamente: según la URL y el método (GET, POST...)
se ejecuta un bloque de código distinto. Incluye respuestas en JSON, como haría una API real.

Probar en el navegador o con curl:
- `GET /`
- `GET /archivos`
- `GET /archivos/1`
- `GET /saludo?nombre=Ever`

## Paso 3 — Archivos (el núcleo real de un "Drive propio")

Acá está el corazón de lo que necesitás para tu proyecto: subir y descargar archivos
usando **streams**, sin cargar el archivo entero en memoria. Esto es crítico en la
Raspberry Pi, que tiene RAM limitada — subir un video de 2GB no debería consumir 2GB de RAM.

Endpoints:

| Método | Ruta                     | Qué hace                              |
|--------|--------------------------|----------------------------------------|
| GET    | `/archivos`               | Lista los archivos guardados          |
| POST   | `/subir?nombre=x.pdf`     | Sube un archivo (body = contenido)    |
| GET    | `/descargar/x.pdf`        | Descarga un archivo                   |
| DELETE | `/archivos/x.pdf`         | Elimina un archivo                    |

### Probar con curl

```bash
# Subir un archivo
curl -X POST --data-binary @miarchivo.pdf "http://localhost:3000/subir?nombre=miarchivo.pdf"

# Listar archivos
curl http://localhost:3000/archivos

# Descargar
curl http://localhost:3000/descargar/miarchivo.pdf -o descargado.pdf

# Borrar
curl -X DELETE http://localhost:3000/archivos/miarchivo.pdf
```

### Seguridad ya incluida (básica)

- `nombreSeguro()`: evita que alguien intente subir/pedir archivos fuera de la carpeta
  permitida (ataque de "path traversal", ej: `../../etc/passwd`).
- Los archivos solo se guardan dentro de `03-archivos/almacenamiento/`.

### Lo que falta para ser un "Drive propio" real (próximos pasos)

Esto ya es la base funcional, pero para el proyecto completo falta agregar:

1. **Autenticación** — que cada usuario solo vea sus propios archivos (JWT o sesiones).
2. **HTTPS** — nunca exponer esto en la red real sin cifrado de transporte.
3. **Multipart real** — hoy `/subir` manda el archivo "crudo" en el body; los navegadores
   suben archivos con `multipart/form-data`, que requiere un parser (se puede seguir
   escribiendo a mano o usar una librería mínima como `busboy`).
4. **Metadatos en base de datos** — hoy la lista de archivos se lee del sistema de
   archivos; en el proyecto real, Supabase o Nextcloud guardarían dueño, fecha,
   permisos, tags de IA, etc.
5. **Límite de tamaño y cuotas** por usuario.
6. **Conexión con IA** — cuando se sube un archivo, disparar una llamada a Ollama/LocalAI
   para clasificarlo o generar un resumen.

## Paso 4 — Autenticación con JWT (usuarios reales)

Acá el servidor deja de ser "cualquiera puede subir o borrar" y pasa a tener usuarios
reales, cada uno con sus propios archivos.

**Requiere instalar dependencias primero** (a diferencia de los pasos 1-3, que solo
usan módulos nativos de Node):

```bash
cd 04-autenticacion
npm install
cp .env.example .env    # creá tu propio .env local (no se sube a git)
npm run dev
```

Conceptos nuevos:
- **bcrypt**: hashea contraseñas — nunca se guardan en texto plano, ni el propio
  servidor puede "ver" la contraseña real de un usuario.
- **JWT (JSON Web Token)**: al loguearse, el servidor entrega un token firmado.
  El cliente lo manda en cada petición (header `Authorization: Bearer <token>`)
  para probar quién es, sin reenviar usuario/contraseña cada vez.
- **Middleware de autenticación**: `verificarToken()` revisa el token antes de
  dejar pasar la petición a la ruta real — si no hay token válido, corta con `401`.
- Cada usuario tiene su **propia carpeta** dentro de `almacenamiento/<id-usuario>/`,
  así que un usuario nunca puede ver ni borrar archivos de otro.

Endpoints:

| Método | Ruta                     | Requiere token | Qué hace                          |
|--------|--------------------------|:---:|-------------------------------------------|
| POST   | `/registro`               | No  | Crea un usuario `{ email, contrasena }`   |
| POST   | `/login`                  | No  | Devuelve un token JWT                     |
| GET    | `/archivos`               | Sí  | Lista los archivos del usuario logueado   |
| POST   | `/subir?nombre=x.pdf`     | Sí  | Sube un archivo                           |
| GET    | `/descargar/x.pdf`        | Sí  | Descarga un archivo propio                |
| DELETE | `/archivos/x.pdf`         | Sí  | Elimina un archivo propio                 |

Probar con `prueba.html` de esta misma carpeta: primero registrate, después hacé
login (el token queda guardado en memoria de la página), y ahí aparece el panel
para subir/listar/descargar/borrar.

### Importante para cuando esto sea real (no solo de prueba)

- El `JWT_SECRETO` vive en `.env` (nunca en el código ni en git). Copiá
  `.env.example` a `.env` y poné ahí tu propio valor.
- `usuarios.json` es una simulación de base de datos. En el proyecto real esto
  sería una tabla en Supabase (que ya usás en tus otros proyectos) o el propio
  sistema de usuarios de Nextcloud.
- Falta: recuperación de contraseña, verificación de email, rate-limiting en
  `/login` (para frenar ataques de fuerza bruta probando contraseñas).

## Próximo paso sugerido

- Migrar `usuarios.json` a Supabase (ya lo conocés de tus otros proyectos).
- Servir la subida como `multipart/form-data` real (formulario HTML nativo).
- Conectar `/subir` con Ollama/LocalAI para clasificar el archivo automáticamente
  apenas se guarda.

