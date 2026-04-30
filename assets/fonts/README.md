# Fuentes

El theme global (`ui/theme/theme_builder.gd`) usa `SystemFont` como pila de
fallback robusta:

| Rol | Pila SystemFont | Sustituto OS típico |
|-----|-----------------|---------------------|
| UI | Inter → Helvetica Neue → Arial → Liberation Sans → DejaVu Sans | Cualquier sans moderna |
| Display | Spectral → Cardo → Georgia → Liberation Serif → DejaVu Serif | Cualquier serif clásica |
| Mono | JetBrains Mono → Fira Mono → Liberation Mono → DejaVu Sans Mono | Cualquier mono |

## Para producción (recomendado)

Descargar las fuentes oficiales bajo licencia OFL y colocarlas aquí:

- [Inter](https://fonts.google.com/specimen/Inter): `Inter-Regular.ttf`,
  `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf`.
- [Spectral](https://fonts.google.com/specimen/Spectral): `Spectral-Regular.ttf`,
  `Spectral-SemiBold.ttf`, `Spectral-Bold.ttf`.

Una vez añadidas, actualizar `Tokens.font_ui()` y `Tokens.font_display()`
para preferirlas con `FontFile.new()` (variante `load_or_null` con
fallback al SystemFont).

## ¿Por qué no las commit-eamos directamente?

Esta build inicial mantiene el repo libre de binarios pesados. La pila
SystemFont produce un resultado consistente entre Linux/macOS/Windows/Android
porque siempre encuentra al menos `DejaVu Sans` / `Liberation Serif`.
