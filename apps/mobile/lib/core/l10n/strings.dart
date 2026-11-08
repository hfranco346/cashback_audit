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
  static const errSubscription =
      'Necesitas una suscripción activa para verificar estados de cuenta.';
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
  static const longPressHint = 'Mantén presionada una tarjeta para eliminarla';
}
