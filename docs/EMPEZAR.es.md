# Open Dream Prime — Primeros pasos

Ejecute el instalador de Mac o Windows con el proyecto que se le asignó: `ADAM` o `FRNKLY.ONE`.

Antes de clonar un proyecto privado, GitHub CLI realiza exactamente una autorización web/de dispositivo. Inicie sesión con **su propia cuenta de GitHub** e ingrese el código de un solo uso únicamente en la página oficial de dispositivos de GitHub. El instalador muestra el nombre de usuario autenticado y luego verifica que esa cuenta pueda leer el repositorio elegido. No usa un inicio de sesión compartido de Open Dream, token, otra credencial ni acceso de administrador del repositorio de GitHub. Si se detiene por falta de acceso, pida al propietario del repositorio que invite su cuenta personal como colaborador normal con el acceso necesario y ejecute de nuevo el instalador. **FRNKLY.ONE requiere esa invitación personal de colaborador.** El **OPNDRM APP** público no inicia la autorización de dispositivos de GitHub.

FRNKLY.ONE es la reconstrucción en Rust. Su checkout privado canónico es [`opndrm/Frnkly.one`](https://github.com/opndrm/Frnkly.one.git), mientras que el espacio instalado conserva el nombre `FRNKLY.ONE`.

Cuando termine, abra WezTerm. Su espacio de trabajo tiene dos áreas simples:

- **PRIME** — empiece aquí. Dígale a Prime Agent lo que quiere crear.
- **NO MISTAKES GATE** — permanece inactivo hasta que usted decida usarlo para verificar una rama terminada.

Prime Agent comienza con Ollama. DeepSeek V4 Flash es el modelo predeterminado. MiniMax M3 y cada modelo instalado en Ollama están disponibles cuando los necesite.

Buzz es el espacio de conversación del equipo. Úselo para hablar del trabajo y enlazar la incidencia correspondiente de GitHub. Wayfinder organiza el plan de incidencias de GitHub. GitHub sigue siendo el registro oficial para código, ramas, revisiones y solicitudes de extracción.

Atomic Vault es personal. No comparta credenciales, claves privadas ni acceso al Vault. Si la confianza del Vault está pendiente, pida al líder del equipo el paso oficial aprobado por el propietario.

El instalador acepta una instalación correcta del paquete de GitHub de Open Dream Prime y luego verifica que Prime Agent siga respondiendo. El paquete se carga cuando Prime Agent inicia o después de `/reload`; un Prime Agent que ya está ejecutándose no necesita listar el paquete para que la instalación continúe.
