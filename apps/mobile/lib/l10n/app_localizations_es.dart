// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Cashback Audit';

  @override
  String get tagline => 'Verifica que tu banco te pague lo que te corresponde.';

  @override
  String get retry => 'Reintentar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get skip => 'Omitir';

  @override
  String get devSignIn => 'Entrar como usuario de prueba (desarrollo)';

  @override
  String get back => 'Atrás';

  @override
  String get loading => 'Cargando…';

  @override
  String get offlineBanner => 'Sin conexión. Mostrando datos guardados.';

  @override
  String get errNetwork =>
      'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get errTimeout => 'La solicitud tardó demasiado. Inténtalo de nuevo.';

  @override
  String get errUnauthorized => 'Tu sesión expiró. Inicia sesión otra vez.';

  @override
  String get errNoCredits =>
      'No tienes verificaciones disponibles. Suscríbete o compra un paquete para continuar.';

  @override
  String get errRatesRequired =>
      'Escribe el porcentaje de los rubros marcados como obligatorios.';

  @override
  String get errProgramAmbiguous =>
      'Tu estado de cuenta tiene varios programas de recompensa. Elige cuál auditar.';

  @override
  String get errTransactionNotFound => 'No encontramos ese movimiento.';

  @override
  String get errTransactionNotClassifiable =>
      'Este movimiento no genera recompensa, así que no se puede asignar a un rubro.';

  @override
  String get errVerificationNotFound =>
      'Esta verificación ya no existe. Las que no se confirman en 7 días se eliminan.';

  @override
  String get errValidation => 'Revisa los datos e inténtalo de nuevo.';

  @override
  String get errNotFound => 'No encontramos lo que buscabas.';

  @override
  String get errConflict =>
      'Esa acción entra en conflicto con datos existentes.';

  @override
  String get errTooLarge => 'El archivo supera el límite de 10 MB.';

  @override
  String get errNotPdf => 'Solo se aceptan archivos PDF.';

  @override
  String get errRateLimited =>
      'Demasiados intentos. Espera un momento e inténtalo otra vez.';

  @override
  String get errServer =>
      'Algo salió mal de nuestro lado. Inténtalo de nuevo en unos minutos.';

  @override
  String get errUnknown => 'Ocurrió un error inesperado.';

  @override
  String get errCategoryNameTaken => 'Ya tienes un rubro con ese nombre.';

  @override
  String get errMerchantNameTaken => 'Ya tienes un comercio con ese nombre.';

  @override
  String get errCategoryInUse =>
      'Este rubro tiene comercios o reglas de tarjeta. Elige a qué rubro moverlos.';

  @override
  String get errInvalidPdf => 'El archivo no es un PDF válido.';

  @override
  String get errUnreadable =>
      'No pudimos leer ese estado de cuenta. Descarga el PDF original desde tu banco (no una foto ni un archivo con contraseña).';

  @override
  String get errRewardRateRequired =>
      'Escribe cuánto vale la moneda de la recompensa para poder convertirla.';

  @override
  String get errInvalidExchangeRate =>
      'Revisa los tipos de cambio: deben ser números mayores a 0 (máximo 6 decimales).';

  @override
  String get errRewardNotFound =>
      'El estado de cuenta no muestra la recompensa que te dio el banco. Escríbela para continuar.';

  @override
  String get errExtractionFailed =>
      'El análisis no devolvió un resultado utilizable. Suele funcionar al reintentar.';

  @override
  String get errExtractionUnavailable =>
      'El servicio de análisis está ocupado. Inténtalo más tarde.';

  @override
  String get errIdentityToken =>
      'No pudimos validar tu cuenta. Inténtalo de nuevo.';

  @override
  String get errIdentityUnavailable =>
      'El inicio de sesión no está disponible por ahora.';

  @override
  String get errSignInFailed =>
      'No pudimos completar el inicio de sesión. Inténtalo de nuevo.';

  @override
  String get sessionExpiredTitle => 'Sesión finalizada';

  @override
  String get onb1Title => 'Comprueba lo que tu banco te debe';

  @override
  String get onb1Body =>
      'Sube tu estado de cuenta y calculamos cuánto cashback o cuántos puntos deberías haber recibido.';

  @override
  String get onb2Title => 'Registra tus tarjetas y rubros';

  @override
  String get onb2Body =>
      'Captura la tasa base de cada tarjeta y los porcentajes por rubro (súper, gasolina, restaurantes…). Asigna cada comercio al rubro en el que esperas que acumule.';

  @override
  String get onb3Title => 'Sube el PDF y revisa el veredicto';

  @override
  String get onb3Body =>
      'Te mostramos si el pago coincide, si te pagaron de menos o de más, con el detalle por rubro y por movimiento.';

  @override
  String get onb4Title => 'Tu privacidad primero';

  @override
  String get onb4Body =>
      'Nunca guardamos tu PDF ni el número completo de tu tarjeta: solo los últimos 4 dígitos y los resultados del análisis.';

  @override
  String get start => 'Empezar';

  @override
  String get loginTitle => 'Inicia sesión';

  @override
  String get loginSubtitle =>
      'Usa tu cuenta para guardar tus tarjetas, rubros y el historial de verificaciones.';

  @override
  String get signInGoogle => 'Continuar con Google';

  @override
  String get signInApple => 'Continuar con Apple';

  @override
  String get loginLegal =>
      'No almacenamos tu PDF ni el número completo de tu tarjeta.';

  @override
  String get fieldRequired => 'Este campo es obligatorio';

  @override
  String get last4Invalid => 'Escribe exactamente 4 dígitos';

  @override
  String get currencyInvalid => 'Usa un código de 3 letras (MXN, USD…)';

  @override
  String get numberInvalid => 'Escribe un número válido';

  @override
  String get percentRange => 'Debe estar entre 0 y 100';

  @override
  String get capInvalid => 'Debe ser mayor a 0 (máximo 2 decimales)';

  @override
  String get pointsFactorInvalid => 'Debe ser mayor a 0 y hasta 1000';

  @override
  String get homeCards => 'Mis tarjetas';

  @override
  String get homeNoCardsTitle => 'Aún no tienes tarjetas';

  @override
  String get homeNoCardsBody =>
      'Agrega tu primera tarjeta con sus tasas de recompensa para empezar a auditar.';

  @override
  String get addCard => 'Agregar tarjeta';

  @override
  String get manageCategories => 'Rubros y comercios';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get loadError => 'No pudimos cargar tus datos.';

  @override
  String get newCard => 'Nueva tarjeta';

  @override
  String get editCard => 'Editar tarjeta';

  @override
  String get cardAlias => 'Alias';

  @override
  String get cardAliasHint => 'Ej. Tarjeta diaria';

  @override
  String get cardBank => 'Banco';

  @override
  String get cardLast4 => 'Últimos 4 dígitos';

  @override
  String get cardLast4Helper => 'Nunca pedimos el número completo.';

  @override
  String get cardNetwork => 'Red (opcional)';

  @override
  String get cardCurrency => 'Moneda';

  @override
  String get cardRewardProgram => 'Programa de recompensa a auditar';

  @override
  String get cardRewardProgramHelper =>
      'Opcional. Si tu estado de cuenta lista varios programas (p. ej. CASH BAC), escribe el nombre del que quieres auditar.';

  @override
  String get cardRewardCurrency => 'Moneda en que recibes la recompensa';

  @override
  String get cardRewardCurrencyHelper =>
      'Opcional. Si tu banco paga la recompensa en otra moneda que tus compras (p. ej. dólares), indícala. Vacío = detectar automáticamente.';

  @override
  String get cardRewardCurrencyAuto => 'Detectar automáticamente';

  @override
  String get rewardUnitLabel => 'Tipo de recompensa';

  @override
  String get unitCashback => 'Cashback';

  @override
  String get unitPoints => 'Puntos';

  @override
  String get pointsPerUnit => 'Puntos por cada \$1 de recompensa';

  @override
  String get baseRate => 'Tasa base (%)';

  @override
  String get baseRateHelper => 'Se aplica a todo gasto sin regla por rubro.';

  @override
  String get rulesTitle => 'Reglas por rubro';

  @override
  String get rulesHelper =>
      'Define una tasa distinta para cada rubro, con tope mensual opcional.';

  @override
  String get addRule => 'Agregar regla';

  @override
  String get ruleCategory => 'Rubro';

  @override
  String get ruleRate => 'Tasa (%)';

  @override
  String get ruleCap => 'Tope mensual';

  @override
  String get ruleCapHelper => 'Opcional';

  @override
  String get removeRule => 'Quitar regla';

  @override
  String get ruleNeedsCategories =>
      'Primero crea al menos un rubro para definir reglas.';

  @override
  String get ruleCategoryRequired => 'Elige un rubro';

  @override
  String get ruleDuplicateCategory => 'Ya hay una regla para ese rubro';

  @override
  String get deleteCardTitle => 'Eliminar tarjeta';

  @override
  String get cardSaved => 'Tarjeta guardada';

  @override
  String get cardDeleted => 'Tarjeta eliminada';

  @override
  String get catalogTitle => 'Rubros y comercios';

  @override
  String get addCategory => 'Nuevo rubro';

  @override
  String get editCategory => 'Editar rubro';

  @override
  String get categoryName => 'Nombre del rubro';

  @override
  String get categoryDescription => 'Descripción (opcional)';

  @override
  String get addMerchant => 'Agregar comercio';

  @override
  String get editMerchant => 'Editar comercio';

  @override
  String get merchantName => 'Nombre del comercio';

  @override
  String get merchantKeywords => 'Palabras clave del estado de cuenta';

  @override
  String get merchantKeywordsHelper =>
      'Como aparecen en tu estado de cuenta, separadas por coma. Ej. WAL MART, WALMART SUC';

  @override
  String get merchantCategory => 'Rubro esperado';

  @override
  String get noMerchants => 'Sin comercios';

  @override
  String get catalogEmptyTitle => 'Crea tu primer rubro';

  @override
  String get catalogEmptyBody =>
      'Los rubros (súper, gasolina, restaurantes…) agrupan comercios y reciben tasas especiales en tus tarjetas.';

  @override
  String get deleteCategoryTitle => 'Eliminar rubro';

  @override
  String get reassignTo => 'Mover a';

  @override
  String get reassignAndDelete => 'Mover y eliminar';

  @override
  String get deleteMerchantTitle => 'Eliminar comercio';

  @override
  String get needOtherCategory =>
      'Crea otro rubro para poder mover los elementos.';

  @override
  String get settingsTitle => 'Perfil y ajustes';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get longPressHint => 'Mantén presionada una tarjeta para eliminarla';

  @override
  String get uploadTitle => 'Verificar estado de cuenta';

  @override
  String get uploadStep1 => 'Elige la tarjeta';

  @override
  String get uploadStep2 => 'Selecciona el PDF';

  @override
  String get pickPdf => 'Elegir PDF';

  @override
  String get changePdf => 'Cambiar archivo';

  @override
  String get noCardsForUpload =>
      'Primero agrega una tarjeta para poder verificar un estado de cuenta.';

  @override
  String get verify => 'Verificar';

  @override
  String get uploading => 'Subiendo archivo…';

  @override
  String get analyzing => 'Analizando tu estado de cuenta…';

  @override
  String get analyzingHint =>
      'Puede tardar hasta un minuto. No cierres la app.';

  @override
  String get uploadPrivacy => 'Procesamos el PDF en memoria y no lo guardamos.';

  @override
  String get fileTooLarge => 'El archivo supera el límite de 10 MB.';

  @override
  String get fileNotPdf => 'Elige un archivo PDF.';

  @override
  String get uploadTimeout =>
      'El análisis tardó demasiado. Revisa tu historial antes de reintentar: puede que ya se haya procesado.';

  @override
  String get overrideTitle => 'Escribe la recompensa que te dio el banco';

  @override
  String get overrideLabel => 'Recompensa reportada';

  @override
  String get overrideHelper =>
      'Búscala en tu estado de cuenta (bonificación o puntos del periodo).';

  @override
  String get overrideInvalid => 'Escribe un monto válido (hasta 2 decimales)';

  @override
  String get selectCardFirst => 'Elige una tarjeta';

  @override
  String get analyzingStepUpload => 'Archivo recibido';

  @override
  String get analyzingStepRead => 'Leyendo tu estado de cuenta';

  @override
  String get analyzingStepClassify => 'Clasificando movimientos';

  @override
  String get analyzingExpect =>
      'Este paso suele tardar cerca de 1 minuto. Después podrás confirmar los porcentajes.';

  @override
  String get confirmRatesTitle => 'Confirma los porcentajes';

  @override
  String get recalcRatesTitle => 'Recalcular con otros %';

  @override
  String get confirmRatesIntro =>
      'Los bancos cambian sus reglas. Revisa antes de calcular; cambiarlos después es gratis.';

  @override
  String get confirmRatesNoCharge =>
      'Calcular y recalcular no consume verificaciones.';

  @override
  String get rateBaseTitle => 'Todo lo demás · tasa base';

  @override
  String get rateBaseSubtitle => 'Compras fuera de tus rubros';

  @override
  String get rateFieldLabel => 'Porcentaje';

  @override
  String get rateCapLabel => 'Tope mensual (opcional)';

  @override
  String get badgeStatement => 'Detectado en tu estado de cuenta';

  @override
  String get badgeCardRule => 'De las reglas de tu tarjeta';

  @override
  String get badgePrevious => 'Los que usaste antes';

  @override
  String get badgeRequired => 'Obligatorio';

  @override
  String get rateRequiredError => 'Escribe el porcentaje para continuar';

  @override
  String get saveToCardTitle => 'Guardar estos % en la tarjeta';

  @override
  String get saveToCardSubtitle => 'Se usarán en la próxima verificación';

  @override
  String get exchangeRateTitle => 'Tipo de cambio (opcional)';

  @override
  String get exchangeRateMissing =>
      'Hay compras en moneda extranjera. Sin tipo de cambio quedarán fuera del cálculo.';

  @override
  String get exchangeRateInvalid =>
      'Escribe un número mayor a 0 (máximo 6 decimales)';

  @override
  String get rewardRateRequiredError =>
      'Escribe el tipo de cambio para continuar';

  @override
  String get foreignRatesTitle => 'Compras en otras monedas';

  @override
  String get foreignRatesHelper =>
      'Opcional. Si dejas un tipo de cambio vacío, las compras en esa moneda quedan fuera del cálculo.';

  @override
  String get foreignRateOptional => 'Opcional';

  @override
  String get suggestionsTitle =>
      'Tu estado de cuenta menciona rubros que no tienes';

  @override
  String get suggestionsHelper =>
      'Créalos para auditar esas compras con el porcentaje que indica tu banco.';

  @override
  String get suggestionsFree => 'Es gratis: no consume verificaciones.';

  @override
  String get createSuggestions => 'Crear rubros seleccionados';

  @override
  String get creatingSuggestions => 'Creando rubros…';

  @override
  String get suggestionsCreated =>
      'Rubros creados. Ya aparecen abajo con el porcentaje de tu estado de cuenta.';

  @override
  String get programChooserTitle => 'Elige el programa a auditar';

  @override
  String get programChooserHelper =>
      'Tu estado de cuenta lista varios programas de recompensa.';

  @override
  String get programRequired => 'Elige un programa para continuar';

  @override
  String get calculateResult => 'Calcular resultado';

  @override
  String get calculating => 'Calculando…';

  @override
  String get confirmLoadError => 'No pudimos cargar esta verificación.';

  @override
  String get resultTitle => 'Resultado';

  @override
  String get resultNotConfirmed =>
      'Esta verificación aún no tiene resultado. Confirma los porcentajes para calcularlo.';

  @override
  String get verdictMatch => 'Todo en orden';

  @override
  String get verdictUnderpaid => 'Te pagaron de menos';

  @override
  String get verdictOverpaid => 'Te pagaron de más';

  @override
  String get verdictMatchHint => 'La recompensa coincide con lo esperado.';

  @override
  String get expectedLabel => 'Esperado';

  @override
  String get reportedLabel => 'Reportado';

  @override
  String get differenceLabel => 'Diferencia';

  @override
  String get reportedOverrideNote => 'Capturado por ti';

  @override
  String get breakdownTitle => 'Desglose por rubro';

  @override
  String get baseRateLine => 'Tasa base';

  @override
  String get capped => 'Tope alcanzado';

  @override
  String get transactionsTitle => 'Movimientos';

  @override
  String get filterAll => 'Todos';

  @override
  String get filterCounted => 'En rubro';

  @override
  String get filterUncounted => 'Sin rubro';

  @override
  String get filterExcluded => 'Excluidos';

  @override
  String get countedLabel => 'Contó en rubro';

  @override
  String get uncountedLabel => 'Sin rubro';

  @override
  String get excludedLabel => 'No genera recompensa';

  @override
  String get aiChip => 'IA';

  @override
  String get aiChipTooltip => 'Asignado por inteligencia artificial';

  @override
  String get userChip => 'Tú';

  @override
  String get userChipTooltip => 'Rubro corregido por ti';

  @override
  String get excludedPayment => 'Los pagos no generan recompensa';

  @override
  String get excludedFee => 'Comisión o cargo';

  @override
  String get excludedInterest => 'Intereses';

  @override
  String get excludedInsurance => 'Seguro';

  @override
  String get excludedOther => 'Movimiento que no genera recompensa';

  @override
  String get changeCategory => 'Cambiar rubro';

  @override
  String get changeCategoryTitle => 'Cambiar el rubro de este movimiento';

  @override
  String get noCategoryOption => 'Sin rubro';

  @override
  String get categoryChanged => 'Rubro actualizado y resultado recalculado';

  @override
  String get recalcFailedAfterChange =>
      'Cambiaste el rubro, pero no pudimos recalcular el resultado. Los montos mostrados siguen siendo los anteriores.';

  @override
  String get recalcNeedsRate =>
      'Ese rubro necesita un porcentaje. Confírmalo para recalcular.';

  @override
  String get recalcAction => 'Recalcular';

  @override
  String get recalcWithOtherRates => 'Recalcular con otros %';

  @override
  String get explanationTitle => 'En pocas palabras';

  @override
  String get loyaltyTitle => 'Programas de recompensa';

  @override
  String get loyaltyAudited => 'Auditado';

  @override
  String get loyaltyCumulativeChip => 'Posible saldo acumulado';

  @override
  String get loyaltyProgram => 'Programa';

  @override
  String get loyaltyAccumulated => 'Acumulado';

  @override
  String get loyaltyAvailable => 'Disponible';

  @override
  String get loyaltyRedeemed => 'Canjeado';

  @override
  String get loyaltyExpiring => 'Por vencer';

  @override
  String get loyaltyForfeited => 'Perdido';

  @override
  String get currenciesTitle => 'Subtotales por moneda';

  @override
  String get currencySpent => 'Gasto neto';

  @override
  String get currencyEligible => 'Considerado';

  @override
  String get currencyReward => 'Recompensa (sin topes)';

  @override
  String get appliedRatesTitle => 'Porcentajes usados';

  @override
  String get warnLast4 =>
      'Este estado de cuenta parece ser de otra tarjeta: los últimos 4 dígitos no coinciden.';

  @override
  String get warnCurrencyMismatch =>
      'Ninguna moneda del estado de cuenta coincide con la moneda de tu tarjeta.';

  @override
  String get warnTotalMismatch =>
      'Los movimientos leídos no suman el total del estado de cuenta. Puede que falten algunos y el resultado sea poco confiable.';

  @override
  String get warnNoTransactions =>
      'No encontramos movimientos en el estado de cuenta.';

  @override
  String get warnAiUnavailable =>
      'La clasificación con IA no estuvo disponible para algunos movimientos; solo se usaron tus comercios registrados.';

  @override
  String get warnNoExchangeRate =>
      'Hay compras en moneda extranjera sin tipo de cambio: quedaron fuera del cálculo.';

  @override
  String get warnExchangeMultiple =>
      'El tipo de cambio se aplicó a más de una moneda extranjera.';

  @override
  String get warnCumulative =>
      'La cifra reportada parece un saldo acumulado y no lo ganado en este periodo. Revisa el programa.';

  @override
  String get warnUnitDiffers =>
      'El programa reporta una unidad distinta a la de tu tarjeta; se usó la configuración de la tarjeta.';

  @override
  String get assignToCategory => 'Recordar comercio en un rubro';

  @override
  String get assignedNotice => 'Asignado para próximas verificaciones';

  @override
  String get baseOnly => 'Solo tasa base';

  @override
  String get creditPayment => 'Pago a la tarjeta';

  @override
  String get creditRefund => 'Devolución';

  @override
  String get creditOther => 'Otro crédito / bonificación';

  @override
  String get rewardRateDetailTitle => 'Conversión de la recompensa';

  @override
  String get rewardRateFromStatement => 'Tomado de tu estado de cuenta';

  @override
  String get rewardRateUserEntered => 'Lo escribiste tú';

  @override
  String get assignSheetTitle => 'Asignar comercio a un rubro';

  @override
  String get noCategoriesToAssign =>
      'Crea un rubro primero para poder asignar este comercio.';

  @override
  String get goToCategories => 'Ir a rubros';

  @override
  String get merchantAssigned => 'Comercio asignado';

  @override
  String get warningsTitle => 'Avisos';

  @override
  String get noTransactionsMatch => 'No hay movimientos en esta vista.';

  @override
  String get periodLabel => 'Periodo';

  @override
  String get deleteVerification => 'Eliminar verificación';

  @override
  String get deleteVerificationBody =>
      '¿Eliminar esta verificación del historial?';

  @override
  String get awaitingRatesChip => 'Pendiente de confirmar %';

  @override
  String get historyTitle => 'Historial';

  @override
  String get historyEmptyTitle => 'Sin verificaciones todavía';

  @override
  String get historyEmptyBody =>
      'Cuando verifiques un estado de cuenta aparecerá aquí.';

  @override
  String get allCards => 'Todas';

  @override
  String get loadMore => 'Ver más';

  @override
  String get latestVerifications => 'Últimas verificaciones';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get verifyAction => 'Verificar estado';

  @override
  String get historyAction => 'Historial';

  @override
  String get creditsNone => 'Sin verificaciones disponibles';

  @override
  String get uploadFreeNotice => 'Tu primera verificación es gratis.';

  @override
  String get uploadNoCredits =>
      'No tienes verificaciones disponibles para analizar otro estado de cuenta.';

  @override
  String get seePlans => 'Ver planes';

  @override
  String get creditsTitle => 'Verificaciones';

  @override
  String get creditsHistoryTitle => 'Historial de verificaciones';

  @override
  String get creditsHistoryEmptyTitle => 'Sin movimientos todavía';

  @override
  String get creditsHistoryEmptyBody =>
      'Aquí verás cuándo recibes, usas o te devolvemos verificaciones.';

  @override
  String get creditsBuy => 'Comprar verificaciones';

  @override
  String get creditReasonGrantFree => 'Verificación gratis';

  @override
  String get creditReasonGrantPlan => 'Verificaciones de tu suscripción';

  @override
  String get creditReasonGrantPack => 'Paquete comprado';

  @override
  String get creditReasonConsume => 'Estado de cuenta analizado';

  @override
  String get creditReasonRefund => 'Verificación devuelta';

  @override
  String get creditReasonExpirePlan => 'Venció el saldo del plan';

  @override
  String get creditReasonOther => 'Ajuste';

  @override
  String get creditBucketFree => 'Gratis';

  @override
  String get creditBucketPlan => 'Plan';

  @override
  String get creditBucketPurchased => 'Comprada';

  @override
  String get paywallTitle => 'Cashback Audit Pro';

  @override
  String get paywallHeadline => 'Más verificaciones, cuando las necesites';

  @override
  String get paywallBenefit1 =>
      'Cada estado de cuenta que analizas usa 1 verificación';

  @override
  String get paywallBenefit2 =>
      'Confirmar, recalcular y corregir movimientos no cuesta nada';

  @override
  String get paywallBenefit3 => 'Tu historial siempre queda disponible';

  @override
  String get paywallSubscriptionTitle => 'Suscripción mensual';

  @override
  String get paywallSubscriptionPerks =>
      '5 verificaciones al mes · no se acumulan';

  @override
  String get paywallPacksTitle => 'Paquetes de verificaciones';

  @override
  String get paywallPacksSubtitle => 'Se compran una sola vez y no caducan.';

  @override
  String get paywallBuy => 'Comprar';

  @override
  String get paywallSuccessPack => 'Tus verificaciones ya están disponibles.';

  @override
  String get paywallConfirmingPurchase => 'Confirmando tu compra…';

  @override
  String get paywallPendingPack =>
      'Tu compra se está procesando. Las verificaciones pueden tardar unos segundos en aparecer.';

  @override
  String get restoreNothing =>
      'No encontramos compras para restaurar en esta cuenta.';

  @override
  String get paywallSubscribe => 'Suscribirme';

  @override
  String get paywallRestore => 'Restaurar compras';

  @override
  String get paywallLegal =>
      'La suscripción se renueva automáticamente. Puedes cancelarla en cualquier momento desde los ajustes de tu tienda de aplicaciones.';

  @override
  String get paywallNoPackages =>
      'No hay planes disponibles por ahora. Inténtalo más tarde.';

  @override
  String get paywallLoadFailed =>
      'No pudimos cargar los planes. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get paywallPurchaseFailed =>
      'No se pudo completar la compra. No se te cobró nada.';

  @override
  String get paywallRestoreFailed =>
      'No pudimos restaurar tus compras. Inténtalo de nuevo.';

  @override
  String get paywallConfirming => 'Confirmando tu compra…';

  @override
  String get paywallPending =>
      'Tu compra se está procesando. Puede tardar unos segundos en reflejarse.';

  @override
  String get paywallCheckAgain => 'Verificar de nuevo';

  @override
  String get paywallSuccessTitle => '¡Listo!';

  @override
  String get paywallSuccessBody => 'Tu suscripción está activa.';

  @override
  String get paywallDevNoticeTitle => 'Compras no configuradas';

  @override
  String get paywallDevNotice =>
      'Esta compilación no tiene clave de RevenueCat (REVENUECAT_IOS_KEY / REVENUECAT_ANDROID_KEY). Configúrala con --dart-define para probar las compras.';

  @override
  String get subscriptionTitle => 'Suscripción';

  @override
  String get subscribeNow => 'Ver planes';

  @override
  String get subscriptionNone => 'Sin suscripción activa';

  @override
  String get subscriptionActive => 'Pro activa';

  @override
  String get subscriptionCancelled => 'Cancelada';

  @override
  String get subscriptionBillingIssue => 'Problema de pago';

  @override
  String get subscriptionExpired => 'Vencida';

  @override
  String get subscriptionBillingIssueHint =>
      'Actualiza tu método de pago en la tienda para no perder el acceso.';

  @override
  String get restoreDone => 'Compras restauradas';

  @override
  String fieldTooLong(int max) {
    return 'Máximo $max caracteres';
  }

  @override
  String greeting(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Hola',
      'other': 'Hola, $name',
    });
    return '$_temp0';
  }

  @override
  String deleteCardBody(String alias) {
    return '¿Eliminar \"$alias\"? También se borrará su historial de verificaciones.';
  }

  @override
  String ruleCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n reglas',
      one: '1 regla',
      zero: 'Sin reglas',
    );
    return '$_temp0';
  }

  @override
  String ruleCountPlain(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n reglas',
      one: '1 regla',
    );
    return '$_temp0';
  }

  @override
  String baseRateShort(String rate) {
    return 'Base $rate';
  }

  @override
  String deleteCategoryBody(String name) {
    return '¿Eliminar el rubro \"$name\"?';
  }

  @override
  String reassignBody(String merchants, String rules) {
    return 'Este rubro tiene $merchants y $rules de tarjeta. Elige a qué rubro moverlos antes de eliminarlo.';
  }

  @override
  String deleteMerchantBody(String name) {
    return '¿Eliminar \"$name\"? Dejará de asignarse a su rubro.';
  }

  @override
  String merchantCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n comercios',
      one: '1 comercio',
    );
    return '$_temp0';
  }

  @override
  String evidenceQuote(String text) {
    return '“$text”';
  }

  @override
  String exchangeRateHelper(String primary) {
    return 'Cuántos $primary vale 1 unidad de la moneda extranjera. Sin él, las compras en otra moneda no cuentan para la recompensa.';
  }

  @override
  String exchangeRateStatement(String from, String to, String rate) {
    return 'Tu estado de cuenta indica 1 $from = $rate $to.';
  }

  @override
  String howManyIs(String primary, String foreign) {
    return '¿Cuántos $primary vale 1 $foreign?';
  }

  @override
  String rewardConversionTitle(String reward, String primary) {
    return 'Tu banco paga la recompensa en $reward y tus compras están en $primary';
  }

  @override
  String rewardConversionHelper(String reward) {
    return 'Necesitamos este tipo de cambio para convertir lo que deberías haber recibido a $reward. Es obligatorio.';
  }

  @override
  String foreignRateEmptyNote(String currency) {
    return 'Sin tipo de cambio, las compras en $currency no cuentan.';
  }

  @override
  String suggestionLines(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n movimientos',
      one: '1 movimiento',
      zero: 'Sin movimientos',
    );
    return '$_temp0';
  }

  @override
  String verdictUnderpaidHint(String amount) {
    return 'El banco te debe $amount. Puedes reclamarlo con tu estado de cuenta.';
  }

  @override
  String verdictOverpaidHint(String amount) {
    return 'El banco te pagó $amount de más.';
  }

  @override
  String breakdownDetail(String spend, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos',
      one: '1 movimiento',
    );
    return '$spend en $_temp0';
  }

  @override
  String capOf(String cap) {
    return 'Tope $cap';
  }

  @override
  String filterWithCount(String label, int n) {
    return '$label ($n)';
  }

  @override
  String transactionsSummary(int counted, int uncounted, int excluded) {
    return '$counted en rubro · $uncounted sin rubro · $excluded excluidos';
  }

  @override
  String convertedAs(String amount) {
    return '≈ $amount';
  }

  @override
  String excludedNoRate(String currency) {
    return 'Compra en $currency sin tipo de cambio';
  }

  @override
  String currencyRate(String from, String to, String rate) {
    return '1 $from = $rate $to';
  }

  @override
  String currencyExcluded(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n movimientos excluidos',
      one: '1 movimiento excluido',
    );
    return '$_temp0';
  }

  @override
  String assignedTo(String category) {
    return 'Asignado a $category · aplicará en la próxima verificación';
  }

  @override
  String appliedRate(String rate) {
    return 'Tasa $rate';
  }

  @override
  String bankConsiders(String hint) {
    return 'Tu banco lo considera: $hint';
  }

  @override
  String equivalentTo(String money) {
    return 'Equivale a $money';
  }

  @override
  String rewardRateDetail(String reward, String rate, String primary) {
    return '1 $reward = $rate $primary';
  }

  @override
  String creditsAvailable(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n verificaciones disponibles',
      one: '1 verificación disponible',
    );
    return '$_temp0';
  }

  @override
  String uploadCreditNotice(int n) {
    return 'Esta verificación usará 1 de tus $n disponibles.';
  }

  @override
  String creditsBreakdown(int free, int plan, int purchased) {
    return 'Gratis $free · Plan $plan · Comprados $purchased';
  }

  @override
  String creditsPlanExpires(String date) {
    return 'Las del plan vencen el $date';
  }

  @override
  String packTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n verificaciones',
      one: '1 verificación',
    );
    return '$_temp0';
  }

  @override
  String paywallFreeBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Tienes $n verificaciones gratis. Úsalas antes de comprar nada.',
      one: 'Tienes 1 verificación gratis. Úsala antes de comprar nada.',
    );
    return '$_temp0';
  }

  @override
  String subscriptionRenews(String date) {
    return 'Se renueva el $date';
  }

  @override
  String subscriptionEnds(String date) {
    return 'Activa hasta el $date';
  }

  @override
  String stepOf(int step, int total) {
    return 'Paso $step de $total';
  }

  @override
  String get assignCategory => 'Asignar rubro';

  @override
  String get showDetails => 'Ver detalle';

  @override
  String get hideDetails => 'Ocultar detalle';

  @override
  String get splashTagline => 'Lo que tu banco te debe';

  @override
  String get languageAutomatic => 'Automático';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String onbLangAria(String language) {
    return 'Idioma: $language. Cambiar';
  }

  @override
  String get onbHaveAccount => 'Ya tengo cuenta';

  @override
  String get onbDemoTitle => '¿Tu banco te pagó todo tu cashback?';

  @override
  String get onbDemoStatementSays => 'Tu estado de cuenta dice';

  @override
  String get onbDemoPharmacy => 'Farmacia Kielsa · 7%';

  @override
  String get onbDemoPayment => 'Pago recibido · no cuenta';

  @override
  String get onbDemoOwed => 'Te debían';

  @override
  String get onbDemoSub =>
      'Subes el PDF, la IA lee cada compra y te decimos si te pagaron bien, de menos o de más. Vamos a configurar tu tarjeta mientras lo pruebas.';

  @override
  String get onbDemoCta => 'Hacer mi verificación gratis';

  @override
  String get onbDemoFoot => 'Unos 3 minutos · no pedimos datos de pago';

  @override
  String get onbStepBank => 'Tu banco';

  @override
  String get onbStepCard => 'Tu tarjeta';

  @override
  String get onbStepCategories => 'Tus rubros';

  @override
  String get onbStepAccount => 'Tu cuenta';

  @override
  String get onbStepFreeCheck => 'Verificación gratis';

  @override
  String onbStepLabel(int step, int total, String name) {
    return 'Paso $step de $total · $name';
  }

  @override
  String get onbBankTitle => '¿De qué banco es tu tarjeta?';

  @override
  String get onbBankSub =>
      'Funciona con cualquier banco y país. Lo usamos para reconocer tu estado de cuenta.';

  @override
  String get onbBankSearch => 'Buscar tu banco';

  @override
  String get onbBankTested => 'Probado';

  @override
  String get onbBankOther => 'Otro banco';

  @override
  String get onbBankOtherName => 'Nombre de tu banco';

  @override
  String onbCardTitle(String bank) {
    return 'Tu tarjeta $bank';
  }

  @override
  String get onbCardName => 'Nombre';

  @override
  String get onbCardLast4 => 'Últimos 4';

  @override
  String get onbCardLast4Note => 'Solo guardamos estos 4 dígitos.';

  @override
  String get onbRewardKind => '¿Qué te da la tarjeta?';

  @override
  String get onbRewardCashback => 'Cashback';

  @override
  String get onbRewardPoints => 'Puntos o millas';

  @override
  String get onbRewardCurrency => '¿En qué moneda te lo pagan?';

  @override
  String get onbCurrencyDetect => 'No sé, que lo detecte';

  @override
  String get onbRewardLabelCashback => 'CASHBACK';

  @override
  String get onbRewardLabelPoints => 'PUNTOS';

  @override
  String get onbCatsTitle => '¿En qué compras te da más?';

  @override
  String get onbCatsSub =>
      'Marca los rubros de tu tarjeta y su porcentaje. Si no lo sabes, déjalo vacío: lo buscamos en tu estado de cuenta.';

  @override
  String get onbCatSupermarkets => 'Supermercados';

  @override
  String get onbCatPharmacy => 'Farmacia';

  @override
  String get onbCatRestaurants => 'Restaurantes y comida rápida';

  @override
  String get onbCatGas => 'Gasolineras';

  @override
  String get onbCatDepartment => 'Tiendas por departamento';

  @override
  String get onbCatOther => 'Otro rubro';

  @override
  String get onbCatOtherName => 'Nombre del rubro';

  @override
  String get onbCatAdd => 'Agregar';

  @override
  String get onbBaseTitle => 'Todo lo demás';

  @override
  String get onbBaseSub =>
      'Lo que gana una compra fuera de estos rubros (tasa base)';

  @override
  String get onbAccountTitle => 'Guarda lo que configuraste';

  @override
  String get onbAccountSub =>
      'Crea tu cuenta para no perder tu tarjeta y usar tu verificación gratis.';

  @override
  String onbAccountCardSub(String bank, String unit, String currency) {
    return '$bank · $unit en $currency';
  }

  @override
  String get onbAccountCurrencyDetected => 'moneda por detectar';

  @override
  String get onbAccountPrivacy =>
      'Tu PDF se lee en memoria y nunca se guarda. De tu tarjeta solo guardamos los últimos 4 dígitos.';

  @override
  String get onbSyncFailed =>
      'Creaste tu cuenta, pero no pudimos guardar tu configuración. Revisa tu conexión y reintenta.';

  @override
  String get onbSyncing => 'Guardando tu configuración…';

  @override
  String get onbFreeCheckPill => '1 verificación gratis';

  @override
  String onbHello(String name) {
    return 'Hola, $name';
  }

  @override
  String get onbPdfTitle => 'Sube tu primer estado de cuenta';

  @override
  String get onbPdfSub =>
      'Elige el PDF que te dio tu banco. Lo leemos en memoria y no lo guardamos.';

  @override
  String get onbPdfPick => 'Elegir PDF';

  @override
  String get onbPdfChange => 'Cambiar PDF';

  @override
  String onbPdfForCard(String card) {
    return 'Para $card';
  }

  @override
  String get onbPdfStart => 'Analizar con mi verificación gratis';

  @override
  String get onbPdfLater => 'Ahora no, ir a mi inicio';

  @override
  String get onbPdfReadingTitle => 'Leyendo tu estado de cuenta';

  @override
  String get onbFirstVerification => 'Tu primera verificación';

  @override
  String onbSavedSummary(String card, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rubros',
      one: '1 rubro',
      zero: 'sin rubros',
    );
    return 'Quedó guardado: tu tarjeta $card, $_temp0 y esta verificación.';
  }

  @override
  String get onbSeeDetail => 'Ver el detalle';

  @override
  String get onbGoHome => 'Ir a mi inicio';

  @override
  String onbContributes(String name, String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count compras',
      one: '1 compra',
    );
    return '$name aporta $amount ($_temp0).';
  }

  @override
  String get onbVerdictStatusUnder => 'De menos';

  @override
  String get onbVerdictStatusOver => 'De más';

  @override
  String get onbVerdictStatusMatch => 'Bien';

  @override
  String get processingTitle => 'Leyendo tu estado de cuenta';

  @override
  String get processingAnalyzing => 'Analizando con IA';

  @override
  String get processingEta => 'unos 40 s';

  @override
  String get processingStepCard => 'Es tu tarjeta';

  @override
  String get processingStepPeriod => 'Encontrando el periodo y los movimientos';

  @override
  String get processingStepClassify => 'Clasificando compras en tus rubros';

  @override
  String get processingStepRates => 'Revisar tus % y calcular';

  @override
  String get processingCardLine => 'Verificando que sea la tarjeta elegida';

  @override
  String get processingCanLeave =>
      'Puedes cerrar la app: seguiremos analizando y lo verás en Inicio. La verificación solo se usa si la lectura sale bien.';

  @override
  String get processingLeave => 'Ir a mi inicio';

  @override
  String get processingDismiss => 'Entendido';

  @override
  String get pendingFailedTitle => 'No se pudo analizar';

  @override
  String get failureNotAStatement =>
      'El archivo no parece un estado de cuenta. Tu verificación fue devuelta: elige otro PDF.';

  @override
  String get failureExtraction =>
      'No pudimos leer tu estado de cuenta. Tu verificación fue devuelta: inténtalo de nuevo.';

  @override
  String get failureInterrupted =>
      'El análisis se interrumpió. Tu verificación fue devuelta: inténtalo de nuevo.';

  @override
  String get pendingProcessingTitle => 'Analizando…';

  @override
  String pendingProcessingBody(String card) {
    return '$card · puedes cerrar la app';
  }

  @override
  String get pendingAwaitingTitle => 'Lista para confirmar';

  @override
  String get pendingAwaitingBody => 'Falta confirmar tus %';

  @override
  String get pendingCompletedTitle => 'Resultado nuevo';

  @override
  String pendingCompletedBody(String card) {
    return '$card · toca para verlo';
  }

  @override
  String get pendingFollow => 'Seguir';

  @override
  String homeGreetingMorning(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Buenos días',
      'other': 'Buenos días, $name',
    });
    return '$_temp0';
  }

  @override
  String homeGreetingAfternoon(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Buenas tardes',
      'other': 'Buenas tardes, $name',
    });
    return '$_temp0';
  }

  @override
  String homeGreetingEvening(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Buenas noches',
      'other': 'Buenas noches, $name',
    });
    return '$_temp0';
  }

  @override
  String get homeTitle => 'Tu cashback';

  @override
  String get homeProfileAria => 'Perfil y ajustes';

  @override
  String homeFreeChecks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n verificaciones gratis disponibles',
      one: '1 verificación gratis disponible',
    );
    return '$_temp0';
  }

  @override
  String get homeEmptyTitle => 'Empecemos por tu tarjeta';

  @override
  String get homeEmptyCardPlaceholder => 'Tu tarjeta';

  @override
  String get homeStep1Bold => 'Agrega tu tarjeta';

  @override
  String get homeStep1Rest => ' con sus rubros y porcentajes.';

  @override
  String get homeStep2Bold => 'Sube tu PDF';

  @override
  String get homeStep2Rest =>
      ' y en menos de un minuto sabrás si te pagaron bien.';

  @override
  String get homeAddMyCard => 'Agregar mi tarjeta';

  @override
  String get homeNoChecksTitle => 'Aún no tienes verificaciones';

  @override
  String get homeNoChecksBody => 'Aquí verás cada veredicto de tu banco.';

  @override
  String get homeGuidedSetup => 'Prefiero la configuración guiada';

  @override
  String homeFreshBanner(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Listo. Aquí está todo lo que configuraste: tu tarjeta, sus rubros y tu primera verificación.',
      'other':
          'Listo, $name. Aquí está todo lo que configuraste: tu tarjeta, sus rubros y tu primera verificación.',
    });
    return '$_temp0';
  }

  @override
  String get homeVerifyStatement => 'Verificar estado de cuenta';

  @override
  String get homeUsedFree => 'Usaste tu verificación gratis';

  @override
  String get homeGetMore => 'Obtener más';

  @override
  String homeChecksAvailable(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n verificaciones disponibles',
      one: '1 verificación disponible',
    );
    return '$_temp0';
  }

  @override
  String get homeMyCard => 'Mi tarjeta';

  @override
  String get homeMyCards => 'Mis tarjetas';

  @override
  String get homeTapToEdit => 'Toca para editar';

  @override
  String get homeAddAnotherCard => 'Agregar otra tarjeta';

  @override
  String get homeAddCardTile => 'Agregar tarjeta';

  @override
  String homeCardMeta(String bank, String rate, String rules) {
    return '$bank · base $rate · $rules';
  }

  @override
  String homeEverythingElse(String rate) {
    return 'Todo lo demás $rate';
  }

  @override
  String get homeFirstVerification => 'Tu primera verificación';

  @override
  String homeUncategorized(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n compras quedaron sin rubro',
      one: '1 compra quedó sin rubro',
    );
    return '$_temp0 · revísalas gratis';
  }

  @override
  String get homeLatestChecks => 'Últimas verificaciones';

  @override
  String get homeSeeAll => 'Ver todas';

  @override
  String get homeOffline => 'Sin conexión. Mostrando datos guardados.';

  @override
  String get navHome => 'Inicio';

  @override
  String get navHistory => 'Historial';

  @override
  String get navCategories => 'Rubros';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navAria => 'Navegación principal';

  @override
  String get cardBasicCaption => 'Básico';

  @override
  String get cardNameLabel => 'Nombre de la tarjeta';

  @override
  String get cardLast4Short => 'Últimos 4';

  @override
  String get cardRewardKindQuestion => '¿Qué te da?';

  @override
  String get cardUnitCashback => 'Cashback en dinero';

  @override
  String get cardUnitPoints => 'Puntos o millas';

  @override
  String get cardBaseRateLabel => 'Tasa base';

  @override
  String get cardBaseRateHelp =>
      'Lo que gana cualquier compra que no está en un rubro especial.';

  @override
  String get cardRulesTitle => 'Rubros con % especial';

  @override
  String get cardAddRule => '+ Agregar rubro';

  @override
  String get cardAddCap => '+ Tope mensual';

  @override
  String get cardAdvancedTitle => 'Opciones avanzadas';

  @override
  String get cardAdvancedSubtitle => 'Red, moneda, programa a auditar…';

  @override
  String get cardNetworkLabel => 'Red';

  @override
  String get cardOptionalTag => '(opcional)';

  @override
  String get cardNetworkOther => 'Otra';

  @override
  String get cardNetworkOtherHint => 'Nombre de la red';

  @override
  String get cardMainCurrency => 'Moneda principal de la tarjeta';

  @override
  String get cardProgramLabel => 'Programa a auditar';

  @override
  String get cardProgramHelp =>
      'Si tu estado de cuenta trae varios programas (cash, puntos, millas), elige cuál revisamos.';

  @override
  String get cardRewardCurrencyQuestion => 'Moneda en que recibes el cashback';

  @override
  String get cardRewardDetect => 'Detectar sola';

  @override
  String get cardRewardCurrencyNote =>
      'Si es distinta a la de tus compras, te pediremos el tipo de cambio al verificar.';

  @override
  String get cardCurrencyOtherHint => 'Otro código (3 letras)';

  @override
  String get cardDeleteAction => 'Eliminar tarjeta';

  @override
  String get cardDeleteNote =>
      'También se elimina su historial de verificaciones.';

  @override
  String get cardClose => 'Cerrar';

  @override
  String get catalogNewCategory => '+ Nuevo rubro';

  @override
  String get catalogIntroTitle =>
      'Los rubros son los tipos de compra que tu banco premia más';

  @override
  String get catalogIntroBody =>
      'Por ejemplo, 7% en supermercados. Créalos una vez y los usamos en todas tus tarjetas. No necesitas registrar comercios: la IA reconoce que «Farmacia Kielsa 61» es una farmacia.';

  @override
  String get catalogQuickAdd => 'Agrega con un toque';

  @override
  String get catalogCreateOther => 'Crear otro rubro';

  @override
  String get catalogOptionalNote =>
      'Registrar comercios es opcional; sirve para que una compra siempre caiga en el rubro correcto.';

  @override
  String get catalogByAi => 'Por IA';

  @override
  String get catalogAddMerchant => '+ Agregar comercio';

  @override
  String get catalogMore => 'Más acciones';

  @override
  String catalogRuleTag(String card, String rate) {
    return '$card $rate';
  }

  @override
  String get verifyStepCard => '1 · ¿De qué tarjeta es?';

  @override
  String get verifyStepFile => '2 · El PDF del banco';

  @override
  String get verifyPickHint =>
      'El original que descargas de la banca en línea. Se lee en memoria y no se guarda.';

  @override
  String verifyCardCashback(String currency, String rules) {
    return 'Cashback en $currency · $rules';
  }

  @override
  String verifyCardPoints(String rules) {
    return 'Puntos · $rules';
  }

  @override
  String verifyAvailablePill(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n disponibles',
      one: '1 disponible',
    );
    return '$_temp0';
  }

  @override
  String get verifyNoneLeftPill => 'Sin verificaciones';

  @override
  String get verifyCreditNote =>
      'Se usa una verificación solo si la lectura sale bien. Recalcular es gratis.';

  @override
  String get verifyCta => 'Analizar';

  @override
  String get verifyCtaPickFile => 'Analizar · elige un PDF';

  @override
  String get verifyCtaPickCard => 'Analizar · elige una tarjeta';

  @override
  String get verifyClose => 'Cerrar';

  @override
  String get processingBackground => 'Seguir en segundo plano';

  @override
  String get processingFileBadge => 'PDF';

  @override
  String get processingUploadingEta => 'subiendo…';

  @override
  String get failureRefundedPill => 'Verificación devuelta';

  @override
  String get failureRetry => 'Intentar de nuevo';

  @override
  String get failureChooseAnother => 'Elegir otro PDF';

  @override
  String get failureTitleNotAStatement => 'No parece un estado de cuenta';

  @override
  String get failureTitleExtraction => 'No pudimos leerlo';

  @override
  String get failureTitleInterrupted => 'Se interrumpió el análisis';

  @override
  String get errVerificationNotReady =>
      'Tu estado de cuenta todavía se está analizando. Espera a que termine.';

  @override
  String suggestionsTitleN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n rubros que no tienes',
      one: '1 rubro que no tienes',
    );
    return 'Tu banco menciona $_temp0';
  }

  @override
  String createNSuggestions(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Crear $n rubros · gratis',
      one: 'Crear 1 rubro · gratis',
    );
    return '$_temp0';
  }

  @override
  String suggestionTxns(int n) {
    return '$n mov.';
  }

  @override
  String get rateCapAdd => '+ Tope mensual (opcional)';

  @override
  String get exchangeRewardTitle => 'Tipo de cambio de tu cashback';

  @override
  String exchangeRewardBody(String bank, String reward, String primary) {
    return '$bank te paga el cashback en $reward, pero tus compras son en $primary. Necesitamos convertirlo.';
  }

  @override
  String get yourBankFallback => 'Tu banco';

  @override
  String exchangeQuestion(String unit, String target) {
    return '1 $unit = ¿cuántos $target?';
  }

  @override
  String exchangeEnterHint(String unit, String target) {
    return 'Escribe cuántos $target vale 1 $unit.';
  }

  @override
  String get exchangeFindHint =>
      'Lo encuentras en tu estado de cuenta o en el sitio de tu banco.';

  @override
  String exchangeForeignTitle(String currency) {
    return 'Compras en $currency';
  }

  @override
  String get confirmProgramTitle => 'Programa que auditamos';

  @override
  String confirmProgramBody(String name) {
    return '$name · se tomará el valor ganado en el periodo, no el saldo disponible.';
  }

  @override
  String confirmMissingOne(String name) {
    return 'Falta: $name';
  }

  @override
  String confirmCheckOne(String name) {
    return 'Revisa: $name';
  }

  @override
  String confirmMissingMany(int n) {
    return '$n campos por completar o revisar';
  }
}
