#!/bin/bash
# fix_xcframework_scripts.sh
# Parchea los scripts de Copy XCFrameworks generados por CocoaPods
# para que creen el directorio destino antes de llamar a rsync.
# Ejecutar desde example/ios/ después de pod install.

set -e

PODS_DIR="$(pwd)/Pods"

if [ ! -d "$PODS_DIR" ]; then
  echo "❌ No se encontró el directorio Pods. Ejecuta este script desde example/ios/"
  exit 1
fi

echo "🔍 Buscando scripts de Copy XCFrameworks..."

# Targets que sabemos que fallan con Xcode 26
TARGETS=("GoogleMaps" "MapboxCoreMaps" "MapboxCommon")

for TARGET in "${TARGETS[@]}"; do
  SCRIPT_DIR="$PODS_DIR/Target Support Files/$TARGET"
  
  if [ ! -d "$SCRIPT_DIR" ]; then
    echo "⏭️  $TARGET: directorio no encontrado, saltando"
    continue
  fi

  # Buscar el script xcframeworks (puede llamarse diferente según versión de CocoaPods)
  SCRIPT=$(find "$SCRIPT_DIR" -name "*.sh" | grep -i "xcframework\|copy" | head -1)
  
  if [ -z "$SCRIPT" ]; then
    echo "⏭️  $TARGET: no se encontró script .sh, saltando"
    continue
  fi

  echo "📄 Procesando: $SCRIPT"

  # Verificar si ya está parcheado
  if grep -q "fix_xcode26_mkdir" "$SCRIPT"; then
    echo "✅ $TARGET: ya parcheado"
    continue
  fi

  # Hacer backup
  cp "$SCRIPT" "${SCRIPT}.bak"

  # Insertar mkdir -p antes de cada línea rsync
  # Usamos python3 que siempre está disponible en macOS
  python3 - "$SCRIPT" <<'PYTHON'
import sys
import re

script_path = sys.argv[1]

with open(script_path, 'r') as f:
    content = f.read()

# Patrón: líneas con rsync que tienen un destino como último argumento
# Insertar mkdir -p del directorio destino antes de cada rsync
lines = content.split('\n')
new_lines = []
patched = False

for line in lines:
    # Detectar líneas rsync con destino XCFrameworkIntermediates
    if line.strip().startswith('rsync') and 'XCFrameworkIntermediates' in line:
        # Extraer el último token (directorio destino)
        # El formato es: rsync ... "src/*" "dest"
        import shlex
        try:
            tokens = shlex.split(line.strip())
            dest = tokens[-1]  # último argumento = destino
            mkdir_line = f'mkdir -p "{dest}"  # fix_xcode26_mkdir'
            new_lines.append(mkdir_line)
            patched = True
        except Exception as e:
            pass  # Si no podemos parsear, dejamos la línea original
    new_lines.append(line)

if patched:
    with open(script_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print(f"  ✅ Parcheado correctamente")
else:
    print(f"  ⚠️  No se encontraron líneas rsync para parchear")
PYTHON

done

echo ""
echo "🎯 Ahora también parcheando el script generado en DerivedData (si existe)..."

# Buscar en DerivedData también
DERIVED_DATA_SCRIPTS=$(find ~/Library/Developer/Xcode/DerivedData -name "Script-*.sh" -path "*/GoogleMaps.build/*" 2>/dev/null)

for SCRIPT in $DERIVED_DATA_SCRIPTS; do
  if grep -q "fix_xcode26_mkdir" "$SCRIPT"; then
    echo "✅ DerivedData script ya parcheado: $SCRIPT"
    continue
  fi
  
  echo "📄 Parcheando DerivedData: $SCRIPT"
  cp "$SCRIPT" "${SCRIPT}.bak"
  
  python3 - "$SCRIPT" <<'PYTHON'
import sys, shlex

script_path = sys.argv[1]
with open(script_path, 'r') as f:
    content = f.read()

lines = content.split('\n')
new_lines = []
patched = False

for line in lines:
    if line.strip().startswith('rsync') and 'XCFrameworkIntermediates' in line:
        try:
            tokens = shlex.split(line.strip())
            dest = tokens[-1]
            new_lines.append(f'mkdir -p "{dest}"  # fix_xcode26_mkdir')
            patched = True
        except:
            pass
    new_lines.append(line)

if patched:
    with open(script_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print("  ✅ DerivedData script parcheado")
PYTHON

done

echo ""
echo "✅ Listo. Ahora limpia DerivedData y vuelve a buildear:"
echo "   1. En Xcode: Product → Clean Build Folder (⇧⌘K)"
echo "   2. Build (⌘B)"
