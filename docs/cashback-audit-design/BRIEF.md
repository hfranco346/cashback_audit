# Cashback Audit — brief para rediseño móvil

> Nombre provisional. La app todavía no tiene nombre ni marca definitivos.
> Estado al 8 de noviembre de 2026: MVP funcional, probado con estados de cuenta reales (BAC Credomatic y Banco Ficohsa, Honduras), sin publicar en tiendas.

## Encargo para Claude Design

**Qué se pide:** rediseñar la app móvil completa (las 13 pantallas de la sección 4) con una identidad propia, elegante y de "banca privada", resolviendo los problemas de la sección 9. La funcionalidad no cambia: el flujo, los datos y las reglas de las secciones 2 a 6 son fijos.

**Entregables:**
1. **Pantallas** en marco de teléfono de 390 × 844 pt (iPhone), cada una en **tema claro y oscuro**.
2. Para las pantallas con estados distintos, una variante por estado:
   - **Resultado:** "te pagaron de menos", "de más" y "bien"; lista de movimientos con verdes, rojos y grises.
   - **Confirmar porcentajes:** campos prellenados desde el estado de cuenta, un campo obligatorio vacío y el bloque de tipo de cambio.
   - **Home:** sin tarjetas (primer uso) y con tarjetas y verificaciones.
   - **Verificar:** eligiendo el archivo y analizando (espera de ~40 s).
   - **Paywall:** con verificación gratis disponible y sin créditos.
3. **Design system** resumido: paleta (claro y oscuro), escala tipográfica, espaciado, radios, elevación y los componentes clave (tarjeta de crédito, tarjeta de veredicto, fila de movimiento, campo de porcentaje con etiqueta de origen, chips, filtros, avisos).
4. **Notas breves por pantalla** que expliquen las decisiones, sobre todo cómo se resuelve cada problema de la sección 9.

**Restricciones:**
- Se construye en **Flutter con Material 3**: componentes y patrones nativos de móvil (hojas inferiores, chips, segmented buttons, listas, tarjetas). Nada que dependa de hover ni de efectos solo web.
- **Todo el texto en español neutro** (para Latinoamérica), en tono claro y directo, sin tecnicismos.
- **Montos siempre con código de moneda** ("HNL 1,526.84", "USD 42.00") y números tabulares alineados a la derecha. Los montos pueden ser largos y estar en monedas distintas en la misma pantalla.
- Los estados verde, rojo y gris de los movimientos **siempre llevan ícono y texto**, nunca solo color. Contraste AA en claro y oscuro.
- **Máximo 2–3 familias tipográficas.** Hoy se usan Bodoni Moda y Manrope (sección 7); se pueden cambiar si la propuesta lo justifica, siempre que sean de licencia libre.
- **Sin pantallas para funciones que no existen** (foto del estado de cuenta, ingreso manual, conexión al banco, comparación entre meses), salvo que se marquen como propuesta futura.
- **En el paywall no puede aparecer** ninguna mención a pagar fuera de la App Store o Google Play.

**Material de referencia adjunto:**
- capturas del diseño actual en claro y oscuro (`1_onboarding_login.png`, `2_home_tarjetas_rubros.png`, `3_confirmar_y_resultado.png`, `4_historial_paywall_ajustes.png`, `modo_oscuro.png`, `flujo_ficohsa.png`);
- este documento.

Usar los **datos de ejemplo de la sección 10** en lugar de inventar contenido.

---

## 1. Propósito

**Problema.** Las tarjetas de crédito prometen recompensas por categoría ("7% de cashback en supermercados y farmacias"), pero el estado de cuenta solo muestra un total ("Cash Back del mes: $42"). Nadie puede comprobar a mano si ese número es correcto: habría que revisar cada movimiento, decidir a qué rubro pertenece, aplicar el porcentaje, descontar devoluciones y convertir monedas.

**Solución.** El usuario sube el PDF de su estado de cuenta y la app le dice, en menos de un minuto, si el banco le pagó **lo correcto, de menos o de más**, con el detalle por rubro y por movimiento.

**Para quién.**
- Personas con una o varias tarjetas de crédito con cashback, puntos o millas, que gastan lo suficiente para que un error del banco importe.
- Mercado inicial: Centroamérica (Honduras) y Latinoamérica en general. El sistema funciona con cualquier banco, país, moneda y formato de estado de cuenta.
- Usuarios no técnicos: no saben qué es una "categoría MCC" ni quieren capturar movimientos a mano.

**Tono buscado.** Elegante, confiable, de "banca privada": una herramienta seria que usa gente que cuida su dinero. No es una app de juegos ni de descuentos.

**Modelo de negocio.**
- 1 verificación gratis al registrarse.
- Suscripción de USD 4.99 al mes con 5 verificaciones (no se acumulan de un mes a otro).
- Paquetes de verificaciones sueltas que no vencen (por ejemplo, 3 o 10).
- Cobro con el sistema de pagos de Apple y Google. Dentro de la app no se puede mencionar ningún otro medio de pago.
- Una "verificación" se consume solo cuando la IA lee el PDF con éxito. Recalcular, cambiar porcentajes o corregir rubros es gratis.

---

## 2. Cómo funciona la verificación

### De dónde salen los datos

| Fuente | ¿Soportada? |
|---|---|
| Estado de cuenta en **PDF** (el original que descarga el banco) | **Sí**, es la única fuente hoy |
| Foto o captura del estado de cuenta | No |
| Ingreso manual de movimientos | No |
| Conexión directa al banco | No |

El PDF se procesa en memoria y **nunca se guarda**. Tampoco se guarda el número completo de la tarjeta: solo los últimos 4 dígitos.

### Paso 1 — Lectura con IA (≈ 35–50 segundos)

Una IA (Claude Sonnet) lee el PDF y extrae:
- banco, últimos 4 dígitos, periodo y moneda principal;
- totales por moneda: compras, cargos e intereses, saldo;
- **cada movimiento**: fecha, comercio, monto, moneda y tipo (compra, devolución, pago a la tarjeta, comisión, interés, seguro u otro);
- la **tabla del programa de lealtad**: nombre del programa (CASH, PUNTOS, millas…), acumulado, disponible, canjeado, por vencer y castigado, con su moneda;
- los **porcentajes que el propio estado de cuenta menciona**, con la frase exacta como evidencia (por ejemplo, "Acumula Cash Back con tus compras 7% Supermercados");
- tipos de cambio impresos, si los hay.

Luego cada compra se asigna a un rubro del usuario:
1. **Coincidencia exacta**: si el texto del movimiento contiene un comercio o alias que el usuario registró ("WALMART", "MAXI DESPENSA").
2. **Clasificación con IA** (Claude Haiku) para el resto, por el significado del rubro. "FARMACIA KIELSA 61" cuenta como Farmacia aunque el usuario nunca haya registrado Kielsa. Se acepta solo si la confianza es ≥ 70%, y se guarda un motivo corto en español.
3. Si el banco menciona un rubro que el usuario no tiene (por ejemplo, "Restaurantes y Comida rápida"), la app **lo sugiere** y marca qué movimientos le corresponderían.

### Paso 2 — Confirmar porcentajes

Cada banco y cada país tiene políticas distintas que cambian con el tiempo, así que **la app siempre le pide al usuario confirmar los porcentajes** antes de calcular. El formulario se arma solo:
- un campo de **tasa base** (lo que acumula todo lo que no es de un rubro especial);
- un campo **por cada rubro** que aparece en el estado de cuenta;
- cada campo llega **prellenado** con una de estas fuentes, en este orden: lo que dice el estado de cuenta (con la frase como evidencia), las reglas guardadas en la tarjeta, o vacío. **Si está vacío, es obligatorio** y no se puede continuar;
- **tipo de cambio de la recompensa**, obligatorio cuando el banco paga en otra moneda (por ejemplo, Ficohsa paga cashback en USD y las compras son en lempiras);
- **tipos de cambio de compras en otras monedas**, opcionales: si se dejan vacíos, esas compras quedan fuera con un aviso;
- tope mensual opcional por rubro;
- opción "Guardar estos % en la tarjeta".

### Paso 3 — Cálculo y veredicto

**El cálculo lo hace código, nunca la IA**, para que sea exacto y auditable:
- recompensa esperada = suma de (monto × % del rubro), con la tasa base para el resto;
- las devoluciones restan; pagos, comisiones, intereses, seguros y bonificaciones no cuentan;
- se aplican topes mensuales por rubro;
- se convierte a la moneda de la recompensa si es distinta;
- para tarjetas de puntos, se multiplica por los puntos por unidad de moneda;
- se redondea según la moneda (el yen sin decimales, la mayoría con 2).

**Recompensa recibida:** el valor del programa de lealtad que el usuario audita (por ejemplo, "CASH BAC CREDOMATIC"), en su moneda.

**Veredicto:**
| Resultado | Condición |
|---|---|
| **Te pagaron bien** (coincide) | La diferencia está dentro de la tolerancia: el mayor entre 1 unidad y el 1% de lo esperado |
| **Te pagaron de menos** | Recibido < esperado − tolerancia |
| **Te pagaron de más** | Recibido > esperado + tolerancia |

Además, otra IA (Haiku) redacta una **explicación corta en español** usando los números ya calculados. No hace cuentas.

**Avisos automáticos:**
- el estado de cuenta es de otra tarjeta (los últimos 4 dígitos no coinciden);
- hay compras en otra moneda sin tipo de cambio;
- los movimientos no suman el total de compras del estado de cuenta;
- el valor reportado parece un saldo acumulado y no lo ganado en el mes.

**Después del resultado**, sin costo, el usuario puede:
- cambiar el rubro de un movimiento y recalcular;
- recalcular con otros porcentajes o tipo de cambio;
- "recordar" un comercio en un rubro para futuras verificaciones.

---

## 3. Bancos, tarjetas y reglas soportadas

- **Bancos:** cualquiera. No hay lógica específica por banco; la IA interpreta cualquier formato. Probado con BAC Credomatic y Banco Ficohsa (Honduras).
- **Monedas:** cualquiera, con código ISO (HNL, USD, EUR, CRC, MXN, GTQ…). Un mismo estado de cuenta puede tener varias monedas, y la recompensa puede pagarse en una moneda distinta a la de las compras.
- **Tarjeta** (la crea el usuario):
  - alias, banco, últimos 4 dígitos y red (opcional);
  - tipo de recompensa: **cashback en dinero** o **puntos/millas** (con "puntos por unidad de moneda");
  - **tasa base %**;
  - **reglas por rubro**: % y tope mensual opcional;
  - moneda principal de la tarjeta;
  - **programa a auditar** (opcional, por ejemplo "CASH BAC"), cuando el banco tiene varios programas;
  - **moneda en que se recibe la recompensa** (opcional; si se deja vacía se detecta sola).
- **Rubros:** los define el usuario (Supermercados, Farmacia, Restaurantes…), con una descripción opcional.
- **Comercios:** pertenecen a un rubro y tienen alias tal como aparecen en el estado de cuenta.
- **Periodo:** el del estado de cuenta (de corte a corte). Los topes se aplican por estado de cuenta.

---

## 4. Pantallas actuales

| # | Pantalla | Objetivo | Muestra | Acciones | Lleva a |
|---|---|---|---|---|---|
| 1 | **Splash** | Arranque | Logo y nombre sobre fondo verde | — (automática) | Onboarding, Login o Home |
| 2 | **Onboarding** (4 páginas) | Explicar el valor y generar confianza | 1) "Comprueba lo que tu banco te debe" · 2) "Registra tus tarjetas y rubros" · 3) "Sube el PDF y revisa el veredicto" · 4) "Tu privacidad primero" (no guardamos el PDF ni el número completo) | Continuar, Omitir, deslizar; en la última página, Empezar | Login |
| 3 | **Login** | Crear cuenta o entrar | Título "Inicia sesión", texto de beneficio, nota de privacidad | Continuar con Google; Continuar con Apple (solo iOS) | Home |
| 4 | **Home** | Centro de control | Saludo; chip "N verificaciones disponibles"; botones Verificar estado e Historial; carrusel de tarjetas (alias, banco, •••• últimos 4, tasa base, nº de reglas); últimas verificaciones (veredicto, tarjeta, periodo, diferencia, esperado); "Pendiente de confirmar %" | Verificar, Historial, Agregar tarjeta (botón flotante), tocar tarjeta (editar), mantener presionada (eliminar), ícono de rubros, ícono de perfil, tocar verificación | Subir estado, Historial, Formulario de tarjeta, Rubros, Ajustes, Resultado o Confirmar % |
| 5 | **Formulario de tarjeta** | Crear o editar una tarjeta | Alias, banco, últimos 4, red, tipo de recompensa, puntos por unidad, tasa base, moneda, programa a auditar, moneda de la recompensa (con sugerencias USD/EUR/MXN…), editor de reglas (rubro + % + tope) | Guardar, agregar o quitar reglas | Home |
| 6 | **Rubros y comercios** | Administrar rubros y sus comercios | Lista de rubros con número de comercios; comercios de cada rubro con sus alias | Crear, editar o eliminar rubro (al eliminar uno en uso pide a cuál mover sus comercios); crear, editar o mover comercio de rubro | — (hojas inferiores) |
| 7 | **Verificar estado de cuenta** | Subir el PDF | Selector de tarjeta, selector de archivo, saldo de verificaciones; durante la carga, una animación por pasos ("Leyendo estado de cuenta" → "Clasificando movimientos") | Elegir tarjeta, elegir PDF, analizar | Confirmar %, o Paywall si no hay créditos |
| 8 | **Confirmar porcentajes** | Validar los % antes de calcular | Rubros sugeridos por el banco (con casillas, % y nº de movimientos); tarjeta de tasa base; una tarjeta por rubro con etiqueta de origen ("Detectado en tu estado de cuenta" con la cita, o "De las reglas de tu tarjeta"), campo % y tope; bloque de tipo de cambio de la recompensa (obligatorio, con etiqueta "Obligatorio"); tipos de cambio de otras monedas; selector de programa si hay varios | Crear rubros sugeridos (gratis), editar %, ingresar tipo de cambio, "Guardar estos % en la tarjeta", Calcular resultado (desactivado si falta un campo obligatorio) | Resultado |
| 9 | **Resultado** | Mostrar el veredicto y su detalle | Tarjeta de veredicto (ícono, "Te pagaron de menos / de más / bien", frase, Esperado / Reportado / Diferencia, "Equivale a HNL …"); "En pocas palabras" (explicación de la IA); avisos; porcentajes usados y tipo de cambio; tabla de programas de lealtad; subtotales por moneda; desglose por rubro; lista de movimientos con filtro Todos / En rubro / Sin rubro / Excluidos | Recalcular con otros %; tocar movimiento → cambiar rubro (gratis); "Recordar comercio en un rubro"; filtrar | Confirmar % (recalcular), hoja de selección de rubro |
| 10 | **Historial** | Ver verificaciones pasadas | Lista con veredicto, tarjeta, periodo y diferencia; "Pendiente de confirmar %" | Filtrar por tarjeta, abrir | Resultado o Confirmar % |
| 11 | **Paywall** | Vender verificaciones | Beneficios, aviso de la verificación gratis, plan mensual y paquetes de la tienda | Suscribirme, comprar paquete, restaurar compras, cerrar | Vuelve al flujo anterior |
| 12 | **Perfil y ajustes** | Cuenta y preferencias | Nombre y correo; verificaciones (gratis, plan y compradas); estado de la suscripción; **Apariencia** (Sistema / Claro / Oscuro) | Comprar verificaciones, ver historial de créditos, ver planes, restaurar compras, cerrar sesión, cambiar tema | Paywall, Historial de créditos, Login |
| 13 | **Historial de créditos** | Transparencia del saldo | Movimientos de créditos: otorgado, usado, devuelto, vencido | — | — |

**Estados que el diseño debe cubrir en todas las pantallas:** carga, vacío (sin tarjetas, sin rubros, sin verificaciones), error con mensaje en español, modo sin conexión (la app muestra lo último guardado en el teléfono), claro y oscuro.

---

## 5. Flujo principal

1. **Primera apertura:** Splash → Onboarding (4 páginas) → Login con Google o Apple.
2. **Configuración inicial:**
   - crear la primera tarjeta (banco, últimos 4, tipo de recompensa, tasa base, reglas por rubro);
   - crear rubros (por ejemplo Supermercados y Farmacia); los comercios son opcionales, porque la IA clasifica por el significado del rubro.
3. **Verificar:** Home → Verificar estado → elegir tarjeta → elegir PDF → esperar ~40 s (consume 1 verificación).
4. **Confirmar:** revisar los % prellenados, crear rubros sugeridos por el banco, llenar los campos obligatorios (por ejemplo, el tipo de cambio) → Calcular.
5. **Resultado:** veredicto, diferencia, explicación, desglose y movimientos en verde (contó en un rubro), rojo (sin rubro, solo tasa base) o gris (no genera recompensa).
6. **Ajustar (gratis):** corregir el rubro de movimientos o cambiar % y recalcular.
7. **Después:** el resultado queda en Historial. Para la siguiente verificación, si no hay créditos → Paywall.

---

## 6. Modelo de datos

| Entidad | Campos clave | Relación |
|---|---|---|
| **Usuario** | proveedor (Google/Apple), correo, nombre | Tiene tarjetas, rubros, comercios, verificaciones, créditos y suscripción |
| **Tarjeta** | alias, banco, últimos 4, red, tipo de recompensa (cashback o puntos), puntos por unidad, tasa base %, moneda, programa a auditar, moneda de la recompensa | Tiene reglas y verificaciones |
| **Regla de tarjeta** | rubro, %, tope mensual | Une una tarjeta con un rubro |
| **Rubro** | nombre, descripción | Tiene comercios y reglas |
| **Comercio** | nombre, alias tal como aparecen en el estado de cuenta, rubro | Pertenece a un rubro |
| **Verificación** | estado (pendiente de confirmar / completada), banco, periodo, moneda principal, totales, programa auditado y valor reportado, esperado, diferencia, tolerancia, veredicto, moneda de la recompensa, % detectados, % aplicados, tipos de cambio, explicación, avisos, desglose por rubro, movimientos, modelos de IA usados | Pertenece a una tarjeta |
| **Movimiento** (dentro de la verificación) | fecha, comercio, monto, moneda, monto convertido, tipo, tipo de crédito, rubro, origen de la clasificación (alias / IA / usuario / ninguno), motivo, rubro sugerido por el banco, % aplicado, recompensa esperada, motivo de exclusión | — |
| **Movimiento de créditos** | +/− cantidad, bolsa (gratis / plan / comprados), motivo (otorgado, usado, devuelto, vencido), origen (Apple, Google, web, sistema) | Historial inmutable; el saldo se calcula de aquí |
| **Suscripción** | estado, vencimiento, tienda, producto, renovación automática | — |

---

## 7. Stack técnico y design system actual

**App móvil:** Flutter (iOS y Android).
- Estado, navegación e inyección de dependencias: **GetX**.
- Animaciones: **animate_do** (entradas, revelado del veredicto, transiciones Hero).
- Base de datos local para modo sin conexión: **Drift**.
- Login: Google Sign-In y Sign in with Apple.
- Pagos: **RevenueCat** sobre las compras de Apple y Google.
- Componentes: **Material 3**, organizados con atomic design.

**Backend:** NestJS, PostgreSQL y la API de Claude (Sonnet para leer PDFs, Haiku para clasificar y explicar).

### Colores

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| Primario | `#0B5C54` (verde petróleo) | `#7FD6C8` | Botones, tarjetas de crédito, splash |
| Secundario | `#3F6B66` | derivado | Acciones secundarias |
| Fondo | `#F3F6F5` | `#0C1514` | Fondo de pantallas |
| Superficie de tarjeta | blanco / derivado | `#142120` | Tarjetas y contenedores |
| Éxito / coincide / "Contó en rubro" | `#0B7A5B` sobre `#D7F2E8` | `#58D3A8` sobre `#0E3A2E` | Veredicto "bien", movimientos verdes |
| Peligro / de menos / "Sin rubro" | `#C4351F` sobre `#FFE1DA` | `#FF8C77` sobre `#4A1A12` | Veredicto "de menos", movimientos rojos |
| De más | `#4A4FC4` sobre `#E3E4FF` | `#A9ADFF` sobre `#23265E` | Veredicto "de más" |
| Aviso | `#8A5A00` sobre `#FFEDC2` | `#F3C15B` sobre `#45310A` | Tarjetas de aviso |
| Neutro / excluido | `#5B6665` sobre `#E3E8E7` | `#A7B3B1` sobre `#273331` | Movimientos que no generan recompensa |

Los estados verde, rojo y gris **siempre van acompañados de ícono y texto**, nunca solo de color, por accesibilidad.

### Tipografía
- **Bodoni Moda** (serif de alto contraste, estética de billete o cheque): títulos grandes, títulos del onboarding, veredicto y monto de la diferencia.
- **Manrope** (sans geométrica): todo lo demás. Usa números tabulares para que los montos queden alineados.
- Las fuentes van incluidas en la app (licencia libre OFL).

### Componentes existentes
- **Átomos:** marca del logo, indicador de páginas, encabezado de sección, entrada escalonada.
- **Moléculas:** estado vacío, mensaje en línea, botón de acción rápida, botón de login social.
- **Por funcionalidad:**
  - tarjeta de crédito visual;
  - editor de reglas;
  - campo de moneda;
  - hojas de rubro y de comercio;
  - chip y tarjeta de créditos;
  - tarjeta de veredicto;
  - tarjeta de explicación;
  - tarjeta de porcentaje (con etiqueta de origen y cita);
  - tarjeta de conversión de recompensa;
  - tarjeta de tipos de cambio;
  - tarjeta de rubros sugeridos;
  - tabla de programas de lealtad;
  - subtotales por moneda;
  - desglose por rubro;
  - movimiento (verde, rojo o gris);
  - filtro de movimientos;
  - progreso de análisis;
  - fila de verificación;
  - sección de apariencia;
  - estado de suscripción.

### Modos
- Tema claro y oscuro: sigue al sistema, o el usuario elige en Ajustes.

---

## 8. Funcionalidades pendientes o a medio hacer

- **Nombre, logo e identidad de marca:** no existen todavía.
- **Login real:** el código de Google y Apple está listo, pero faltan las credenciales de cada consola. Hoy solo se entra con un acceso de desarrollo.
- **Compras:** el paywall está construido, pero faltan los productos en App Store y Google Play y la configuración de RevenueCat. Hoy muestra un aviso de "compras no configuradas".
- **Fuentes de datos alternativas:** no hay foto ni captura, ingreso manual ni conexión con el banco.
- **Despliegue del backend:** hoy corre solo en la computadora de desarrollo.
- **Página web de pago:** prevista a futuro para vender créditos fuera de las tiendas. No puede mencionarse dentro de la app.
- **Mejor clasificación:** la IA no siempre reconoce cafeterías como restaurantes ni tiendas locales como "tiendas por departamento". El usuario puede corregirlo a mano.
- **Notificaciones:** no hay recordatorio del tipo "llegó tu estado de cuenta, verifícalo".
- **Comparación entre meses:** no hay tendencias ni acumulado de lo que el banco te debe en el año.
- **Exportar o compartir el resultado** para reclamar al banco: no existe.
- **Límite de abuso** de la verificación gratis (por ejemplo, una por dispositivo): no existe.
- **Ambigüedad del valor reportado:** columnas como "Acumulados" pueden ser el saldo total del programa y no lo ganado en el mes. Hoy solo se avisa con un mensaje.

---

## 9. Problemas conocidos de UX y diseño

**Generales**
- **La espera de ~40 segundos** al leer el PDF es larga. La animación por pasos ayuda, pero es simulada (avanza por tiempo, no por progreso real).
- **Dos acciones parecidas en los movimientos rojos:** tocar el movimiento cambia su rubro en esta verificación, y "Recordar comercio en un rubro" lo guarda para el futuro. La diferencia no es evidente.
- **Conceptos difíciles:** "tasa base", "tope mensual", "programa a auditar" y "tipo de cambio de la recompensa" necesitan explicación. La dirección del tipo de cambio ("¿Cuántos HNL vale 1 USD?") se presta a errores.

**Pantalla de resultado**
- **Es muy larga:** veredicto, explicación, avisos, porcentajes, programas, subtotales, desglose y hasta ~50 movimientos en una sola columna. Falta jerarquía o separación (pestañas, secciones plegables).
- **La explicación de la IA es un párrafo largo** y denso.
- **La tabla de programas de lealtad se corta** a la derecha en pantallas angostas (la columna "Canjeado" queda fuera).
- **Los filtros de movimientos** (Todos / En rubro / Sin rubro / Excluidos) se salen de la pantalla y hay que deslizarlos.
- **Los nombres de comercio** vienen en mayúsculas y truncados, tal como los imprime el banco ("SUPERMERCADOS DEL CORRAL COMAYAGUA HN").
- **Varios avisos amarillos seguidos** compiten con el veredicto.

**Otras pantallas**
- **Home:**
  - El botón flotante "Agregar tarjeta" tapa parte de la lista de verificaciones.
  - Las filas de verificación cortan el periodo ("21 sep 2…").
- **Eliminar una tarjeta** se hace manteniéndola presionada: no se descubre. Hoy hay un texto de ayuda al pie.
- **Los títulos de pantalla** ("Resultado", "Confirma los porcentajes") son pequeños y no usan la tipografía de marca.
- **La pantalla de rubros y comercios** es funcional pero plana. No guía al usuario nuevo sobre por qué crear rubros.
- **El formulario de tarjeta es largo** y mezcla campos básicos (alias, banco) con avanzados (puntos por unidad, programa, moneda de recompensa).
- **El paywall** no muestra precios mientras las compras no estén configuradas, así que no se puede evaluar su diseño final.

---

## 10. Datos de ejemplo para las pantallas

Montos redondeados e ilustrativos, basados en las pruebas reales.

**Usuario:** Ana Martínez · ana@correo.com · 1 verificación gratis disponible.

**Tarjetas**
| Alias | Banco | Últimos 4 | Recompensa | Tasa base | Reglas |
|---|---|---|---|---|---|
| BAC Cash | BAC Credomatic | 4821 | Cashback en HNL, programa "CASH BAC CREDOMATIC" | 0% | Supermercados 7% · Farmacia 7% |
| Ficohsa Signature | Banco Ficohsa | 3618 | Cashback en USD, programa "Cash Back" | 0% | Supermercados 7% · Farmacia 7% · Restaurantes y Comida rápida 7% |

**Rubros:** Supermercados (Del Corral, Maxi Despensa, La Colonia) · Farmacia (Kielsa, Farmacias del Ahorro) · Restaurantes y Comida rápida.

**Verificación 1 — BAC, 3 oct – 3 nov 2026 · Te pagaron de menos**
- 52 movimientos: 26 en rubro, 12 sin rubro, 14 excluidos. Moneda principal HNL; 8 compras en USD sin tipo de cambio.
- Supermercados: HNL 20,686.07 en 23 movimientos → HNL 1,448.02.
- Farmacia: HNL 1,125.97 en 3 movimientos → HNL 78.82.
- Esperado **HNL 1,526.84** · Reportado **HNL 0.00** (CASH BAC CREDOMATIC) · Diferencia **–HNL 1,526.84**.
- Avisos: compras en moneda extranjera sin tipo de cambio.
- Movimientos de ejemplo:
  - verde: "SUPERMERCADOS DEL CORRAL COMAYAGUA HN · HNL 1,140.56 · Supermercados · IA · 7% · +HNL 79.84";
  - rojo: "COMIDAS ESPECIALES EBERSO · HNL 297.86 · Sin rubro · tasa base 0%";
  - gris: "PAGO RECIBIDO · –HNL 68,531.56 · Pago a la tarjeta" y "SEGURO DE SALDO DE DEUDA · HNL 112.13 · Seguro".

**Verificación 2 — Ficohsa, 21 sep – 21 oct 2026 · Te pagaron de más**
- 34 movimientos: 11 en rubro, 17 sin rubro, 6 excluidos. Compras en HNL, recompensa en USD.
- El estado de cuenta dice: "Acumula Cash Back con tus compras 7% Supermercados / Tiendas por Departamento / Farmacias y Hospitales / Restaurantes y Comida rápida / Débitos automáticos en educación".
- Rubros sugeridos por el banco: Tiendas por Departamento (7%, 0 movimientos) · Débitos automáticos en educación (7%, 0 movimientos).
- Tipo de cambio de la recompensa: 1 USD = 26.00 HNL (lo ingresó el usuario).
- Farmacia (incluye un hospital): HNL 4,579.80 → HNL 320.59 · Restaurantes: HNL 3,843.21 → HNL 269.02.
- Esperado **USD 22.68** (equivale a HNL 589.61) · Reportado **USD 42.00** · Diferencia **+USD 19.32**.
- Programa: Cash Back · acumulado USD 42 · disponible USD 256.
- Explicación de la IA: "El banco te reportó USD 42.00 y lo esperado era USD 22.68, así que te pagaron de más por USD 19.32. La categoría que más pesa es Farmacia."

**Verificación 3 — pendiente de confirmar %:** Ficohsa Signature, 21 sep – 21 oct 2026.

**Créditos:** Gratis 1 · Plan 0 · Comprados 0. **Plan:** USD 4.99/mes, 5 verificaciones. **Paquetes:** 3 verificaciones · 10 verificaciones.
