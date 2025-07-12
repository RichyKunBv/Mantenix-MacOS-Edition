# macOS_Maintenance

---

## Mantenimiento para macOS

Este script proporciona un **menú interactivo** que te permite realizar diversas tareas de mantenimiento en macOS. Incluye funciones para la **limpieza del sistema**, el **mantenimiento de componentes clave** y la **actualización de Homebrew**. Está diseñado para ser fácil de usar y es compatible con varias versiones de macOS.

---

## Uso

Para empezar a usar el script, primero dale permisos de ejecución. Abre la Terminal y ejecuta el siguiente comando (recuerda cambiar `(tu_usuario)` por tu nombre de usuario y ajusta la ruta si el script no está en tu Escritorio):

```sh
chmod +x /Users/(tu_usuario)/Desktop/macos_mantenimiento.sh
```

Una vez que tenga los permisos, puedes ejecutar el script. Abre la Terminal y usa este comando:

```sh
sudo /Users/(tu_usuario)/Desktop/macos_mantenimiento.sh
```

**Consejo rápido:** Para ejecutar el script de forma más sencilla, escribe `sudo ` (con el espacio al final) en la Terminal, luego simplemente **arrastra el archivo `macos_mantenimiento.sh` desde el Finder a la ventana de la Terminal** y presiona `Enter`.


Ejemplo:
![Captura de Pantalla 2025-06-07 a la(s) 11 17 32 p m](https://github.com/user-attachments/assets/6048be04-e1fa-41cb-af15-709319994834)

---

## Funciones del Script (v2.2)

La versión 2.2 del script ofrece un menú organizado con las siguientes opciones:

<img width="383" height="253" alt="Captura de pantalla 2025-07-11 a la(s) 9 48 37 p m" src="https://github.com/user-attachments/assets/a9a508af-96a1-48c8-838a-1f7368cce8bb" />


### 1. Limpieza General
Esta opción ejecuta varias tareas para **liberar espacio y optimizar el rendimiento**:
* **Limpieza de cachés de sistema, usuario, logs** y estados de aplicaciones guardados.
* **Eliminación de metadatos y cachés de iconos y Spotlight**.
* **Limpieza de archivos de intercambio (Swap)** (te pedirá confirmación antes de proceder).

### 2. Mantenimiento del Sistema
Aquí encontrarás funciones esenciales para el **buen funcionamiento de los componentes centrales** de tu macOS:
* **Verificación y reparación del disco principal** (compatible con sistemas de archivos APFS y HFS+).
* **Reparación de permisos del sistema** (solo relevante para macOS Mojave 10.14 y versiones anteriores).
* **Restablecimiento de configuraciones de red** (limpia DNS, ajusta IPv6 y reinicia la interfaz de red).
* **Liberación de memoria RAM**.
* **Detención temporal de procesos de indexación** (`mds`, `mdworker`, `corespotlightd`) para mejorar la respuesta del sistema.

### 3. Actualizar Homebrew
Esta opción te permite **mantener Homebrew y tus paquetes actualizados**:
* Detecta si Homebrew está instalado en tu sistema.
* Si lo tienes, **actualiza Homebrew y todos los paquetes instalados** a través de él, además de limpiar archivos antiguos.
* Si Homebrew no está presente, te informará y te indicará dónde encontrarlo para instalarlo.
    * **Nota Importante:** Esta tarea se ejecuta con los permisos del **usuario que inició el script** (no con `sudo`), lo cual es crucial para evitar problemas de permisos con tu instalación de Homebrew.

### 4. Ejecutar todo
* **A. Ejecutar TODO el Mantenimiento:** Realiza de forma consecutiva todas las tareas incluidas en "Limpieza General", "Mantenimiento del Sistema" y "Actualizar Homebrew".

### 5. Reporte de salud del Mac
Esta opcion te da informacion sobre tu sistema como el estado de la bateria, espacio usado, tu procesador y cuanta ram tienes

<img width="385" height="237" alt="Captura de pantalla 2025-07-11 a la(s) 9 49 55 p m" src="https://github.com/user-attachments/assets/b30daebd-8352-42fa-9f8d-2c43ff8d4bc2" />

### 6. Limpiar cache de Xcode
* **B. Esta opcion limpia el cache de Xcode ya que puede llegar a pesar GB

### Opciones Adicionales del Menú:
* **Y. El script se autoactualiza con solo un simple click solo le tienes que picar una vez para que se actualice y reinicie en la ultima version disponible.

![Captura de Pantalla 2025-06-27 a la(s) 12 14 25 a m](https://github.com/user-attachments/assets/94fe0b92-ec5a-4834-860a-d373a9a2e06d)


---

## Compatibilidad

Este script ha sido diseñado para ser compatible con **macOS High Sierra (10.13)** y versiones posteriores, incluyendo las más recientes como **Sequoia (15.0)**.

---

## Notas Importantes

* Es **obligatorio ejecutar el script con permisos de administrador (`sudo`)** para que la mayoría de sus funciones puedan operar correctamente.
* Algunas funciones, como la **reparación de permisos**, solo son útiles y están disponibles en versiones de macOS más antiguas (Mojave y anteriores).
* Para una **reparación más profunda del sistema de archivos**, te recomiendo reiniciar tu Mac en **modo de recuperación** (manteniendo `Command + R` al encender) y luego ejecutar el siguiente comando en la Terminal de recuperación:
    ```sh
    /sbin/fsck -fy
    ```

---
```
