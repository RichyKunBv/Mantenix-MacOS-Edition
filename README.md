# macOS_Maintenance
# Mantenimiento para macOS

Este script permite realizar diversas tareas de mantenimiento en macOS, como la verificación y reparación del disco, limpieza de cachés, restablecimiento de la red y más.

## Uso

Para ejecutar el script, abre la Terminal y escribe el siguiente comando:

```sh
sudo /Users/(tu_usuario)/Desktop/macos_mantenimiento.sh
```

Donde `(tu_usuario)` es el nombre de usuario en tu Mac.

## Funciones del Script

- **Verificar y reparar el disco principal** (compatible con APFS y HFS+).
- **Reparar permisos del sistema** (solo en macOS Mojave 10.14 y versiones anteriores).
- **Limpiar cachés del sistema y del usuario**, incluyendo registros de logs.
- **Eliminar metadatos y cachés de iconos y Spotlight**.
- **Restablecer configuraciones de red** (DNS, IPv6, interfaz de red).
- **Liberar memoria RAM y eliminar archivos de intercambio (swap)**.
- **Detener procesos de indexación** temporalmente para mejorar el rendimiento.
- **Instrucciones para ejecutar fsck en modo de recuperación**.

## Compatibilidad

Este script es compatible con macOS desde High Sierra (10.13) hasta las versiones más recientes (Sonoma/Sequoia 14.0/15.0).

## Notas

- Se requiere ejecutar el script con permisos de administrador (`sudo`).
- Algunas funciones, como la reparación de permisos, solo están disponibles en versiones antiguas de macOS.
- Para una reparación avanzada del sistema de archivos, es necesario reiniciar en modo de recuperación y ejecutar el comando:
  
  ```sh
  /sbin/fsck -fy
  ```

---

Con este script, puedes mantener tu macOS limpio y en buen estado de funcionamiento de forma rápida y sencilla.
