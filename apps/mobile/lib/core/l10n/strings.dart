/// All user-facing copy lives here (Spanish, neutral/Mexico) so it can be
/// moved to proper localization later. Identifiers stay in English.
abstract final class S {
  static const appName = 'Cashback Audit';
  static const tagline =
      'Verifica que tu banco te pague lo que te corresponde.';

  // Generic
  static const retry = 'Reintentar';
  static const cancel = 'Cancelar';
  static const save = 'Guardar';
  static const delete = 'Eliminar';
  static const edit = 'Editar';
  static const continueLabel = 'Continuar';
  static const skip = 'Omitir';
  static const back = 'Atrás';
  static const loading = 'Cargando…';
  static const offlineBanner = 'Sin conexión. Mostrando datos guardados.';

  // Errors
  static const errNetwork =
      'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
  static const errTimeout = 'La solicitud tardó demasiado. Inténtalo de nuevo.';
  static const errUnauthorized = 'Tu sesión expiró. Inicia sesión otra vez.';
  static const errNoCredits =
      'No tienes verificaciones disponibles. Suscríbete o compra un paquete para continuar.';
  static const errRatesRequired =
      'Escribe el porcentaje de los rubros marcados como obligatorios.';
  static const errProgramAmbiguous =
      'Tu estado de cuenta tiene varios programas de recompensa. Elige cuál auditar.';
  static const errTransactionNotFound = 'No encontramos ese movimiento.';
  static const errTransactionNotClassifiable =
      'Este movimiento no genera recompensa, así que no se puede asignar a un rubro.';
  static const errVerificationNotFound =
      'Esta verificación ya no existe. Las que no se confirman en 7 días se eliminan.';
  static const errValidation = 'Revisa los datos e inténtalo de nuevo.';
  static const errNotFound = 'No encontramos lo que buscabas.';
  static const errConflict =
      'Esa acción entra en conflicto con datos existentes.';
  static const errTooLarge = 'El archivo supera el límite de 10 MB.';
  static const errNotPdf = 'Solo se aceptan archivos PDF.';
  static const errRateLimited =
      'Demasiados intentos. Espera un momento e inténtalo otra vez.';
  static const errServer =
      'Algo salió mal de nuestro lado. Inténtalo de nuevo en unos minutos.';
  static const errUnknown = 'Ocurrió un error inesperado.';
  static const errCategoryNameTaken = 'Ya tienes un rubro con ese nombre.';
  static const errMerchantNameTaken = 'Ya tienes un comercio con ese nombre.';
  static const errCategoryInUse =
      'Este rubro tiene comercios o reglas de tarjeta. Elige a qué rubro moverlos.';
  static const errInvalidPdf = 'El archivo no es un PDF válido.';
  static const errUnreadable =
      'No pudimos leer ese estado de cuenta. Descarga el PDF original desde tu banco (no una foto ni un archivo con contraseña).';
  static const errRewardRateRequired =
      'Escribe cuánto vale la moneda de la recompensa para poder convertirla.';
  static const errInvalidExchangeRate =
      'Revisa los tipos de cambio: deben ser números mayores a 0 (máximo 6 decimales).';
  static const errRewardNotFound =
      'El estado de cuenta no muestra la recompensa que te dio el banco. Escríbela para continuar.';
  static const errExtractionFailed =
      'El análisis no devolvió un resultado utilizable. Suele funcionar al reintentar.';
  static const errExtractionUnavailable =
      'El servicio de análisis está ocupado. Inténtalo más tarde.';
  static const errIdentityToken =
      'No pudimos validar tu cuenta. Inténtalo de nuevo.';
  static const errIdentityUnavailable =
      'El inicio de sesión no está disponible por ahora.';

  static const errSignInFailed =
      'No pudimos completar el inicio de sesión. Inténtalo de nuevo.';

  // Session
  static const sessionExpiredTitle = 'Sesión finalizada';

  // Onboarding
  static const onb1Title = 'Comprueba lo que tu banco te debe';
  static const onb1Body =
      'Sube tu estado de cuenta y calculamos cuánto cashback o cuántos puntos deberías haber recibido.';
  static const onb2Title = 'Registra tus tarjetas y rubros';
  static const onb2Body =
      'Captura la tasa base de cada tarjeta y los porcentajes por rubro (súper, gasolina, restaurantes…). Asigna cada comercio al rubro en el que esperas que acumule.';
  static const onb3Title = 'Sube el PDF y revisa el veredicto';
  static const onb3Body =
      'Te mostramos si el pago coincide, si te pagaron de menos o de más, con el detalle por rubro y por movimiento.';
  static const onb4Title = 'Tu privacidad primero';
  static const onb4Body =
      'Nunca guardamos tu PDF ni el número completo de tu tarjeta: solo los últimos 4 dígitos y los resultados del análisis.';
  static const start = 'Empezar';

  // Login
  static const loginTitle = 'Inicia sesión';
  static const loginSubtitle =
      'Usa tu cuenta para guardar tus tarjetas, rubros y el historial de verificaciones.';
  static const signInGoogle = 'Continuar con Google';
  static const signInApple = 'Continuar con Apple';
  static const loginLegal =
      'No almacenamos tu PDF ni el número completo de tu tarjeta.';

  // Validation
  static const fieldRequired = 'Este campo es obligatorio';
  static String fieldTooLong(int max) => 'Máximo $max caracteres';
  static const last4Invalid = 'Escribe exactamente 4 dígitos';
  static const currencyInvalid = 'Usa un código de 3 letras (MXN, USD…)';
  static const numberInvalid = 'Escribe un número válido';
  static const percentRange = 'Debe estar entre 0 y 100';
  static const capInvalid = 'Debe ser mayor a 0 (máximo 2 decimales)';
  static const pointsFactorInvalid = 'Debe ser mayor a 0 y hasta 1000';

  // Home
  static String greeting(String? name) => name == null ? 'Hola' : 'Hola, $name';
  static const homeCards = 'Mis tarjetas';
  static const homeNoCardsTitle = 'Aún no tienes tarjetas';
  static const homeNoCardsBody =
      'Agrega tu primera tarjeta con sus tasas de recompensa para empezar a auditar.';
  static const addCard = 'Agregar tarjeta';
  static const manageCategories = 'Rubros y comercios';
  static const logout = 'Cerrar sesión';
  static const loadError = 'No pudimos cargar tus datos.';

  // Cards
  static const newCard = 'Nueva tarjeta';
  static const editCard = 'Editar tarjeta';
  static const cardAlias = 'Alias';
  static const cardAliasHint = 'Ej. Tarjeta diaria';
  static const cardBank = 'Banco';
  static const cardLast4 = 'Últimos 4 dígitos';
  static const cardLast4Helper = 'Nunca pedimos el número completo.';
  static const cardNetwork = 'Red (opcional)';
  static const cardCurrency = 'Moneda';
  static const cardRewardProgram = 'Programa de recompensa a auditar';
  static const cardRewardProgramHelper =
      'Opcional. Si tu estado de cuenta lista varios programas (p. ej. CASH BAC), escribe el nombre del que quieres auditar.';
  static const cardRewardCurrency = 'Moneda en que recibes la recompensa';
  static const cardRewardCurrencyHelper =
      'Opcional. Si tu banco paga la recompensa en otra moneda que tus compras (p. ej. dólares), indícala. Vacío = detectar automáticamente.';
  static const cardRewardCurrencyAuto = 'Detectar automáticamente';
  static const rewardUnitLabel = 'Tipo de recompensa';
  static const unitCashback = 'Cashback';
  static const unitPoints = 'Puntos';
  static const pointsPerUnit = 'Puntos por cada \$1 de recompensa';
  static const baseRate = 'Tasa base (%)';
  static const baseRateHelper = 'Se aplica a todo gasto sin regla por rubro.';
  static const rulesTitle = 'Reglas por rubro';
  static const rulesHelper =
      'Define una tasa distinta para cada rubro, con tope mensual opcional.';
  static const addRule = 'Agregar regla';
  static const ruleCategory = 'Rubro';
  static const ruleRate = 'Tasa (%)';
  static const ruleCap = 'Tope mensual';
  static const ruleCapHelper = 'Opcional';
  static const removeRule = 'Quitar regla';
  static const ruleNeedsCategories =
      'Primero crea al menos un rubro para definir reglas.';
  static const ruleCategoryRequired = 'Elige un rubro';
  static const ruleDuplicateCategory = 'Ya hay una regla para ese rubro';
  static const deleteCardTitle = 'Eliminar tarjeta';
  static String deleteCardBody(String alias) =>
      '¿Eliminar "$alias"? También se borrará su historial de verificaciones.';
  static const cardSaved = 'Tarjeta guardada';
  static const cardDeleted = 'Tarjeta eliminada';
  static String ruleCount(int n) =>
      n == 0 ? 'Sin reglas' : (n == 1 ? '1 regla' : '$n reglas');
  static String baseRateShort(String rate) => 'Base $rate';

  // Categories & merchants
  static const catalogTitle = 'Rubros y comercios';
  static const addCategory = 'Nuevo rubro';
  static const editCategory = 'Editar rubro';
  static const categoryName = 'Nombre del rubro';
  static const categoryDescription = 'Descripción (opcional)';
  static const addMerchant = 'Agregar comercio';
  static const editMerchant = 'Editar comercio';
  static const merchantName = 'Nombre del comercio';
  static const merchantKeywords = 'Palabras clave del estado de cuenta';
  static const merchantKeywordsHelper =
      'Como aparecen en tu estado de cuenta, separadas por coma. Ej. WAL MART, WALMART SUC';
  static const merchantCategory = 'Rubro esperado';
  static const noMerchants = 'Sin comercios';
  static const catalogEmptyTitle = 'Crea tu primer rubro';
  static const catalogEmptyBody =
      'Los rubros (súper, gasolina, restaurantes…) agrupan comercios y reciben tasas especiales en tus tarjetas.';
  static const deleteCategoryTitle = 'Eliminar rubro';
  static String deleteCategoryBody(String name) =>
      '¿Eliminar el rubro "$name"?';
  static String reassignBody(int merchants, int rules) =>
      'Este rubro tiene $merchants comercio(s) y $rules regla(s) de tarjeta. Elige a qué rubro moverlos antes de eliminarlo.';
  static const reassignTo = 'Mover a';
  static const reassignAndDelete = 'Mover y eliminar';
  static const deleteMerchantTitle = 'Eliminar comercio';
  static String deleteMerchantBody(String name) =>
      '¿Eliminar "$name"? Dejará de asignarse a su rubro.';
  static const needOtherCategory =
      'Crea otro rubro para poder mover los elementos.';
  static String merchantCount(int n) => n == 1 ? '1 comercio' : '$n comercios';

  static const settingsTitle = 'Perfil y ajustes';
  static const appearanceTitle = 'Apariencia';
  static const themeSystem = 'Sistema';
  static const themeLight = 'Claro';
  static const themeDark = 'Oscuro';
  static const longPressHint = 'Mantén presionada una tarjeta para eliminarla';

  // Upload
  static const uploadTitle = 'Verificar estado de cuenta';
  static const uploadStep1 = 'Elige la tarjeta';
  static const uploadStep2 = 'Selecciona el PDF';
  static const pickPdf = 'Elegir PDF';
  static const changePdf = 'Cambiar archivo';
  static const noCardsForUpload =
      'Primero agrega una tarjeta para poder verificar un estado de cuenta.';
  static const verify = 'Verificar';
  static const uploading = 'Subiendo archivo…';
  static const analyzing = 'Analizando tu estado de cuenta…';
  static const analyzingHint =
      'Puede tardar hasta un minuto. No cierres la app.';
  static const uploadPrivacy =
      'Procesamos el PDF en memoria y no lo guardamos.';
  static const fileTooLarge = 'El archivo supera el límite de 10 MB.';
  static const fileNotPdf = 'Elige un archivo PDF.';
  static const uploadTimeout =
      'El análisis tardó demasiado. Revisa tu historial antes de reintentar: puede que ya se haya procesado.';
  static const overrideTitle = 'Escribe la recompensa que te dio el banco';
  static const overrideLabel = 'Recompensa reportada';
  static const overrideHelper =
      'Búscala en tu estado de cuenta (bonificación o puntos del periodo).';
  static const overrideInvalid = 'Escribe un monto válido (hasta 2 decimales)';
  static const selectCardFirst = 'Elige una tarjeta';

  static const analyzingStepUpload = 'Archivo recibido';
  static const analyzingStepRead = 'Leyendo tu estado de cuenta';
  static const analyzingStepClassify = 'Clasificando movimientos';
  static const analyzingExpect =
      'Este paso suele tardar cerca de 1 minuto. Después podrás confirmar los porcentajes.';

  // Rate confirmation
  static const confirmRatesTitle = 'Confirma los porcentajes';
  static const recalcRatesTitle = 'Recalcular con otros %';
  static const confirmRatesIntro =
      'Los bancos cambian sus políticas seguido. Revisa con qué porcentajes vamos a calcular lo que deberías haber recibido.';
  static const confirmRatesNoCharge =
      'Calcular y recalcular no consume verificaciones.';
  static const rateBaseTitle = 'Tasa base';
  static const rateBaseSubtitle = 'Se aplica a todo gasto fuera de tus rubros.';
  static const rateFieldLabel = 'Porcentaje';
  static const rateCapLabel = 'Tope mensual (opcional)';
  static const badgeStatement = 'Detectado en tu estado de cuenta';
  static const badgeCardRule = 'De las reglas de tu tarjeta';
  static const badgePrevious = 'Los que usaste antes';
  static const badgeRequired = 'Obligatorio';
  static const rateRequiredError = 'Escribe el porcentaje para continuar';
  static String evidenceQuote(String text) => '“$text”';
  static const saveToCardTitle = 'Guardar estos % en la tarjeta';
  static const saveToCardSubtitle =
      'Reemplaza la tasa base y las reglas por rubro de tu tarjeta.';
  static const exchangeRateTitle = 'Tipo de cambio (opcional)';
  static String exchangeRateHelper(String primary) =>
      'Cuántos $primary vale 1 unidad de la moneda extranjera. Sin él, las compras en otra moneda no cuentan para la recompensa.';
  static String exchangeRateStatement(String from, String to, String rate) =>
      'Tu estado de cuenta indica 1 $from = $rate $to.';
  static const exchangeRateMissing =
      'Hay compras en moneda extranjera. Sin tipo de cambio quedarán fuera del cálculo.';
  static const exchangeRateInvalid =
      'Escribe un número mayor a 0 (máximo 6 decimales)';
  static const programChooserTitle = 'Elige el programa a auditar';
  static const programChooserHelper =
      'Tu estado de cuenta lista varios programas de recompensa.';
  static const programRequired = 'Elige un programa para continuar';
  static const calculateResult = 'Calcular resultado';
  static const calculating = 'Calculando…';
  static const confirmLoadError = 'No pudimos cargar esta verificación.';

  // Verdicts and result
  static const resultTitle = 'Resultado';
  static const resultNotConfirmed =
      'Esta verificación aún no tiene resultado. Confirma los porcentajes para calcularlo.';
  static const verdictMatch = 'Todo en orden';
  static const verdictUnderpaid = 'Te pagaron de menos';
  static const verdictOverpaid = 'Te pagaron de más';
  static const verdictMatchHint = 'La recompensa coincide con lo esperado.';
  static String verdictUnderpaidHint(String amount) =>
      'El banco te debe $amount. Puedes reclamarlo con tu estado de cuenta.';
  static String verdictOverpaidHint(String amount) =>
      'El banco te pagó $amount de más.';
  static const expectedLabel = 'Esperado';
  static const reportedLabel = 'Reportado';
  static const differenceLabel = 'Diferencia';
  static const reportedOverrideNote = 'Capturado por ti';
  static const breakdownTitle = 'Desglose por rubro';
  static const baseRateLine = 'Tasa base';
  static String breakdownDetail(String spend, int count) =>
      '$spend en $count movimiento(s)';
  static const capped = 'Tope alcanzado';
  static String capOf(String cap) => 'Tope $cap';
  static const transactionsTitle = 'Movimientos';
  static const filterAll = 'Todos';
  static const filterCounted = 'En rubro';
  static const filterUncounted = 'Sin rubro';
  static const filterExcluded = 'Excluidos';
  static String filterWithCount(String label, int n) => '$label ($n)';
  static String transactionsSummary(int counted, int uncounted, int excluded) =>
      '$counted en rubro · $uncounted sin rubro · $excluded excluidos';
  static const countedLabel = 'Contó en rubro';
  static const uncountedLabel = 'Sin rubro';
  static const excludedLabel = 'No genera recompensa';
  static const aiChip = 'IA';
  static const aiChipTooltip = 'Asignado por inteligencia artificial';
  static const userChip = 'Tú';
  static const userChipTooltip = 'Rubro corregido por ti';
  static String convertedAs(String amount) => '≈ $amount';
  static const excludedPayment = 'Pago a la tarjeta';
  static const excludedFee = 'Comisión o cargo';
  static const excludedInterest = 'Intereses';
  static const excludedInsurance = 'Seguro';
  static const excludedOther = 'Movimiento que no genera recompensa';
  static String excludedNoRate(String currency) =>
      'Compra en $currency sin tipo de cambio';
  static const changeCategory = 'Cambiar rubro';
  static const changeCategoryTitle = 'Cambiar el rubro de este movimiento';
  static const noCategoryOption = 'Sin rubro';
  static const categoryChanged = 'Rubro actualizado y resultado recalculado';
  static const recalcFailedAfterChange =
      'Cambiaste el rubro, pero no pudimos recalcular el resultado. Los montos mostrados siguen siendo los anteriores.';
  static const recalcNeedsRate =
      'Ese rubro necesita un porcentaje. Confírmalo para recalcular.';
  static const recalcAction = 'Recalcular';
  static const recalcWithOtherRates = 'Recalcular con otros %';
  static const explanationTitle = 'En pocas palabras';
  static const loyaltyTitle = 'Programas de recompensa';
  static const loyaltyAudited = 'Auditado';
  static const loyaltyCumulativeChip = 'Posible saldo acumulado';
  static const loyaltyProgram = 'Programa';
  static const loyaltyAccumulated = 'Acumulado';
  static const loyaltyAvailable = 'Disponible';
  static const loyaltyRedeemed = 'Canjeado';
  static const loyaltyExpiring = 'Por vencer';
  static const loyaltyForfeited = 'Perdido';
  static const currenciesTitle = 'Subtotales por moneda';
  static const currencySpent = 'Gasto neto';
  static const currencyEligible = 'Considerado';
  static const currencyReward = 'Recompensa (sin topes)';
  static String currencyRate(String from, String to, String rate) =>
      '1 $from = $rate $to';
  static String currencyExcluded(int n) =>
      n == 1 ? '1 movimiento excluido' : '$n movimientos excluidos';
  static const appliedRatesTitle = 'Porcentajes usados';
  static const warnLast4 =
      'Este estado de cuenta parece ser de otra tarjeta: los últimos 4 dígitos no coinciden.';
  static const warnCurrencyMismatch =
      'Ninguna moneda del estado de cuenta coincide con la moneda de tu tarjeta.';
  static const warnTotalMismatch =
      'Los movimientos leídos no suman el total del estado de cuenta. Puede que falten algunos y el resultado sea poco confiable.';
  static const warnNoTransactions =
      'No encontramos movimientos en el estado de cuenta.';
  static const warnAiUnavailable =
      'La clasificación con IA no estuvo disponible para algunos movimientos; solo se usaron tus comercios registrados.';
  static const warnNoExchangeRate =
      'Hay compras en moneda extranjera sin tipo de cambio: quedaron fuera del cálculo.';
  static const warnExchangeMultiple =
      'El tipo de cambio se aplicó a más de una moneda extranjera.';
  static const warnCumulative =
      'La cifra reportada parece un saldo acumulado y no lo ganado en este periodo. Revisa el programa.';
  static const warnUnitDiffers =
      'El programa reporta una unidad distinta a la de tu tarjeta; se usó la configuración de la tarjeta.';
  static const assignToCategory = 'Recordar comercio en un rubro';
  static const assignedNotice = 'Asignado para próximas verificaciones';
  static String assignedTo(String category) =>
      'Asignado a $category · aplicará en la próxima verificación';
  static String appliedRate(String rate) => 'Tasa $rate';
  static const baseOnly = 'Solo tasa base';
  static const refund = 'Reembolso';
  static const assignSheetTitle = 'Asignar comercio a un rubro';
  static const noCategoriesToAssign =
      'Crea un rubro primero para poder asignar este comercio.';
  static const goToCategories = 'Ir a rubros';
  static const merchantAssigned = 'Comercio asignado';
  static const warningsTitle = 'Avisos';
  static const noTransactionsMatch = 'No hay movimientos en esta vista.';
  static const periodLabel = 'Periodo';
  static const deleteVerification = 'Eliminar verificación';
  static const deleteVerificationBody =
      '¿Eliminar esta verificación del historial?';

  // History
  static const awaitingRatesChip = 'Pendiente de confirmar %';
  static const historyTitle = 'Historial';
  static const historyEmptyTitle = 'Sin verificaciones todavía';
  static const historyEmptyBody =
      'Cuando verifiques un estado de cuenta aparecerá aquí.';
  static const allCards = 'Todas';
  static const loadMore = 'Ver más';
  static const latestVerifications = 'Últimas verificaciones';
  static const seeAll = 'Ver todo';
  static const verifyAction = 'Verificar estado';
  static const historyAction = 'Historial';

  // Credits
  static String creditsAvailable(int n) =>
      n == 1 ? '1 verificación disponible' : '$n verificaciones disponibles';
  static const creditsNone = 'Sin verificaciones disponibles';
  static String uploadCreditNotice(int n) =>
      'Esta verificación usará 1 de tus $n disponibles.';
  static const uploadFreeNotice = 'Tu primera verificación es gratis.';
  static const uploadNoCredits =
      'No tienes verificaciones disponibles para analizar otro estado de cuenta.';
  static const seePlans = 'Ver planes';
  static const creditsTitle = 'Verificaciones';
  static const creditsHistoryTitle = 'Historial de verificaciones';
  static const creditsHistoryEmptyTitle = 'Sin movimientos todavía';
  static const creditsHistoryEmptyBody =
      'Aquí verás cuándo recibes, usas o te devolvemos verificaciones.';
  static const creditsBuy = 'Comprar verificaciones';
  static String creditsBreakdown(int free, int plan, int purchased) =>
      'Gratis $free · Plan $plan · Comprados $purchased';
  static String creditsPlanExpires(String date) =>
      'Las del plan vencen el $date';
  static const creditReasonGrantFree = 'Verificación gratis';
  static const creditReasonGrantPlan = 'Verificaciones de tu suscripción';
  static const creditReasonGrantPack = 'Paquete comprado';
  static const creditReasonConsume = 'Estado de cuenta analizado';
  static const creditReasonRefund = 'Verificación devuelta';
  static const creditReasonExpirePlan = 'Venció el saldo del plan';
  static const creditReasonOther = 'Ajuste';
  static const creditBucketFree = 'Gratis';
  static const creditBucketPlan = 'Plan';
  static const creditBucketPurchased = 'Comprada';

  // Paywall & subscription
  static const paywallTitle = 'Cashback Audit Pro';
  static const paywallHeadline = 'Más verificaciones, cuando las necesites';
  static const paywallBenefit1 =
      'Cada estado de cuenta que analizas usa 1 verificación';
  static const paywallBenefit2 =
      'Confirmar, recalcular y corregir movimientos no cuesta nada';
  static const paywallBenefit3 = 'Tu historial siempre queda disponible';
  static const paywallSubscriptionTitle = 'Suscripción mensual';
  static const paywallSubscriptionPerks =
      '5 verificaciones al mes · no se acumulan';
  static const paywallPacksTitle = 'Paquetes de verificaciones';
  static const paywallPacksSubtitle = 'Se compran una sola vez y no caducan.';
  static String packTitle(int n) =>
      n == 1 ? '1 verificación' : '$n verificaciones';
  static String paywallFreeBanner(int n) => n == 1
      ? 'Tienes 1 verificación gratis. Úsala antes de comprar nada.'
      : 'Tienes $n verificaciones gratis. Úsalas antes de comprar nada.';
  static const paywallBuy = 'Comprar';
  static const paywallSuccessPack = 'Tus verificaciones ya están disponibles.';
  static const paywallConfirmingPurchase = 'Confirmando tu compra…';
  static const paywallPendingPack =
      'Tu compra se está procesando. Las verificaciones pueden tardar unos segundos en aparecer.';
  static const restoreNothing =
      'No encontramos compras para restaurar en esta cuenta.';
  static const paywallSubscribe = 'Suscribirme';
  static const paywallRestore = 'Restaurar compras';
  static const paywallLegal =
      'La suscripción se renueva automáticamente. Puedes cancelarla en cualquier momento desde los ajustes de tu tienda de aplicaciones.';
  static const paywallNoPackages =
      'No hay planes disponibles por ahora. Inténtalo más tarde.';
  static const paywallLoadFailed =
      'No pudimos cargar los planes. Revisa tu conexión e inténtalo de nuevo.';
  static const paywallPurchaseFailed =
      'No se pudo completar la compra. No se te cobró nada.';
  static const paywallRestoreFailed =
      'No pudimos restaurar tus compras. Inténtalo de nuevo.';
  static const paywallConfirming = 'Confirmando tu compra…';
  static const paywallPending =
      'Tu compra se está procesando. Puede tardar unos segundos en reflejarse.';
  static const paywallCheckAgain = 'Verificar de nuevo';
  static const paywallSuccessTitle = '¡Listo!';
  static const paywallSuccessBody = 'Tu suscripción está activa.';
  static const paywallDevNoticeTitle = 'Compras no configuradas';
  static const paywallDevNotice =
      'Esta compilación no tiene clave de RevenueCat (REVENUECAT_IOS_KEY / REVENUECAT_ANDROID_KEY). Configúrala con --dart-define para probar las compras.';
  static const subscriptionTitle = 'Suscripción';
  static const subscribeNow = 'Ver planes';
  static const subscriptionNone = 'Sin suscripción activa';
  static const subscriptionActive = 'Pro activa';
  static const subscriptionCancelled = 'Cancelada';
  static const subscriptionBillingIssue = 'Problema de pago';
  static const subscriptionExpired = 'Vencida';
  static String subscriptionRenews(String date) => 'Se renueva el $date';
  static String subscriptionEnds(String date) => 'Activa hasta el $date';
  static const subscriptionBillingIssueHint =
      'Actualiza tu método de pago en la tienda para no perder el acceso.';
  static const restoreDone = 'Compras restauradas';
}
