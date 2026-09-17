# Mantenix v4.0 — Mantenimiento inteligente para macOS

Mantenix es una utilidad de mantenimiento y limpieza para macOS diseñada para ayudarte a optimizar el sistema, limpiar cachés, revisar seguridad, mantener Homebrew actualizado y conservar el rendimiento del Mac sin entrar en juegos complejos ni configuraciones avanzadas.

La versión 4.0 llega con una experiencia más moderna, más segura y enfocada en los sistemas actuales de macOS, con compatibilidad para macOS Big Sur 11.0 o superior.

---

## ¿Qué es Mantenix?

Mantenix es un script Bash pensado para usuarios que quieren un mantenimiento rápido, seguro y visual de su Mac desde Terminal. Te permite:

- limpiar cachés del sistema y del usuario
- liberar memoria y reducir el consumo innecesario
- revisar el estado del disco y del sistema
- restaurar configuración de red
- actualizar Homebrew de forma segura
- revisar seguridad del sistema
- crear instantáneas locales de Time Machine antes de cambios importantes
- buscar actualizaciones de la propia app desde GitHub

---

## Compatibilidad

- macOS Big Sur 11.0 o superior
- Soporte recomendado para macOS Sequoia y versiones recientes
- Requiere permisos de administrador para ciertas funciones del sistema

> La versión 4.0 está enfocada en equipos modernos con macOS 11+ y elimina compatibilidad con sistemas antiguos para reforzar la seguridad y la fiabilidad del mantenimiento.

---

## Instalación

1. Descarga el repositorio o copia el archivo `MantenixM.sh` a tu equipo.
2. Abre la Terminal.
3. Ejecuta:

```bash
chmod +x MantenixM.sh
sudo ./MantenixM.sh
```

También puedes usar la ayuda del script para ver todas las opciones disponibles:

```bash
./MantenixM.sh --help
```

---

## Menú principal

La versión 4.0 incluye un menú claro y ordenado con estas opciones:

- 1) Limpieza General de Cachés
- 2) Verificación del Disco APFS
- 3) Restablecer Configuración de Red
- 4) Liberar Memoria RAM Inactiva
- 5) Actualizar y Optimizar Homebrew
- 6) Reporte de Salud del Mac
- 7) Revisión de Seguridad
- 8) Limpieza de Caché de Apps
- 9) Purgar Snapshots Locales (Time Machine)
- A) Ejecutar Todo el Mantenimiento
- B) Limpieza de Caché de Xcode
- C) Desinstalar Visual Studio for Mac
- S) Crear Instantánea de Seguridad Time Machine
- Y) Buscar Actualizaciones
- X) Salir

---

## Nuevas funciones en v4.0

### Seguridad y prevención

- Comprobación explícita de compatibilidad con macOS Big Sur+
- Creación de instantáneas locales de Time Machine antes de limpiar o modificar el sistema
- Avisos y registro en `~/Library/Logs/Mantenix/MantenixBETA.log`
- Revisión de seguridad del sistema con detección de Firewall, Gatekeeper y otros elementos relevantes

### Mantenimiento más completo

- Limpieza de cachés del usuario, sistema y temporales
- Reindexación de Spotlight
- Limpieza de swap y archivos temporales
- Limpieza de cachés de Xcode y aplicaciones populares
- Optimización y actualización de Homebrew con ejecución segura para el usuario real

### Actualizaciones inteligentes

- Comprueba automáticamente si existe actualización del proyecto
- Descarga e instala la última versión del script cuando está disponible
- Reinicia el script con la versión más reciente

---

## Capturas del proyecto

<img src="/screenshots/readme/menu.png">

<img src="/screenshots/readme/salud.png">

<img src="/screenshots/readme/seguridad.png">

<img src="/screenshots/readme/actualizar.png">

<img src="/screenshots/readme/brew.png">

---

## Uso recomendado

Para usuarios normales, la mejor opción es:

1. abrir el script
2. elegir la opción A para ejecutar todo el mantenimiento
3. confirmar la instantánea de seguridad
4. revisar el reporte de salud y seguridad
5. dejar que el script actualice Homebrew y limpie archivos temporales

Esto te da una experiencia de mantenimiento más segura y ordenada en un solo flujo.

---

## Nota importante

Ejecuta Mantenix con precaución en equipos con configuraciones custom o entornos de trabajo sensibles. Algunas tareas eliminan cachés, temporales y archivos de sistema que pueden requerir reinicio o regeneración de datos por parte de aplicaciones.

---

## Licencia

Este proyecto se distribuye bajo la licencia indicada en el repositorio.

---

## Estado del proyecto

La versión 4.0 está diseñada como una evolución más moderna del mantenimiento de macOS, con una base más clara para la experiencia de beta y la preparación de futuras releases.

---

## Créditos

Desarrollado para la comunidad de usuarios de macOS que buscan un mantenimiento simple, rápido y capaz de ayudar a mantener el sistema limpio y estable.
