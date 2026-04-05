# 02_ZIG_Ruidos_pseudoaleatorios

Implementación y benchmark de ruido Perlin en Zig, con múltiples variantes de optimización (`O0` a `O6`) y exportación de imágenes compuestas.

## Requisitos

- Zig `0.15.2`
- CPU con SIMD para modos vectoriales (`O5`, `O6`): AVX2/AVX512BW en `x86_64` o NEON en `aarch64`

## Instalación y ejecución básica

Desde esta carpeta:

```bash
zig build --release=fast
./zig-out/bin/perlin O3
```

También puedes usar:

```bash
zig build --release=fast run -- O5
```


## Qué hace cada modo (`O0`...`O6`)

- `O0`: referencia base, sin optimizaciones estructurales agresivas.
- `O1`: variante con hash custom para reducir coste respecto al baseline.
- `O2`: caching de valores auxiliares para disminuir recomputación.
- `O3`: pseudotiling/indexación optimizada y mejor localidad.
- `O4`: versión `f32` con estructura LICM
- `O5`: versión SIMD en `f32` basada en la estructura de `O4`.
- `O6`: versión SIMD en punto fijo `i16` (FPA) con cache intermedia.

El backend SIMD se resuelve en `core/shared/arch_caps.zig` con prioridad `AVX512BW -> AVX2 -> NEON -> scalar` (según target y CPU features). Los modos vectoriales `O5` (`f32`) y `O6` (`i16`) usan ese despacho a través de `core/f32/vector_math.zig` y `core/i16/vector_math.zig`.

> Nota: Los nombres `O0..O6` son etiquetas de variante del algoritmo, no equivalen directamente a flags de optimización del compilador Zig.

## Arquitectura del proyecto

```text
src/
  main.zig                 # CLI: valida args y delega en benchmark/engine
  root.zig                 # API pública (engine + perlin_registry)

  benchmark/
    config.zig             # Parámetros de benchmark (seed, chunk, escala, etc.)
    engine.zig             # Dispatcher por modo (f32/i16)
    runner.zig             # Warmup + pass de benchmark + medición de ciclos
    report.zig             # Cálculo e impresión de métricas
    f32/
      run_mode.zig         # Pipeline de ejecución para modos f32
      image_writer.zig     # Adaptador f32 -> Gray8Image
    i16/
      run_mode.zig         # Pipeline de ejecución para modos i16
      image_writer.zig     # Adaptador i16 -> Gray8Image
    image/
      composite_builder.zig # Composición de mosaico de chunks
      output_naming.zig     # Convención de nombres de salida
      png_writer.zig        # Escritura PNG (zigimg)
      types.zig             # Tipos de imagen (Gray8Image)

  core/
    shared/
      arch_caps.zig         # Detección de arquitectura/capacidades SIMD
      cycle_counter.zig     # Lectura de ciclos de CPU
      hash.zig              # Hashes para gradientes
      math.zig              # Utilidades matemáticas compartidas
    f32/
      types.zig
      table.zig
      vector_math.zig       # Helpers SIMD para f32
    i16/
      types.zig
      table.zig
      vector_math.zig       # Operaciones Q0.15 + intrinsics AVX/NEON

  noise/perlin/
    mode_meta.zig          # Enums compartidos (SampleKind)
    00_ref.zig
    01_custom_hash.zig
    02_caching.zig
    03_tiling.zig
    04_licm.zig
    05_simd.zig
    06_fpa.zig
    registry.zig           # Mapeo O0..O6 -> implementación + metadatos
```

### Flujo de ejecución (alto nivel)

1. `main.zig` valida argumentos (`O0..O6`) y delega en `benchmark/engine.zig`.
2. `engine.zig` consulta `noise/perlin/registry.zig` para resolver `ModeSpec` (módulo, tipo de dato, layout de memoria, alineación).
3. `benchmark/f32/run_mode.zig` o `benchmark/i16/run_mode.zig` inicializa buffers/config y ejecuta:
    - `runner.run_warmup`
    - `runner.run_benchmark_pass`
    - `report.print_benchmark_report`
    - `image_writer.write_composite_image`
4. `image_writer` delega en `benchmark/image/*` para construir la imagen compuesta y guardarla como PNG.

## Salida

Cada ejecución genera:

- Resumen de rendimiento en consola (tiempo, Mpts/s, ciclos/punto)
- Imagen en `output/perlin_composite_*_zig_<modo>.png`

## Limitaciones y restricciones actuales

Estas restricciones salen del código actual de las variantes (`O0..O6`) y del pipeline de benchmark.

### Restricciones obligatorias

- `SCALE` debe ser **potencia de 2** y `> 0`.
  - Se usa `@ctz(SCALE)` y máscara `SCALE - 1` para indexación modular (`idx & (SCALE - 1)`).
  - Si no es potencia de 2, la indexación de tiles/celdas deja de ser correcta.
- En modos vectoriales, `min(CHUNK_SIZE, SCALE)` debe ser múltiplo del ancho vectorial.
  - `O5` (`f32`): múltiplo de `LANES` (**8 con AVX2**, **16 con AVX512BW**, **4 con NEON**).
  - `O6` (`i16`): múltiplo de `LANES``; **16 con AVX2**, **32 con AVX512BW**, **8 con NEON**).
  - Si no se cumple, falla la validación de `comptime` en la inicialización de configuración.
- Validaciones en `comptime` por modo:
  - `O4`: valida potencia de 2 en `SCALE`.
  - `O5` y `O6`: validan potencia de 2 en `SCALE` y múltiplo de ancho vectorial en `min(CHUNK_SIZE, SCALE)`.
- El modo `O6` (`i16`) requiere backend SIMD válido para su ancho vectorial.
- La alineación requerida por cada modo debe respetarse.
  - Se obtiene vía `registry.get_mode_spec(...).required_alignment` y se valida como potencia de 2.
  - El código ya reserva buffers con esa alineación (`alignedAlloc`).

### Restricciones prácticas/recomendadas
- Para benchmark estable, usa `CHUNK_SIZE` y `SCALE` como potencias de 2 y, preferiblemente, iguales (por ejemplo `256/256`, como en `config.zig`).
- En `i16` (`O6`), mantener `SCALE <= 32768` evita problemas con la representación Q0.15 al precalcular `cached_values`.
- Si quieres portabilidad en targets sin backend SIMD válido para `i16`, usa `O0..O5`.

### Nota sobre parámetros no usados

- `OCTAVES`, `PERSISTENCE` y `LACUNARITY` forman parte de la config, pero en estas implementaciones actuales de benchmark no cambian el cálculo interno del chunk (single-octave efectivo).
