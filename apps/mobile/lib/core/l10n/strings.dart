/// All user-facing copy lives here (Spanish, neutral/Mexico) so it can be
/// moved to proper localization later. Identifiers stay in English.
abstract final class S {
  static const appName = 'Cashback Audit';
  static const tagline = 'Verifica que tu banco te pague lo que te corresponde.';

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
  static const errConflict = 'Esa acción entra en conflicto con datos existentes.';
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
}
