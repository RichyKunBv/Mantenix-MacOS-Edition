#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_PNG="${1:-${SCRIPT_DIR}/icon.png}"
OUTPUT_ICNS="${2:-${SCRIPT_DIR}/icon.icns}"

if [ ! -f "${INPUT_PNG}" ]; then
    echo "Error: No se encontró el archivo de entrada: ${INPUT_PNG}"
    echo "Uso: $0 [ruta_al_png_original] [ruta_salida.icns]"
    exit 1
fi

TEMP_ICONSET="$(mktemp -d)/icon.iconset"
mkdir -p "${TEMP_ICONSET}"

cleanup() {
    rm -rf "$(dirname "${TEMP_ICONSET}")"
}
trap cleanup EXIT

echo "Generando iconos a partir de ${INPUT_PNG}..."

sips -z 16 16     "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_16x16.png" > /dev/null
sips -z 32 32     "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_32x32.png" > /dev/null
sips -z 64 64     "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_128x128.png" > /dev/null
sips -z 256 256   "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_256x256.png" > /dev/null
sips -z 512 512   "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_512x512.png" > /dev/null
sips -z 1024 1024 "${INPUT_PNG}" --out "${TEMP_ICONSET}/icon_512x512@2x.png" > /dev/null

echo "Empaquetando en .icns..."
mkdir -p "$(dirname "${OUTPUT_ICNS}")"
iconutil -c icns "${TEMP_ICONSET}" --out "${OUTPUT_ICNS}"

echo "¡Icono generado exitosamente en: ${OUTPUT_ICNS}!"

