# Cashback Audit — handoff de diseño para implementar en Flutter

Este paquete contiene el rediseño móvil completo (español e inglés, claro y oscuro) para implementarlo en la app Flutter existente (GetX, Material 3, atomic design). La funcionalidad, los datos y las reglas no cambian: ver `BRIEF.md`.

## Cómo leer los archivos de diseño

- `project/*.dc.html` — una "mesa de trabajo" por pantalla. Es HTML con estilos en línea y una mini plantilla:
  - `<sc-for list="{{cells}}">` repite el teléfono por cada **estado × tema**. Cada teléfono es un `div.ph` de 390 × 844.
  - `<sc-if value="{{c.estado}}">` muestra el bloque de cada estado (por ejemplo `c.empty`, `c.fresh`, `c.full`).
  - El `<script>` final (`renderVals()`) tiene los datos de ejemplo y la lista de estados de cada pantalla.
  - Los colores salen de variables CSS: la clase `.lt` es el tema claro y `.dk` el oscuro (mismos nombres de token).
  - `support.js` no se incluye: es el runtime del lienzo y no hace falta para implementar.
- `project/canvas.json` — índice del lienzo: título de cada pantalla y **notas de diseño** (`notes`) que explican qué problema resuelve cada una.
- Archivos `*-en.dc.html` = versión en inglés de la misma pantalla.

## Mapa de pantallas

| # | Pantalla | Archivo (ES / EN) | Estados dibujados |
|---|---|---|---|
| — | Design system | `Main.dc.html` | paleta claro/oscuro, tipografía, espaciado, radios, elevación, componentes |
| 1–3 | Splash + onboarding dinámico + login | `Bienvenida` / `Bienvenida-en` | splash, demo animada (+ demo con teléfono en inglés), banco, tarjeta, rubros y %, crear cuenta, primer PDF, primer veredicto |
| 4 | Home | `Home` / `Home-en` | se saltó el onboarding (vacío), recién terminado el onboarding, uso continuo |
| 5 | Formulario de tarjeta | `Tarjeta` / `Tarjeta-en` | básico, opciones avanzadas abiertas |
| 6 | Rubros y comercios | `Rubros` / `Rubros-en` | vacío guiado, con rubros y comercios |
| 7 | Verificar estado de cuenta | `Verificar` / `Verificar-en` | eligiendo archivo, analizando (~40 s) |
| 8 | Confirmar porcentajes | `Confirmar` / `Confirmar-en` | prellenados + rubros sugeridos, campo obligatorio vacío + tipo de cambio |
| 9 | Resultado | `Resultado` / `Resultado-en` | de menos, de más, bien, movimientos (filtro), hoja "cambiar rubro" |
| 10 | Historial | `Historial` / `Historial-en` | con conexión, sin conexión |
| 11 | Paywall | `Paywall` / `Paywall-en` | con verificación gratis, sin créditos |
| 12–13 | Perfil, historial de créditos, idioma y monedas | `Ajustes` / `Ajustes-en` | perfil, historial de créditos, idioma y monedas |
| futuro | Reclamo al banco | `Reclamo` / `Reclamo-en` | correo en ES / EN, tono formal o firme (marcado como propuesta futura) |

## Tokens → Flutter

Mapear a `ColorScheme` de M3 + un `ThemeExtension` para los colores de estado.

| Token CSS | Uso | Claro | Oscuro | Flutter sugerido |
|---|---|---|---|---|
| `--bg` | fondo | `#F6F4EF` | `#0C1211` | `surface` / `scaffoldBackgroundColor` |
| `--surf` | tarjetas | `#FFFFFF` | `#141C1B` | `surfaceContainerLowest` |
| `--surf2` | superficie 2 | `#EFECE5` | `#1B2523` | `surfaceContainerHigh` |
| `--ink` | texto | `#16201E` | `#EDF0EC` | `onSurface` |
| `--mut` | texto secundario | `#5C6664` | `#A2ACA9` | `onSurfaceVariant` |
| `--line` | bordes | `#E2DED5` | `#2A3533` | `outlineVariant` |
| `--pri` / `--onpri` | botón principal | `#0F3D36` / `#FFFFFF` | `#8FD3C3` / `#08201B` | `primary` / `onPrimary` |
| `--pric` / `--onpric` | chips, contenedores | `#D8E8E3` / `#0F3D36` | `#1F3A35` / `#BFE7DD` | `primaryContainer` / `onPrimaryContainer` |
| `--brass` | filete latón (ornamento) | `#8A6D33` | `#CDAE6E` | `tertiary` |
| `--card` / `--oncard` | tarjeta de crédito | `#0F3D36` / `#F3EBDA` | `#183F38` / `#F3EBDA` | extensión `creditCard` |
| `--okf` / `--okb` | bien / en rubro (verde) | `#17734F` / `#DDF0E5` | `#62D2A2` / `#0F3427` | extensión `success` |
| `--erf` / `--erb` | de menos / sin rubro (rojo) | `#B42318` / `#FBE3DF` | `#FF907F` / `#45150E` | `error` / `errorContainer` |
| `--ovf` / `--ovb` | de más | `#4338A8` / `#E6E4F7` | `#B4AEFF` / `#262159` | extensión `overpaid` |
| `--wnf` / `--wnb` | aviso | `#7A5300` / `#F8ECCB` | `#F0C462` / `#3D2C07` | extensión `warning` |
| `--ntf` / `--ntb` | excluido (gris) | `#545D5B` / `#E9E8E3` | `#A9B2AF` / `#232C2B` | extensión `neutral` |

- **Tipografía:** Bodoni Moda solo en ≥ 22 px (títulos de pantalla 26–34, veredicto, monto de la diferencia). Manrope para todo lo demás, con `FontFeature.tabularFigures()` en montos. Montos siempre con código ISO ("HNL 1,526.84") y alineados a la derecha.
- **Espaciado:** base 4; márgenes de pantalla 20; separación entre bloques 14–18.
- **Radios:** chips 10 · campos 14 · tarjetas 18–20 · hojas inferiores 28 · botones pill (999).
- **Elevación:** nivel 0 = borde `outlineVariant`; nivel 1 = sombra suave; hojas con sombra fuerte. En oscuro, elevación con superficies más claras, no sombras.
- **Táctiles:** mínimo 44–48 px de alto.
- Verde, rojo y gris **siempre con ícono + texto**, nunca solo color.

## Componentes clave (para atomic design)

- Tarjeta de crédito (`.cc`): fondo `creditCard`, filete interior latón, alias en Bodoni, `•••• últimos 4`, moneda arriba a la derecha.
- Tarjeta de veredicto: chip de estado con ícono → título Bodoni → monto Bodoni → Esperado / Reportado → equivalencia opcional.
- Fila de movimiento (`.mv`): punto de estado con ícono, nombre limpio en negrita, texto original del banco en pequeño, estado en color, monto + recompensa a la derecha; botón "Asignar rubro" en los rojos.
- Campo de porcentaje con etiqueta de origen: "Detectado en tu estado de cuenta" (+ cita con filete latón) / "De las reglas de tu tarjeta" / "Obligatorio".
- Segmented button de filtros (4 opciones con contador debajo, sin scroll).
- Aviso plegable único (amarillo) en lugar de varios avisos seguidos.
- Hoja inferior "Cambiar rubro" con el interruptor "Recordar para próximas verificaciones" (reemplaza las dos acciones confusas).
- Barra de navegación M3: Inicio · Historial · Rubros · Perfil (sin FAB).

## Reglas de comportamiento nuevas

1. **Onboarding dinámico:** cada paso guarda datos reales (banco → tarjeta → últimos 4, tipo y moneda → rubros con % y tasa base → login → primer PDF con la verificación gratis → primer veredicto). El login va al final, cuando ya hay algo que guardar. Barra de progreso "Paso N de 5" y "Atrás" siempre visibles.
2. **Home refleja el onboarding:** al terminarlo, Home muestra exactamente la tarjeta, rubros, % y la primera verificación registrados, más el aviso de compras sin rubro. Si el usuario se lo salta, Home muestra el estado vacío con la opción de volver a la configuración guiada.
3. **Idioma:** al abrir, leer el idioma del teléfono (`PlatformDispatcher.instance.locale`): `en-*` → inglés; cualquier otro → español. Se puede cambiar en Perfil › Idioma y monedas (Automático / Español / English) y desde el selector de la demo del onboarding. Todos los textos en ARB (`intl`). El texto que viene del banco (comercios, citas, nombre del programa) no se traduce.
4. **Monedas preferidas:** moneda principal para equivalencias y lista de monedas del usuario con su último tipo de cambio; se sugieren primero al crear tarjetas y al pedir tipos de cambio.
5. **Reclamo (futuro):** el idioma del correo arranca igual que el de la app, pero se elige aparte.

## Datos de ejemplo

Todos vienen de la sección 10 de `BRIEF.md`. Excepciones ilustrativas: el veredicto "te pagaron bien", el historial de créditos y los precios de paquetes (`[PRECIO]`).
