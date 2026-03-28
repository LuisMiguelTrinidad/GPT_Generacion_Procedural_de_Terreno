# 02_ZIG_Ruidos_pseudoaleatorios

Implementación y benchmark de ruido Perlin en Zig, con múltiples variantes de optimización (`O0` a `O6`) y exportación de imágenes compuestas.

## Requisitos

- Zig `0.14.x` (o compatible con `build.zig` actual)
- CPU x86_64 con AVX2 (mínimo) para modos `i16` (`O5`, `O6`)

## Instalación y ejecución básica

Desde esta carpeta:

```bash
zig build --release=fast
./zig-out/bin/perlin O3
```

También puedes usar:

```bash
zig build run --release=fast -- O5
```

## Comandos útiles

- Build rápido: `zig build --release=fast`
- Ejecutar con argumentos: `zig build run --release=fast -- O6`
- Tests Zig: `zig build test`
- Convención de nombres: `zig build naming`

## Qué hace cada modo (`O0`...`O6`)

- `O0`: referencia base, sin optimizaciones estructurales agresivas.
- `O1`: variante con hash custom para reducir coste respecto al baseline.
- `O2`: caching de valores auxiliares para disminuir recomputación.
- `O3`: tiling/indexación optimizada y mejor localidad.
- `O4`: versión SIMD en `f32`.
- `O5`: versión vectorial en punto fijo `i16`.
- `O6`: versión `i16` con unroll adicional y cacheado de cálculo en L1.

En `O5`/`O6` se selecciona automáticamente backend vectorial: AVX512BW (32 lanes) cuando el target lo soporta, y AVX2 (16 lanes) en caso contrario.

> Nota: Los nombres `O0..O6` son etiquetas de variante del algoritmo, no equivalen directamente a flags de optimización del compilador Zig.

## Arquitectura del proyecto

```text
src/
  benchmark/
    engine.zig             # Orquestador de ejecución por modo
    runner.zig             # Warmup + benchmark pass
    report.zig             # Formato de métricas
    f32/
      run_mode.zig         # Pipeline benchmark para modos f32
      image_writer.zig     # Exportación PNG para muestras f32
    i16/
      run_mode.zig         # Pipeline benchmark para modos i16
      image_writer.zig     # Exportación PNG para muestras i16

  core/
    shared/
      hash.zig
      math.zig
    f32/
      types.zig
      table.zig
    i16/
      types.zig
      table.zig

  noise/perlin/
    00_ref.zig
    01_custom_hash.zig
    02_caching.zig
    03_tiling.zig
    04_simd.zig
    05_fpa.zig
    06_licm.zig
    registry.zig           # Mapeo modo -> implementación + metadatos
```

## Salida

Cada ejecución genera:

- Resumen de rendimiento en consola (tiempo, Mpts/s, ciclos/punto)
- Imagen en `output/perlin_composite_*_zig_<modo>.png`

## Convenciones

- Funciones en `snake_case`
- Tipos (`struct`, `enum`, `union`) en `PascalCase`
- Validación automática mediante `zig build naming`

## Limitaciones y restricciones actuales

Estas restricciones salen del código actual de las variantes (`O0..O6`) y del pipeline de benchmark.

### Restricciones obligatorias

- `SCALE` debe ser **potencia de 2** y `> 0`.
  - Se usa `@ctz(SCALE)` y máscara `SCALE - 1` para indexación modular (`idx & (SCALE - 1)`).
  - Si no es potencia de 2, la indexación de tiles/celdas deja de ser correcta.

- En modos vectoriales, `min(CHUNK_SIZE, SCALE)` debe ser múltiplo del ancho vectorial.
  - `O4` (`f32`, 8 lanes): múltiplo de **8**.
  - `O5` y `O6` (`i16`): múltiplo de `LANES` (**16 con AVX2**, **32 con AVX512BW**).
  - Si no se cumple, los `load/store` vectoriales alineados pueden leer/escribir fuera de bloque.

- En `O6`, además, `min(CHUNK_SIZE, SCALE)` debería ser múltiplo de **8** (por `UNROLL_FACTOR = 8`).
  - El bucle de filas avanza de 8 en 8 y prepara 8 filas por iteración.
- Estas condiciones se validan en `comptime` en `O5`/`O6` (fallan en compilación si no se cumplen).
- Los modos `i16` (`O5`, `O6`) requieren CPU x86_64 con AVX2 como mínimo.
  - Si el target incluye AVX512BW, usan vectorización de 32 lanes; si no, fallback a 16 lanes.
- La alineación requerida por cada modo debe respetarse.
  - Se obtiene vía `registry.get_mode_spec(...).required_alignment` y se valida como potencia de 2.
  - El código ya reserva buffers con esa alineación (`alignedAlloc`).

### Restricciones prácticas/recomendadas
- Para benchmark estable, usa `CHUNK_SIZE` y `SCALE` como potencias de 2 y, preferiblemente, iguales (por ejemplo `512/512`, como en `config.zig`).
- En `i16` (`O5`, `O6`), mantener `SCALE <= 32768` evita problemas con la representación Q0.15 al precalcular `cached_values`.
- Si quieres portabilidad sin AVX2, usa `O0..O4`.

### Nota sobre parámetros no usados

- `OCTAVES`, `PERSISTENCE` y `LACUNARITY` forman parte de la config, pero en estas implementaciones actuales de benchmark no cambian el cálculo interno del chunk (single-octave efectivo).
