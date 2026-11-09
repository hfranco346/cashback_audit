import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'Cashback Audit'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In es, this message translates to:
  /// **'Verifica que tu banco te pague lo que te corresponde.'**
  String get tagline;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @continueLabel.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueLabel;

  /// No description provided for @skip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get skip;

  /// No description provided for @devSignIn.
  ///
  /// In es, this message translates to:
  /// **'Entrar como usuario de prueba (desarrollo)'**
  String get devSignIn;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get back;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get loading;

  /// No description provided for @offlineBanner.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Mostrando datos guardados.'**
  String get offlineBanner;

  /// No description provided for @errNetwork.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.'**
  String get errNetwork;

  /// No description provided for @errTimeout.
  ///
  /// In es, this message translates to:
  /// **'La solicitud tardó demasiado. Inténtalo de nuevo.'**
  String get errTimeout;

  /// No description provided for @errUnauthorized.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró. Inicia sesión otra vez.'**
  String get errUnauthorized;

  /// No description provided for @errNoCredits.
  ///
  /// In es, this message translates to:
  /// **'No tienes verificaciones disponibles. Suscríbete o compra un paquete para continuar.'**
  String get errNoCredits;

  /// No description provided for @errRatesRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe el porcentaje de los rubros marcados como obligatorios.'**
  String get errRatesRequired;

  /// No description provided for @errProgramAmbiguous.
  ///
  /// In es, this message translates to:
  /// **'Tu estado de cuenta tiene varios programas de recompensa. Elige cuál auditar.'**
  String get errProgramAmbiguous;

  /// No description provided for @errTransactionNotFound.
  ///
  /// In es, this message translates to:
  /// **'No encontramos ese movimiento.'**
  String get errTransactionNotFound;

  /// No description provided for @errTransactionNotClassifiable.
  ///
  /// In es, this message translates to:
  /// **'Este movimiento no genera recompensa, así que no se puede asignar a un rubro.'**
  String get errTransactionNotClassifiable;

  /// No description provided for @errVerificationNotFound.
  ///
  /// In es, this message translates to:
  /// **'Esta verificación ya no existe. Las que no se confirman en 7 días se eliminan.'**
  String get errVerificationNotFound;

  /// No description provided for @errValidation.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos e inténtalo de nuevo.'**
  String get errValidation;

  /// No description provided for @errNotFound.
  ///
  /// In es, this message translates to:
  /// **'No encontramos lo que buscabas.'**
  String get errNotFound;

  /// No description provided for @errConflict.
  ///
  /// In es, this message translates to:
  /// **'Esa acción entra en conflicto con datos existentes.'**
  String get errConflict;

  /// No description provided for @errTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El archivo supera el límite de 10 MB.'**
  String get errTooLarge;

  /// No description provided for @errNotPdf.
  ///
  /// In es, this message translates to:
  /// **'Solo se aceptan archivos PDF.'**
  String get errNotPdf;

  /// No description provided for @errRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Espera un momento e inténtalo otra vez.'**
  String get errRateLimited;

  /// No description provided for @errServer.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal de nuestro lado. Inténtalo de nuevo en unos minutos.'**
  String get errServer;

  /// No description provided for @errUnknown.
  ///
  /// In es, this message translates to:
  /// **'Ocurrió un error inesperado.'**
  String get errUnknown;

  /// No description provided for @errCategoryNameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes un rubro con ese nombre.'**
  String get errCategoryNameTaken;

  /// No description provided for @errMerchantNameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes un comercio con ese nombre.'**
  String get errMerchantNameTaken;

  /// No description provided for @errCategoryInUse.
  ///
  /// In es, this message translates to:
  /// **'Este rubro tiene comercios o reglas de tarjeta. Elige a qué rubro moverlos.'**
  String get errCategoryInUse;

  /// No description provided for @errInvalidPdf.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es un PDF válido.'**
  String get errInvalidPdf;

  /// No description provided for @errUnreadable.
  ///
  /// In es, this message translates to:
  /// **'No pudimos leer ese estado de cuenta. Descarga el PDF original desde tu banco (no una foto ni un archivo con contraseña).'**
  String get errUnreadable;

  /// No description provided for @errRewardRateRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe cuánto vale la moneda de la recompensa para poder convertirla.'**
  String get errRewardRateRequired;

  /// No description provided for @errInvalidExchangeRate.
  ///
  /// In es, this message translates to:
  /// **'Revisa los tipos de cambio: deben ser números mayores a 0 (máximo 6 decimales).'**
  String get errInvalidExchangeRate;

  /// No description provided for @errRewardNotFound.
  ///
  /// In es, this message translates to:
  /// **'El estado de cuenta no muestra la recompensa que te dio el banco. Escríbela para continuar.'**
  String get errRewardNotFound;

  /// No description provided for @errExtractionFailed.
  ///
  /// In es, this message translates to:
  /// **'El análisis no devolvió un resultado utilizable. Suele funcionar al reintentar.'**
  String get errExtractionFailed;

  /// No description provided for @errExtractionUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El servicio de análisis está ocupado. Inténtalo más tarde.'**
  String get errExtractionUnavailable;

  /// No description provided for @errIdentityToken.
  ///
  /// In es, this message translates to:
  /// **'No pudimos validar tu cuenta. Inténtalo de nuevo.'**
  String get errIdentityToken;

  /// No description provided for @errIdentityUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El inicio de sesión no está disponible por ahora.'**
  String get errIdentityUnavailable;

  /// No description provided for @errSignInFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar el inicio de sesión. Inténtalo de nuevo.'**
  String get errSignInFailed;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In es, this message translates to:
  /// **'Sesión finalizada'**
  String get sessionExpiredTitle;

  /// No description provided for @onb1Title.
  ///
  /// In es, this message translates to:
  /// **'Comprueba lo que tu banco te debe'**
  String get onb1Title;

  /// No description provided for @onb1Body.
  ///
  /// In es, this message translates to:
  /// **'Sube tu estado de cuenta y calculamos cuánto cashback o cuántos puntos deberías haber recibido.'**
  String get onb1Body;

  /// No description provided for @onb2Title.
  ///
  /// In es, this message translates to:
  /// **'Registra tus tarjetas y rubros'**
  String get onb2Title;

  /// No description provided for @onb2Body.
  ///
  /// In es, this message translates to:
  /// **'Captura la tasa base de cada tarjeta y los porcentajes por rubro (súper, gasolina, restaurantes…). Asigna cada comercio al rubro en el que esperas que acumule.'**
  String get onb2Body;

  /// No description provided for @onb3Title.
  ///
  /// In es, this message translates to:
  /// **'Sube el PDF y revisa el veredicto'**
  String get onb3Title;

  /// No description provided for @onb3Body.
  ///
  /// In es, this message translates to:
  /// **'Te mostramos si el pago coincide, si te pagaron de menos o de más, con el detalle por rubro y por movimiento.'**
  String get onb3Body;

  /// No description provided for @onb4Title.
  ///
  /// In es, this message translates to:
  /// **'Tu privacidad primero'**
  String get onb4Title;

  /// No description provided for @onb4Body.
  ///
  /// In es, this message translates to:
  /// **'Nunca guardamos tu PDF ni el número completo de tu tarjeta: solo los últimos 4 dígitos y los resultados del análisis.'**
  String get onb4Body;

  /// No description provided for @start.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get start;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Usa tu cuenta para guardar tus tarjetas, rubros y el historial de verificaciones.'**
  String get loginSubtitle;

  /// No description provided for @signInGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get signInGoogle;

  /// No description provided for @signInApple.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get signInApple;

  /// No description provided for @loginLegal.
  ///
  /// In es, this message translates to:
  /// **'No almacenamos tu PDF ni el número completo de tu tarjeta.'**
  String get loginLegal;

  /// No description provided for @fieldRequired.
  ///
  /// In es, this message translates to:
  /// **'Este campo es obligatorio'**
  String get fieldRequired;

  /// No description provided for @last4Invalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe exactamente 4 dígitos'**
  String get last4Invalid;

  /// No description provided for @currencyInvalid.
  ///
  /// In es, this message translates to:
  /// **'Usa un código de 3 letras (MXN, USD…)'**
  String get currencyInvalid;

  /// No description provided for @numberInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe un número válido'**
  String get numberInvalid;

  /// No description provided for @percentRange.
  ///
  /// In es, this message translates to:
  /// **'Debe estar entre 0 y 100'**
  String get percentRange;

  /// No description provided for @capInvalid.
  ///
  /// In es, this message translates to:
  /// **'Debe ser mayor a 0 (máximo 2 decimales)'**
  String get capInvalid;

  /// No description provided for @pointsFactorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Debe ser mayor a 0 y hasta 1000'**
  String get pointsFactorInvalid;

  /// No description provided for @homeCards.
  ///
  /// In es, this message translates to:
  /// **'Mis tarjetas'**
  String get homeCards;

  /// No description provided for @homeNoCardsTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes tarjetas'**
  String get homeNoCardsTitle;

  /// No description provided for @homeNoCardsBody.
  ///
  /// In es, this message translates to:
  /// **'Agrega tu primera tarjeta con sus tasas de recompensa para empezar a auditar.'**
  String get homeNoCardsBody;

  /// No description provided for @addCard.
  ///
  /// In es, this message translates to:
  /// **'Agregar tarjeta'**
  String get addCard;

  /// No description provided for @manageCategories.
  ///
  /// In es, this message translates to:
  /// **'Rubros y comercios'**
  String get manageCategories;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @loadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus datos.'**
  String get loadError;

  /// No description provided for @newCard.
  ///
  /// In es, this message translates to:
  /// **'Nueva tarjeta'**
  String get newCard;

  /// No description provided for @editCard.
  ///
  /// In es, this message translates to:
  /// **'Editar tarjeta'**
  String get editCard;

  /// No description provided for @cardAlias.
  ///
  /// In es, this message translates to:
  /// **'Alias'**
  String get cardAlias;

  /// No description provided for @cardAliasHint.
  ///
  /// In es, this message translates to:
  /// **'Ej. Tarjeta diaria'**
  String get cardAliasHint;

  /// No description provided for @cardBank.
  ///
  /// In es, this message translates to:
  /// **'Banco'**
  String get cardBank;

  /// No description provided for @cardLast4.
  ///
  /// In es, this message translates to:
  /// **'Últimos 4 dígitos'**
  String get cardLast4;

  /// No description provided for @cardLast4Helper.
  ///
  /// In es, this message translates to:
  /// **'Nunca pedimos el número completo.'**
  String get cardLast4Helper;

  /// No description provided for @cardNetwork.
  ///
  /// In es, this message translates to:
  /// **'Red (opcional)'**
  String get cardNetwork;

  /// No description provided for @cardCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get cardCurrency;

  /// No description provided for @cardRewardProgram.
  ///
  /// In es, this message translates to:
  /// **'Programa de recompensa a auditar'**
  String get cardRewardProgram;

  /// No description provided for @cardRewardProgramHelper.
  ///
  /// In es, this message translates to:
  /// **'Opcional. Si tu estado de cuenta lista varios programas (p. ej. CASH BAC), escribe el nombre del que quieres auditar.'**
  String get cardRewardProgramHelper;

  /// No description provided for @cardRewardCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda en que recibes la recompensa'**
  String get cardRewardCurrency;

  /// No description provided for @cardRewardCurrencyHelper.
  ///
  /// In es, this message translates to:
  /// **'Opcional. Si tu banco paga la recompensa en otra moneda que tus compras (p. ej. dólares), indícala. Vacío = detectar automáticamente.'**
  String get cardRewardCurrencyHelper;

  /// No description provided for @cardRewardCurrencyAuto.
  ///
  /// In es, this message translates to:
  /// **'Detectar automáticamente'**
  String get cardRewardCurrencyAuto;

  /// No description provided for @rewardUnitLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipo de recompensa'**
  String get rewardUnitLabel;

  /// No description provided for @unitCashback.
  ///
  /// In es, this message translates to:
  /// **'Cashback'**
  String get unitCashback;

  /// No description provided for @unitPoints.
  ///
  /// In es, this message translates to:
  /// **'Puntos'**
  String get unitPoints;

  /// No description provided for @pointsPerUnit.
  ///
  /// In es, this message translates to:
  /// **'Puntos por cada \$1 de recompensa'**
  String get pointsPerUnit;

  /// No description provided for @baseRate.
  ///
  /// In es, this message translates to:
  /// **'Tasa base (%)'**
  String get baseRate;

  /// No description provided for @baseRateHelper.
  ///
  /// In es, this message translates to:
  /// **'Se aplica a todo gasto sin regla por rubro.'**
  String get baseRateHelper;

  /// No description provided for @rulesTitle.
  ///
  /// In es, this message translates to:
  /// **'Reglas por rubro'**
  String get rulesTitle;

  /// No description provided for @rulesHelper.
  ///
  /// In es, this message translates to:
  /// **'Define una tasa distinta para cada rubro, con tope mensual opcional.'**
  String get rulesHelper;

  /// No description provided for @addRule.
  ///
  /// In es, this message translates to:
  /// **'Agregar regla'**
  String get addRule;

  /// No description provided for @ruleCategory.
  ///
  /// In es, this message translates to:
  /// **'Rubro'**
  String get ruleCategory;

  /// No description provided for @ruleRate.
  ///
  /// In es, this message translates to:
  /// **'Tasa (%)'**
  String get ruleRate;

  /// No description provided for @ruleCap.
  ///
  /// In es, this message translates to:
  /// **'Tope mensual'**
  String get ruleCap;

  /// No description provided for @ruleCapHelper.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get ruleCapHelper;

  /// No description provided for @removeRule.
  ///
  /// In es, this message translates to:
  /// **'Quitar regla'**
  String get removeRule;

  /// No description provided for @ruleNeedsCategories.
  ///
  /// In es, this message translates to:
  /// **'Primero crea al menos un rubro para definir reglas.'**
  String get ruleNeedsCategories;

  /// No description provided for @ruleCategoryRequired.
  ///
  /// In es, this message translates to:
  /// **'Elige un rubro'**
  String get ruleCategoryRequired;

  /// No description provided for @ruleDuplicateCategory.
  ///
  /// In es, this message translates to:
  /// **'Ya hay una regla para ese rubro'**
  String get ruleDuplicateCategory;

  /// No description provided for @deleteCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar tarjeta'**
  String get deleteCardTitle;

  /// No description provided for @cardSaved.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta guardada'**
  String get cardSaved;

  /// No description provided for @cardDeleted.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta eliminada'**
  String get cardDeleted;

  /// No description provided for @catalogTitle.
  ///
  /// In es, this message translates to:
  /// **'Rubros y comercios'**
  String get catalogTitle;

  /// No description provided for @addCategory.
  ///
  /// In es, this message translates to:
  /// **'Nuevo rubro'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In es, this message translates to:
  /// **'Editar rubro'**
  String get editCategory;

  /// No description provided for @categoryName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del rubro'**
  String get categoryName;

  /// No description provided for @categoryDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get categoryDescription;

  /// No description provided for @addMerchant.
  ///
  /// In es, this message translates to:
  /// **'Agregar comercio'**
  String get addMerchant;

  /// No description provided for @editMerchant.
  ///
  /// In es, this message translates to:
  /// **'Editar comercio'**
  String get editMerchant;

  /// No description provided for @merchantName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del comercio'**
  String get merchantName;

  /// No description provided for @merchantKeywords.
  ///
  /// In es, this message translates to:
  /// **'Palabras clave del estado de cuenta'**
  String get merchantKeywords;

  /// No description provided for @merchantKeywordsHelper.
  ///
  /// In es, this message translates to:
  /// **'Como aparecen en tu estado de cuenta, separadas por coma. Ej. WAL MART, WALMART SUC'**
  String get merchantKeywordsHelper;

  /// No description provided for @merchantCategory.
  ///
  /// In es, this message translates to:
  /// **'Rubro esperado'**
  String get merchantCategory;

  /// No description provided for @noMerchants.
  ///
  /// In es, this message translates to:
  /// **'Sin comercios'**
  String get noMerchants;

  /// No description provided for @catalogEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Crea tu primer rubro'**
  String get catalogEmptyTitle;

  /// No description provided for @catalogEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Los rubros (súper, gasolina, restaurantes…) agrupan comercios y reciben tasas especiales en tus tarjetas.'**
  String get catalogEmptyBody;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar rubro'**
  String get deleteCategoryTitle;

  /// No description provided for @reassignTo.
  ///
  /// In es, this message translates to:
  /// **'Mover a'**
  String get reassignTo;

  /// No description provided for @reassignAndDelete.
  ///
  /// In es, this message translates to:
  /// **'Mover y eliminar'**
  String get reassignAndDelete;

  /// No description provided for @deleteMerchantTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar comercio'**
  String get deleteMerchantTitle;

  /// No description provided for @needOtherCategory.
  ///
  /// In es, this message translates to:
  /// **'Crea otro rubro para poder mover los elementos.'**
  String get needOtherCategory;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil y ajustes'**
  String get settingsTitle;

  /// No description provided for @appearanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearanceTitle;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @longPressHint.
  ///
  /// In es, this message translates to:
  /// **'Mantén presionada una tarjeta para eliminarla'**
  String get longPressHint;

  /// No description provided for @uploadTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificar estado de cuenta'**
  String get uploadTitle;

  /// No description provided for @uploadStep1.
  ///
  /// In es, this message translates to:
  /// **'Elige la tarjeta'**
  String get uploadStep1;

  /// No description provided for @uploadStep2.
  ///
  /// In es, this message translates to:
  /// **'Selecciona el PDF'**
  String get uploadStep2;

  /// No description provided for @pickPdf.
  ///
  /// In es, this message translates to:
  /// **'Elegir PDF'**
  String get pickPdf;

  /// No description provided for @changePdf.
  ///
  /// In es, this message translates to:
  /// **'Cambiar archivo'**
  String get changePdf;

  /// No description provided for @noCardsForUpload.
  ///
  /// In es, this message translates to:
  /// **'Primero agrega una tarjeta para poder verificar un estado de cuenta.'**
  String get noCardsForUpload;

  /// No description provided for @verify.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get verify;

  /// No description provided for @uploading.
  ///
  /// In es, this message translates to:
  /// **'Subiendo archivo…'**
  String get uploading;

  /// No description provided for @analyzing.
  ///
  /// In es, this message translates to:
  /// **'Analizando tu estado de cuenta…'**
  String get analyzing;

  /// No description provided for @analyzingHint.
  ///
  /// In es, this message translates to:
  /// **'Puede tardar hasta un minuto. No cierres la app.'**
  String get analyzingHint;

  /// No description provided for @uploadPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Procesamos el PDF en memoria y no lo guardamos.'**
  String get uploadPrivacy;

  /// No description provided for @fileTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El archivo supera el límite de 10 MB.'**
  String get fileTooLarge;

  /// No description provided for @fileNotPdf.
  ///
  /// In es, this message translates to:
  /// **'Elige un archivo PDF.'**
  String get fileNotPdf;

  /// No description provided for @uploadTimeout.
  ///
  /// In es, this message translates to:
  /// **'El análisis tardó demasiado. Revisa tu historial antes de reintentar: puede que ya se haya procesado.'**
  String get uploadTimeout;

  /// No description provided for @overrideTitle.
  ///
  /// In es, this message translates to:
  /// **'Escribe la recompensa que te dio el banco'**
  String get overrideTitle;

  /// No description provided for @overrideLabel.
  ///
  /// In es, this message translates to:
  /// **'Recompensa reportada'**
  String get overrideLabel;

  /// No description provided for @overrideHelper.
  ///
  /// In es, this message translates to:
  /// **'Búscala en tu estado de cuenta (bonificación o puntos del periodo).'**
  String get overrideHelper;

  /// No description provided for @overrideInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe un monto válido (hasta 2 decimales)'**
  String get overrideInvalid;

  /// No description provided for @selectCardFirst.
  ///
  /// In es, this message translates to:
  /// **'Elige una tarjeta'**
  String get selectCardFirst;

  /// No description provided for @analyzingStepUpload.
  ///
  /// In es, this message translates to:
  /// **'Archivo recibido'**
  String get analyzingStepUpload;

  /// No description provided for @analyzingStepRead.
  ///
  /// In es, this message translates to:
  /// **'Leyendo tu estado de cuenta'**
  String get analyzingStepRead;

  /// No description provided for @analyzingStepClassify.
  ///
  /// In es, this message translates to:
  /// **'Clasificando movimientos'**
  String get analyzingStepClassify;

  /// No description provided for @analyzingExpect.
  ///
  /// In es, this message translates to:
  /// **'Este paso suele tardar cerca de 1 minuto. Después podrás confirmar los porcentajes.'**
  String get analyzingExpect;

  /// No description provided for @confirmRatesTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirma los porcentajes'**
  String get confirmRatesTitle;

  /// No description provided for @recalcRatesTitle.
  ///
  /// In es, this message translates to:
  /// **'Recalcular con otros %'**
  String get recalcRatesTitle;

  /// No description provided for @confirmRatesIntro.
  ///
  /// In es, this message translates to:
  /// **'Los bancos cambian sus políticas seguido. Revisa con qué porcentajes vamos a calcular lo que deberías haber recibido.'**
  String get confirmRatesIntro;

  /// No description provided for @confirmRatesNoCharge.
  ///
  /// In es, this message translates to:
  /// **'Calcular y recalcular no consume verificaciones.'**
  String get confirmRatesNoCharge;

  /// No description provided for @rateBaseTitle.
  ///
  /// In es, this message translates to:
  /// **'Tasa base'**
  String get rateBaseTitle;

  /// No description provided for @rateBaseSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Se aplica a todo gasto fuera de tus rubros.'**
  String get rateBaseSubtitle;

  /// No description provided for @rateFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'Porcentaje'**
  String get rateFieldLabel;

  /// No description provided for @rateCapLabel.
  ///
  /// In es, this message translates to:
  /// **'Tope mensual (opcional)'**
  String get rateCapLabel;

  /// No description provided for @badgeStatement.
  ///
  /// In es, this message translates to:
  /// **'Detectado en tu estado de cuenta'**
  String get badgeStatement;

  /// No description provided for @badgeCardRule.
  ///
  /// In es, this message translates to:
  /// **'De las reglas de tu tarjeta'**
  String get badgeCardRule;

  /// No description provided for @badgePrevious.
  ///
  /// In es, this message translates to:
  /// **'Los que usaste antes'**
  String get badgePrevious;

  /// No description provided for @badgeRequired.
  ///
  /// In es, this message translates to:
  /// **'Obligatorio'**
  String get badgeRequired;

  /// No description provided for @rateRequiredError.
  ///
  /// In es, this message translates to:
  /// **'Escribe el porcentaje para continuar'**
  String get rateRequiredError;

  /// No description provided for @saveToCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar estos % en la tarjeta'**
  String get saveToCardTitle;

  /// No description provided for @saveToCardSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Reemplaza la tasa base y las reglas por rubro de tu tarjeta.'**
  String get saveToCardSubtitle;

  /// No description provided for @exchangeRateTitle.
  ///
  /// In es, this message translates to:
  /// **'Tipo de cambio (opcional)'**
  String get exchangeRateTitle;

  /// No description provided for @exchangeRateMissing.
  ///
  /// In es, this message translates to:
  /// **'Hay compras en moneda extranjera. Sin tipo de cambio quedarán fuera del cálculo.'**
  String get exchangeRateMissing;

  /// No description provided for @exchangeRateInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe un número mayor a 0 (máximo 6 decimales)'**
  String get exchangeRateInvalid;

  /// No description provided for @rewardRateRequiredError.
  ///
  /// In es, this message translates to:
  /// **'Escribe el tipo de cambio para continuar'**
  String get rewardRateRequiredError;

  /// No description provided for @foreignRatesTitle.
  ///
  /// In es, this message translates to:
  /// **'Compras en otras monedas'**
  String get foreignRatesTitle;

  /// No description provided for @foreignRatesHelper.
  ///
  /// In es, this message translates to:
  /// **'Opcional. Si dejas un tipo de cambio vacío, las compras en esa moneda quedan fuera del cálculo.'**
  String get foreignRatesHelper;

  /// No description provided for @foreignRateOptional.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get foreignRateOptional;

  /// No description provided for @suggestionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu estado de cuenta menciona rubros que no tienes'**
  String get suggestionsTitle;

  /// No description provided for @suggestionsHelper.
  ///
  /// In es, this message translates to:
  /// **'Créalos para auditar esas compras con el porcentaje que indica tu banco.'**
  String get suggestionsHelper;

  /// No description provided for @suggestionsFree.
  ///
  /// In es, this message translates to:
  /// **'Es gratis: no consume verificaciones.'**
  String get suggestionsFree;

  /// No description provided for @createSuggestions.
  ///
  /// In es, this message translates to:
  /// **'Crear rubros seleccionados'**
  String get createSuggestions;

  /// No description provided for @creatingSuggestions.
  ///
  /// In es, this message translates to:
  /// **'Creando rubros…'**
  String get creatingSuggestions;

  /// No description provided for @suggestionsCreated.
  ///
  /// In es, this message translates to:
  /// **'Rubros creados. Ya aparecen abajo con el porcentaje de tu estado de cuenta.'**
  String get suggestionsCreated;

  /// No description provided for @programChooserTitle.
  ///
  /// In es, this message translates to:
  /// **'Elige el programa a auditar'**
  String get programChooserTitle;

  /// No description provided for @programChooserHelper.
  ///
  /// In es, this message translates to:
  /// **'Tu estado de cuenta lista varios programas de recompensa.'**
  String get programChooserHelper;

  /// No description provided for @programRequired.
  ///
  /// In es, this message translates to:
  /// **'Elige un programa para continuar'**
  String get programRequired;

  /// No description provided for @calculateResult.
  ///
  /// In es, this message translates to:
  /// **'Calcular resultado'**
  String get calculateResult;

  /// No description provided for @calculating.
  ///
  /// In es, this message translates to:
  /// **'Calculando…'**
  String get calculating;

  /// No description provided for @confirmLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar esta verificación.'**
  String get confirmLoadError;

  /// No description provided for @resultTitle.
  ///
  /// In es, this message translates to:
  /// **'Resultado'**
  String get resultTitle;

  /// No description provided for @resultNotConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Esta verificación aún no tiene resultado. Confirma los porcentajes para calcularlo.'**
  String get resultNotConfirmed;

  /// No description provided for @verdictMatch.
  ///
  /// In es, this message translates to:
  /// **'Todo en orden'**
  String get verdictMatch;

  /// No description provided for @verdictUnderpaid.
  ///
  /// In es, this message translates to:
  /// **'Te pagaron de menos'**
  String get verdictUnderpaid;

  /// No description provided for @verdictOverpaid.
  ///
  /// In es, this message translates to:
  /// **'Te pagaron de más'**
  String get verdictOverpaid;

  /// No description provided for @verdictMatchHint.
  ///
  /// In es, this message translates to:
  /// **'La recompensa coincide con lo esperado.'**
  String get verdictMatchHint;

  /// No description provided for @expectedLabel.
  ///
  /// In es, this message translates to:
  /// **'Esperado'**
  String get expectedLabel;

  /// No description provided for @reportedLabel.
  ///
  /// In es, this message translates to:
  /// **'Reportado'**
  String get reportedLabel;

  /// No description provided for @differenceLabel.
  ///
  /// In es, this message translates to:
  /// **'Diferencia'**
  String get differenceLabel;

  /// No description provided for @reportedOverrideNote.
  ///
  /// In es, this message translates to:
  /// **'Capturado por ti'**
  String get reportedOverrideNote;

  /// No description provided for @breakdownTitle.
  ///
  /// In es, this message translates to:
  /// **'Desglose por rubro'**
  String get breakdownTitle;

  /// No description provided for @baseRateLine.
  ///
  /// In es, this message translates to:
  /// **'Tasa base'**
  String get baseRateLine;

  /// No description provided for @capped.
  ///
  /// In es, this message translates to:
  /// **'Tope alcanzado'**
  String get capped;

  /// No description provided for @transactionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get transactionsTitle;

  /// No description provided for @filterAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get filterAll;

  /// No description provided for @filterCounted.
  ///
  /// In es, this message translates to:
  /// **'En rubro'**
  String get filterCounted;

  /// No description provided for @filterUncounted.
  ///
  /// In es, this message translates to:
  /// **'Sin rubro'**
  String get filterUncounted;

  /// No description provided for @filterExcluded.
  ///
  /// In es, this message translates to:
  /// **'Excluidos'**
  String get filterExcluded;

  /// No description provided for @countedLabel.
  ///
  /// In es, this message translates to:
  /// **'Contó en rubro'**
  String get countedLabel;

  /// No description provided for @uncountedLabel.
  ///
  /// In es, this message translates to:
  /// **'Sin rubro'**
  String get uncountedLabel;

  /// No description provided for @excludedLabel.
  ///
  /// In es, this message translates to:
  /// **'No genera recompensa'**
  String get excludedLabel;

  /// No description provided for @aiChip.
  ///
  /// In es, this message translates to:
  /// **'IA'**
  String get aiChip;

  /// No description provided for @aiChipTooltip.
  ///
  /// In es, this message translates to:
  /// **'Asignado por inteligencia artificial'**
  String get aiChipTooltip;

  /// No description provided for @userChip.
  ///
  /// In es, this message translates to:
  /// **'Tú'**
  String get userChip;

  /// No description provided for @userChipTooltip.
  ///
  /// In es, this message translates to:
  /// **'Rubro corregido por ti'**
  String get userChipTooltip;

  /// No description provided for @excludedPayment.
  ///
  /// In es, this message translates to:
  /// **'Los pagos no generan recompensa'**
  String get excludedPayment;

  /// No description provided for @excludedFee.
  ///
  /// In es, this message translates to:
  /// **'Comisión o cargo'**
  String get excludedFee;

  /// No description provided for @excludedInterest.
  ///
  /// In es, this message translates to:
  /// **'Intereses'**
  String get excludedInterest;

  /// No description provided for @excludedInsurance.
  ///
  /// In es, this message translates to:
  /// **'Seguro'**
  String get excludedInsurance;

  /// No description provided for @excludedOther.
  ///
  /// In es, this message translates to:
  /// **'Movimiento que no genera recompensa'**
  String get excludedOther;

  /// No description provided for @changeCategory.
  ///
  /// In es, this message translates to:
  /// **'Cambiar rubro'**
  String get changeCategory;

  /// No description provided for @changeCategoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar el rubro de este movimiento'**
  String get changeCategoryTitle;

  /// No description provided for @noCategoryOption.
  ///
  /// In es, this message translates to:
  /// **'Sin rubro'**
  String get noCategoryOption;

  /// No description provided for @categoryChanged.
  ///
  /// In es, this message translates to:
  /// **'Rubro actualizado y resultado recalculado'**
  String get categoryChanged;

  /// No description provided for @recalcFailedAfterChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiaste el rubro, pero no pudimos recalcular el resultado. Los montos mostrados siguen siendo los anteriores.'**
  String get recalcFailedAfterChange;

  /// No description provided for @recalcNeedsRate.
  ///
  /// In es, this message translates to:
  /// **'Ese rubro necesita un porcentaje. Confírmalo para recalcular.'**
  String get recalcNeedsRate;

  /// No description provided for @recalcAction.
  ///
  /// In es, this message translates to:
  /// **'Recalcular'**
  String get recalcAction;

  /// No description provided for @recalcWithOtherRates.
  ///
  /// In es, this message translates to:
  /// **'Recalcular con otros %'**
  String get recalcWithOtherRates;

  /// No description provided for @explanationTitle.
  ///
  /// In es, this message translates to:
  /// **'En pocas palabras'**
  String get explanationTitle;

  /// No description provided for @loyaltyTitle.
  ///
  /// In es, this message translates to:
  /// **'Programas de recompensa'**
  String get loyaltyTitle;

  /// No description provided for @loyaltyAudited.
  ///
  /// In es, this message translates to:
  /// **'Auditado'**
  String get loyaltyAudited;

  /// No description provided for @loyaltyCumulativeChip.
  ///
  /// In es, this message translates to:
  /// **'Posible saldo acumulado'**
  String get loyaltyCumulativeChip;

  /// No description provided for @loyaltyProgram.
  ///
  /// In es, this message translates to:
  /// **'Programa'**
  String get loyaltyProgram;

  /// No description provided for @loyaltyAccumulated.
  ///
  /// In es, this message translates to:
  /// **'Acumulado'**
  String get loyaltyAccumulated;

  /// No description provided for @loyaltyAvailable.
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get loyaltyAvailable;

  /// No description provided for @loyaltyRedeemed.
  ///
  /// In es, this message translates to:
  /// **'Canjeado'**
  String get loyaltyRedeemed;

  /// No description provided for @loyaltyExpiring.
  ///
  /// In es, this message translates to:
  /// **'Por vencer'**
  String get loyaltyExpiring;

  /// No description provided for @loyaltyForfeited.
  ///
  /// In es, this message translates to:
  /// **'Perdido'**
  String get loyaltyForfeited;

  /// No description provided for @currenciesTitle.
  ///
  /// In es, this message translates to:
  /// **'Subtotales por moneda'**
  String get currenciesTitle;

  /// No description provided for @currencySpent.
  ///
  /// In es, this message translates to:
  /// **'Gasto neto'**
  String get currencySpent;

  /// No description provided for @currencyEligible.
  ///
  /// In es, this message translates to:
  /// **'Considerado'**
  String get currencyEligible;

  /// No description provided for @currencyReward.
  ///
  /// In es, this message translates to:
  /// **'Recompensa (sin topes)'**
  String get currencyReward;

  /// No description provided for @appliedRatesTitle.
  ///
  /// In es, this message translates to:
  /// **'Porcentajes usados'**
  String get appliedRatesTitle;

  /// No description provided for @warnLast4.
  ///
  /// In es, this message translates to:
  /// **'Este estado de cuenta parece ser de otra tarjeta: los últimos 4 dígitos no coinciden.'**
  String get warnLast4;

  /// No description provided for @warnCurrencyMismatch.
  ///
  /// In es, this message translates to:
  /// **'Ninguna moneda del estado de cuenta coincide con la moneda de tu tarjeta.'**
  String get warnCurrencyMismatch;

  /// No description provided for @warnTotalMismatch.
  ///
  /// In es, this message translates to:
  /// **'Los movimientos leídos no suman el total del estado de cuenta. Puede que falten algunos y el resultado sea poco confiable.'**
  String get warnTotalMismatch;

  /// No description provided for @warnNoTransactions.
  ///
  /// In es, this message translates to:
  /// **'No encontramos movimientos en el estado de cuenta.'**
  String get warnNoTransactions;

  /// No description provided for @warnAiUnavailable.
  ///
  /// In es, this message translates to:
  /// **'La clasificación con IA no estuvo disponible para algunos movimientos; solo se usaron tus comercios registrados.'**
  String get warnAiUnavailable;

  /// No description provided for @warnNoExchangeRate.
  ///
  /// In es, this message translates to:
  /// **'Hay compras en moneda extranjera sin tipo de cambio: quedaron fuera del cálculo.'**
  String get warnNoExchangeRate;

  /// No description provided for @warnExchangeMultiple.
  ///
  /// In es, this message translates to:
  /// **'El tipo de cambio se aplicó a más de una moneda extranjera.'**
  String get warnExchangeMultiple;

  /// No description provided for @warnCumulative.
  ///
  /// In es, this message translates to:
  /// **'La cifra reportada parece un saldo acumulado y no lo ganado en este periodo. Revisa el programa.'**
  String get warnCumulative;

  /// No description provided for @warnUnitDiffers.
  ///
  /// In es, this message translates to:
  /// **'El programa reporta una unidad distinta a la de tu tarjeta; se usó la configuración de la tarjeta.'**
  String get warnUnitDiffers;

  /// No description provided for @assignToCategory.
  ///
  /// In es, this message translates to:
  /// **'Recordar comercio en un rubro'**
  String get assignToCategory;

  /// No description provided for @assignedNotice.
  ///
  /// In es, this message translates to:
  /// **'Asignado para próximas verificaciones'**
  String get assignedNotice;

  /// No description provided for @baseOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo tasa base'**
  String get baseOnly;

  /// No description provided for @creditPayment.
  ///
  /// In es, this message translates to:
  /// **'Pago a la tarjeta'**
  String get creditPayment;

  /// No description provided for @creditRefund.
  ///
  /// In es, this message translates to:
  /// **'Devolución'**
  String get creditRefund;

  /// No description provided for @creditOther.
  ///
  /// In es, this message translates to:
  /// **'Otro crédito / bonificación'**
  String get creditOther;

  /// No description provided for @rewardRateDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Conversión de la recompensa'**
  String get rewardRateDetailTitle;

  /// No description provided for @rewardRateFromStatement.
  ///
  /// In es, this message translates to:
  /// **'Tomado de tu estado de cuenta'**
  String get rewardRateFromStatement;

  /// No description provided for @rewardRateUserEntered.
  ///
  /// In es, this message translates to:
  /// **'Lo escribiste tú'**
  String get rewardRateUserEntered;

  /// No description provided for @assignSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Asignar comercio a un rubro'**
  String get assignSheetTitle;

  /// No description provided for @noCategoriesToAssign.
  ///
  /// In es, this message translates to:
  /// **'Crea un rubro primero para poder asignar este comercio.'**
  String get noCategoriesToAssign;

  /// No description provided for @goToCategories.
  ///
  /// In es, this message translates to:
  /// **'Ir a rubros'**
  String get goToCategories;

  /// No description provided for @merchantAssigned.
  ///
  /// In es, this message translates to:
  /// **'Comercio asignado'**
  String get merchantAssigned;

  /// No description provided for @warningsTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos'**
  String get warningsTitle;

  /// No description provided for @noTransactionsMatch.
  ///
  /// In es, this message translates to:
  /// **'No hay movimientos en esta vista.'**
  String get noTransactionsMatch;

  /// No description provided for @periodLabel.
  ///
  /// In es, this message translates to:
  /// **'Periodo'**
  String get periodLabel;

  /// No description provided for @deleteVerification.
  ///
  /// In es, this message translates to:
  /// **'Eliminar verificación'**
  String get deleteVerification;

  /// No description provided for @deleteVerificationBody.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta verificación del historial?'**
  String get deleteVerificationBody;

  /// No description provided for @awaitingRatesChip.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de confirmar %'**
  String get awaitingRatesChip;

  /// No description provided for @historyTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get historyTitle;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin verificaciones todavía'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando verifiques un estado de cuenta aparecerá aquí.'**
  String get historyEmptyBody;

  /// No description provided for @allCards.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get allCards;

  /// No description provided for @loadMore.
  ///
  /// In es, this message translates to:
  /// **'Ver más'**
  String get loadMore;

  /// No description provided for @latestVerifications.
  ///
  /// In es, this message translates to:
  /// **'Últimas verificaciones'**
  String get latestVerifications;

  /// No description provided for @seeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todo'**
  String get seeAll;

  /// No description provided for @verifyAction.
  ///
  /// In es, this message translates to:
  /// **'Verificar estado'**
  String get verifyAction;

  /// No description provided for @historyAction.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get historyAction;

  /// No description provided for @creditsNone.
  ///
  /// In es, this message translates to:
  /// **'Sin verificaciones disponibles'**
  String get creditsNone;

  /// No description provided for @uploadFreeNotice.
  ///
  /// In es, this message translates to:
  /// **'Tu primera verificación es gratis.'**
  String get uploadFreeNotice;

  /// No description provided for @uploadNoCredits.
  ///
  /// In es, this message translates to:
  /// **'No tienes verificaciones disponibles para analizar otro estado de cuenta.'**
  String get uploadNoCredits;

  /// No description provided for @seePlans.
  ///
  /// In es, this message translates to:
  /// **'Ver planes'**
  String get seePlans;

  /// No description provided for @creditsTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificaciones'**
  String get creditsTitle;

  /// No description provided for @creditsHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de verificaciones'**
  String get creditsHistoryTitle;

  /// No description provided for @creditsHistoryEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin movimientos todavía'**
  String get creditsHistoryEmptyTitle;

  /// No description provided for @creditsHistoryEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Aquí verás cuándo recibes, usas o te devolvemos verificaciones.'**
  String get creditsHistoryEmptyBody;

  /// No description provided for @creditsBuy.
  ///
  /// In es, this message translates to:
  /// **'Comprar verificaciones'**
  String get creditsBuy;

  /// No description provided for @creditReasonGrantFree.
  ///
  /// In es, this message translates to:
  /// **'Verificación gratis'**
  String get creditReasonGrantFree;

  /// No description provided for @creditReasonGrantPlan.
  ///
  /// In es, this message translates to:
  /// **'Verificaciones de tu suscripción'**
  String get creditReasonGrantPlan;

  /// No description provided for @creditReasonGrantPack.
  ///
  /// In es, this message translates to:
  /// **'Paquete comprado'**
  String get creditReasonGrantPack;

  /// No description provided for @creditReasonConsume.
  ///
  /// In es, this message translates to:
  /// **'Estado de cuenta analizado'**
  String get creditReasonConsume;

  /// No description provided for @creditReasonRefund.
  ///
  /// In es, this message translates to:
  /// **'Verificación devuelta'**
  String get creditReasonRefund;

  /// No description provided for @creditReasonExpirePlan.
  ///
  /// In es, this message translates to:
  /// **'Venció el saldo del plan'**
  String get creditReasonExpirePlan;

  /// No description provided for @creditReasonOther.
  ///
  /// In es, this message translates to:
  /// **'Ajuste'**
  String get creditReasonOther;

  /// No description provided for @creditBucketFree.
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get creditBucketFree;

  /// No description provided for @creditBucketPlan.
  ///
  /// In es, this message translates to:
  /// **'Plan'**
  String get creditBucketPlan;

  /// No description provided for @creditBucketPurchased.
  ///
  /// In es, this message translates to:
  /// **'Comprada'**
  String get creditBucketPurchased;

  /// No description provided for @paywallTitle.
  ///
  /// In es, this message translates to:
  /// **'Cashback Audit Pro'**
  String get paywallTitle;

  /// No description provided for @paywallHeadline.
  ///
  /// In es, this message translates to:
  /// **'Más verificaciones, cuando las necesites'**
  String get paywallHeadline;

  /// No description provided for @paywallBenefit1.
  ///
  /// In es, this message translates to:
  /// **'Cada estado de cuenta que analizas usa 1 verificación'**
  String get paywallBenefit1;

  /// No description provided for @paywallBenefit2.
  ///
  /// In es, this message translates to:
  /// **'Confirmar, recalcular y corregir movimientos no cuesta nada'**
  String get paywallBenefit2;

  /// No description provided for @paywallBenefit3.
  ///
  /// In es, this message translates to:
  /// **'Tu historial siempre queda disponible'**
  String get paywallBenefit3;

  /// No description provided for @paywallSubscriptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Suscripción mensual'**
  String get paywallSubscriptionTitle;

  /// No description provided for @paywallSubscriptionPerks.
  ///
  /// In es, this message translates to:
  /// **'5 verificaciones al mes · no se acumulan'**
  String get paywallSubscriptionPerks;

  /// No description provided for @paywallPacksTitle.
  ///
  /// In es, this message translates to:
  /// **'Paquetes de verificaciones'**
  String get paywallPacksTitle;

  /// No description provided for @paywallPacksSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Se compran una sola vez y no caducan.'**
  String get paywallPacksSubtitle;

  /// No description provided for @paywallBuy.
  ///
  /// In es, this message translates to:
  /// **'Comprar'**
  String get paywallBuy;

  /// No description provided for @paywallSuccessPack.
  ///
  /// In es, this message translates to:
  /// **'Tus verificaciones ya están disponibles.'**
  String get paywallSuccessPack;

  /// No description provided for @paywallConfirmingPurchase.
  ///
  /// In es, this message translates to:
  /// **'Confirmando tu compra…'**
  String get paywallConfirmingPurchase;

  /// No description provided for @paywallPendingPack.
  ///
  /// In es, this message translates to:
  /// **'Tu compra se está procesando. Las verificaciones pueden tardar unos segundos en aparecer.'**
  String get paywallPendingPack;

  /// No description provided for @restoreNothing.
  ///
  /// In es, this message translates to:
  /// **'No encontramos compras para restaurar en esta cuenta.'**
  String get restoreNothing;

  /// No description provided for @paywallSubscribe.
  ///
  /// In es, this message translates to:
  /// **'Suscribirme'**
  String get paywallSubscribe;

  /// No description provided for @paywallRestore.
  ///
  /// In es, this message translates to:
  /// **'Restaurar compras'**
  String get paywallRestore;

  /// No description provided for @paywallLegal.
  ///
  /// In es, this message translates to:
  /// **'La suscripción se renueva automáticamente. Puedes cancelarla en cualquier momento desde los ajustes de tu tienda de aplicaciones.'**
  String get paywallLegal;

  /// No description provided for @paywallNoPackages.
  ///
  /// In es, this message translates to:
  /// **'No hay planes disponibles por ahora. Inténtalo más tarde.'**
  String get paywallNoPackages;

  /// No description provided for @paywallLoadFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los planes. Revisa tu conexión e inténtalo de nuevo.'**
  String get paywallLoadFailed;

  /// No description provided for @paywallPurchaseFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la compra. No se te cobró nada.'**
  String get paywallPurchaseFailed;

  /// No description provided for @paywallRestoreFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos restaurar tus compras. Inténtalo de nuevo.'**
  String get paywallRestoreFailed;

  /// No description provided for @paywallConfirming.
  ///
  /// In es, this message translates to:
  /// **'Confirmando tu compra…'**
  String get paywallConfirming;

  /// No description provided for @paywallPending.
  ///
  /// In es, this message translates to:
  /// **'Tu compra se está procesando. Puede tardar unos segundos en reflejarse.'**
  String get paywallPending;

  /// No description provided for @paywallCheckAgain.
  ///
  /// In es, this message translates to:
  /// **'Verificar de nuevo'**
  String get paywallCheckAgain;

  /// No description provided for @paywallSuccessTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Listo!'**
  String get paywallSuccessTitle;

  /// No description provided for @paywallSuccessBody.
  ///
  /// In es, this message translates to:
  /// **'Tu suscripción está activa.'**
  String get paywallSuccessBody;

  /// No description provided for @paywallDevNoticeTitle.
  ///
  /// In es, this message translates to:
  /// **'Compras no configuradas'**
  String get paywallDevNoticeTitle;

  /// No description provided for @paywallDevNotice.
  ///
  /// In es, this message translates to:
  /// **'Esta compilación no tiene clave de RevenueCat (REVENUECAT_IOS_KEY / REVENUECAT_ANDROID_KEY). Configúrala con --dart-define para probar las compras.'**
  String get paywallDevNotice;

  /// No description provided for @subscriptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Suscripción'**
  String get subscriptionTitle;

  /// No description provided for @subscribeNow.
  ///
  /// In es, this message translates to:
  /// **'Ver planes'**
  String get subscribeNow;

  /// No description provided for @subscriptionNone.
  ///
  /// In es, this message translates to:
  /// **'Sin suscripción activa'**
  String get subscriptionNone;

  /// No description provided for @subscriptionActive.
  ///
  /// In es, this message translates to:
  /// **'Pro activa'**
  String get subscriptionActive;

  /// No description provided for @subscriptionCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelada'**
  String get subscriptionCancelled;

  /// No description provided for @subscriptionBillingIssue.
  ///
  /// In es, this message translates to:
  /// **'Problema de pago'**
  String get subscriptionBillingIssue;

  /// No description provided for @subscriptionExpired.
  ///
  /// In es, this message translates to:
  /// **'Vencida'**
  String get subscriptionExpired;

  /// No description provided for @subscriptionBillingIssueHint.
  ///
  /// In es, this message translates to:
  /// **'Actualiza tu método de pago en la tienda para no perder el acceso.'**
  String get subscriptionBillingIssueHint;

  /// No description provided for @restoreDone.
  ///
  /// In es, this message translates to:
  /// **'Compras restauradas'**
  String get restoreDone;

  /// No description provided for @fieldTooLong.
  ///
  /// In es, this message translates to:
  /// **'Máximo {max} caracteres'**
  String fieldTooLong(int max);

  /// No description provided for @greeting.
  ///
  /// In es, this message translates to:
  /// **'{name, select, none{Hola} other{Hola, {name}}}'**
  String greeting(String name);

  /// No description provided for @deleteCardBody.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar \"{alias}\"? También se borrará su historial de verificaciones.'**
  String deleteCardBody(String alias);

  /// No description provided for @ruleCount.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Sin reglas} =1{1 regla} other{{n} reglas}}'**
  String ruleCount(int n);

  /// No description provided for @ruleCountPlain.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 regla} other{{n} reglas}}'**
  String ruleCountPlain(int n);

  /// No description provided for @baseRateShort.
  ///
  /// In es, this message translates to:
  /// **'Base {rate}'**
  String baseRateShort(String rate);

  /// No description provided for @deleteCategoryBody.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar el rubro \"{name}\"?'**
  String deleteCategoryBody(String name);

  /// No description provided for @reassignBody.
  ///
  /// In es, this message translates to:
  /// **'Este rubro tiene {merchants} y {rules} de tarjeta. Elige a qué rubro moverlos antes de eliminarlo.'**
  String reassignBody(String merchants, String rules);

  /// No description provided for @deleteMerchantBody.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar \"{name}\"? Dejará de asignarse a su rubro.'**
  String deleteMerchantBody(String name);

  /// No description provided for @merchantCount.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 comercio} other{{n} comercios}}'**
  String merchantCount(int n);

  /// No description provided for @evidenceQuote.
  ///
  /// In es, this message translates to:
  /// **'“{text}”'**
  String evidenceQuote(String text);

  /// No description provided for @exchangeRateHelper.
  ///
  /// In es, this message translates to:
  /// **'Cuántos {primary} vale 1 unidad de la moneda extranjera. Sin él, las compras en otra moneda no cuentan para la recompensa.'**
  String exchangeRateHelper(String primary);

  /// No description provided for @exchangeRateStatement.
  ///
  /// In es, this message translates to:
  /// **'Tu estado de cuenta indica 1 {from} = {rate} {to}.'**
  String exchangeRateStatement(String from, String to, String rate);

  /// No description provided for @howManyIs.
  ///
  /// In es, this message translates to:
  /// **'¿Cuántos {primary} vale 1 {foreign}?'**
  String howManyIs(String primary, String foreign);

  /// No description provided for @rewardConversionTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu banco paga la recompensa en {reward} y tus compras están en {primary}'**
  String rewardConversionTitle(String reward, String primary);

  /// No description provided for @rewardConversionHelper.
  ///
  /// In es, this message translates to:
  /// **'Necesitamos este tipo de cambio para convertir lo que deberías haber recibido a {reward}. Es obligatorio.'**
  String rewardConversionHelper(String reward);

  /// No description provided for @foreignRateEmptyNote.
  ///
  /// In es, this message translates to:
  /// **'Sin tipo de cambio, las compras en {currency} no cuentan.'**
  String foreignRateEmptyNote(String currency);

  /// No description provided for @suggestionLines.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Sin movimientos} =1{1 movimiento} other{{n} movimientos}}'**
  String suggestionLines(int n);

  /// No description provided for @verdictUnderpaidHint.
  ///
  /// In es, this message translates to:
  /// **'El banco te debe {amount}. Puedes reclamarlo con tu estado de cuenta.'**
  String verdictUnderpaidHint(String amount);

  /// No description provided for @verdictOverpaidHint.
  ///
  /// In es, this message translates to:
  /// **'El banco te pagó {amount} de más.'**
  String verdictOverpaidHint(String amount);

  /// No description provided for @breakdownDetail.
  ///
  /// In es, this message translates to:
  /// **'{spend} en {count, plural, =1{1 movimiento} other{{count} movimientos}}'**
  String breakdownDetail(String spend, int count);

  /// No description provided for @capOf.
  ///
  /// In es, this message translates to:
  /// **'Tope {cap}'**
  String capOf(String cap);

  /// No description provided for @filterWithCount.
  ///
  /// In es, this message translates to:
  /// **'{label} ({n})'**
  String filterWithCount(String label, int n);

  /// No description provided for @transactionsSummary.
  ///
  /// In es, this message translates to:
  /// **'{counted} en rubro · {uncounted} sin rubro · {excluded} excluidos'**
  String transactionsSummary(int counted, int uncounted, int excluded);

  /// No description provided for @convertedAs.
  ///
  /// In es, this message translates to:
  /// **'≈ {amount}'**
  String convertedAs(String amount);

  /// No description provided for @excludedNoRate.
  ///
  /// In es, this message translates to:
  /// **'Compra en {currency} sin tipo de cambio'**
  String excludedNoRate(String currency);

  /// No description provided for @currencyRate.
  ///
  /// In es, this message translates to:
  /// **'1 {from} = {rate} {to}'**
  String currencyRate(String from, String to, String rate);

  /// No description provided for @currencyExcluded.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 movimiento excluido} other{{n} movimientos excluidos}}'**
  String currencyExcluded(int n);

  /// No description provided for @assignedTo.
  ///
  /// In es, this message translates to:
  /// **'Asignado a {category} · aplicará en la próxima verificación'**
  String assignedTo(String category);

  /// No description provided for @appliedRate.
  ///
  /// In es, this message translates to:
  /// **'Tasa {rate}'**
  String appliedRate(String rate);

  /// No description provided for @bankConsiders.
  ///
  /// In es, this message translates to:
  /// **'Tu banco lo considera: {hint}'**
  String bankConsiders(String hint);

  /// No description provided for @equivalentTo.
  ///
  /// In es, this message translates to:
  /// **'Equivale a {money}'**
  String equivalentTo(String money);

  /// No description provided for @rewardRateDetail.
  ///
  /// In es, this message translates to:
  /// **'1 {reward} = {rate} {primary}'**
  String rewardRateDetail(String reward, String rate, String primary);

  /// No description provided for @creditsAvailable.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 verificación disponible} other{{n} verificaciones disponibles}}'**
  String creditsAvailable(int n);

  /// No description provided for @uploadCreditNotice.
  ///
  /// In es, this message translates to:
  /// **'Esta verificación usará 1 de tus {n} disponibles.'**
  String uploadCreditNotice(int n);

  /// No description provided for @creditsBreakdown.
  ///
  /// In es, this message translates to:
  /// **'Gratis {free} · Plan {plan} · Comprados {purchased}'**
  String creditsBreakdown(int free, int plan, int purchased);

  /// No description provided for @creditsPlanExpires.
  ///
  /// In es, this message translates to:
  /// **'Las del plan vencen el {date}'**
  String creditsPlanExpires(String date);

  /// No description provided for @packTitle.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 verificación} other{{n} verificaciones}}'**
  String packTitle(int n);

  /// No description provided for @paywallFreeBanner.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{Tienes 1 verificación gratis. Úsala antes de comprar nada.} other{Tienes {n} verificaciones gratis. Úsalas antes de comprar nada.}}'**
  String paywallFreeBanner(int n);

  /// No description provided for @subscriptionRenews.
  ///
  /// In es, this message translates to:
  /// **'Se renueva el {date}'**
  String subscriptionRenews(String date);

  /// No description provided for @subscriptionEnds.
  ///
  /// In es, this message translates to:
  /// **'Activa hasta el {date}'**
  String subscriptionEnds(String date);

  /// No description provided for @stepOf.
  ///
  /// In es, this message translates to:
  /// **'Paso {step} de {total}'**
  String stepOf(int step, int total);

  /// No description provided for @assignCategory.
  ///
  /// In es, this message translates to:
  /// **'Asignar rubro'**
  String get assignCategory;

  /// No description provided for @showDetails.
  ///
  /// In es, this message translates to:
  /// **'Ver detalle'**
  String get showDetails;

  /// No description provided for @hideDetails.
  ///
  /// In es, this message translates to:
  /// **'Ocultar detalle'**
  String get hideDetails;

  /// No description provided for @splashTagline.
  ///
  /// In es, this message translates to:
  /// **'Lo que tu banco te debe'**
  String get splashTagline;

  /// No description provided for @languageAutomatic.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get languageAutomatic;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @onbLangAria.
  ///
  /// In es, this message translates to:
  /// **'Idioma: {language}. Cambiar'**
  String onbLangAria(String language);

  /// No description provided for @onbHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'Ya tengo cuenta'**
  String get onbHaveAccount;

  /// No description provided for @onbDemoTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Tu banco te pagó todo tu cashback?'**
  String get onbDemoTitle;

  /// No description provided for @onbDemoStatementSays.
  ///
  /// In es, this message translates to:
  /// **'Tu estado de cuenta dice'**
  String get onbDemoStatementSays;

  /// No description provided for @onbDemoPharmacy.
  ///
  /// In es, this message translates to:
  /// **'Farmacia Kielsa · 7%'**
  String get onbDemoPharmacy;

  /// No description provided for @onbDemoPayment.
  ///
  /// In es, this message translates to:
  /// **'Pago recibido · no cuenta'**
  String get onbDemoPayment;

  /// No description provided for @onbDemoOwed.
  ///
  /// In es, this message translates to:
  /// **'Te debían'**
  String get onbDemoOwed;

  /// No description provided for @onbDemoSub.
  ///
  /// In es, this message translates to:
  /// **'Subes el PDF, la IA lee cada compra y te decimos si te pagaron bien, de menos o de más. Vamos a configurar tu tarjeta mientras lo pruebas.'**
  String get onbDemoSub;

  /// No description provided for @onbDemoCta.
  ///
  /// In es, this message translates to:
  /// **'Hacer mi verificación gratis'**
  String get onbDemoCta;

  /// No description provided for @onbDemoFoot.
  ///
  /// In es, this message translates to:
  /// **'Unos 3 minutos · no pedimos datos de pago'**
  String get onbDemoFoot;

  /// No description provided for @onbStepBank.
  ///
  /// In es, this message translates to:
  /// **'Tu banco'**
  String get onbStepBank;

  /// No description provided for @onbStepCard.
  ///
  /// In es, this message translates to:
  /// **'Tu tarjeta'**
  String get onbStepCard;

  /// No description provided for @onbStepCategories.
  ///
  /// In es, this message translates to:
  /// **'Tus rubros'**
  String get onbStepCategories;

  /// No description provided for @onbStepAccount.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta'**
  String get onbStepAccount;

  /// No description provided for @onbStepFreeCheck.
  ///
  /// In es, this message translates to:
  /// **'Verificación gratis'**
  String get onbStepFreeCheck;

  /// No description provided for @onbStepLabel.
  ///
  /// In es, this message translates to:
  /// **'Paso {step} de {total} · {name}'**
  String onbStepLabel(int step, int total, String name);

  /// No description provided for @onbBankTitle.
  ///
  /// In es, this message translates to:
  /// **'¿De qué banco es tu tarjeta?'**
  String get onbBankTitle;

  /// No description provided for @onbBankSub.
  ///
  /// In es, this message translates to:
  /// **'Funciona con cualquier banco y país. Lo usamos para reconocer tu estado de cuenta.'**
  String get onbBankSub;

  /// No description provided for @onbBankSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar tu banco'**
  String get onbBankSearch;

  /// No description provided for @onbBankTested.
  ///
  /// In es, this message translates to:
  /// **'Probado'**
  String get onbBankTested;

  /// No description provided for @onbBankOther.
  ///
  /// In es, this message translates to:
  /// **'Otro banco'**
  String get onbBankOther;

  /// No description provided for @onbBankOtherName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de tu banco'**
  String get onbBankOtherName;

  /// No description provided for @onbCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu tarjeta {bank}'**
  String onbCardTitle(String bank);

  /// No description provided for @onbCardName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get onbCardName;

  /// No description provided for @onbCardLast4.
  ///
  /// In es, this message translates to:
  /// **'Últimos 4'**
  String get onbCardLast4;

  /// No description provided for @onbCardLast4Note.
  ///
  /// In es, this message translates to:
  /// **'Solo guardamos estos 4 dígitos.'**
  String get onbCardLast4Note;

  /// No description provided for @onbRewardKind.
  ///
  /// In es, this message translates to:
  /// **'¿Qué te da la tarjeta?'**
  String get onbRewardKind;

  /// No description provided for @onbRewardCashback.
  ///
  /// In es, this message translates to:
  /// **'Cashback'**
  String get onbRewardCashback;

  /// No description provided for @onbRewardPoints.
  ///
  /// In es, this message translates to:
  /// **'Puntos o millas'**
  String get onbRewardPoints;

  /// No description provided for @onbRewardCurrency.
  ///
  /// In es, this message translates to:
  /// **'¿En qué moneda te lo pagan?'**
  String get onbRewardCurrency;

  /// No description provided for @onbCurrencyDetect.
  ///
  /// In es, this message translates to:
  /// **'No sé, que lo detecte'**
  String get onbCurrencyDetect;

  /// No description provided for @onbRewardLabelCashback.
  ///
  /// In es, this message translates to:
  /// **'CASHBACK'**
  String get onbRewardLabelCashback;

  /// No description provided for @onbRewardLabelPoints.
  ///
  /// In es, this message translates to:
  /// **'PUNTOS'**
  String get onbRewardLabelPoints;

  /// No description provided for @onbCatsTitle.
  ///
  /// In es, this message translates to:
  /// **'¿En qué compras te da más?'**
  String get onbCatsTitle;

  /// No description provided for @onbCatsSub.
  ///
  /// In es, this message translates to:
  /// **'Marca los rubros de tu tarjeta y su porcentaje. Si no lo sabes, déjalo vacío: lo buscamos en tu estado de cuenta.'**
  String get onbCatsSub;

  /// No description provided for @onbCatSupermarkets.
  ///
  /// In es, this message translates to:
  /// **'Supermercados'**
  String get onbCatSupermarkets;

  /// No description provided for @onbCatPharmacy.
  ///
  /// In es, this message translates to:
  /// **'Farmacia'**
  String get onbCatPharmacy;

  /// No description provided for @onbCatRestaurants.
  ///
  /// In es, this message translates to:
  /// **'Restaurantes y comida rápida'**
  String get onbCatRestaurants;

  /// No description provided for @onbCatGas.
  ///
  /// In es, this message translates to:
  /// **'Gasolineras'**
  String get onbCatGas;

  /// No description provided for @onbCatDepartment.
  ///
  /// In es, this message translates to:
  /// **'Tiendas por departamento'**
  String get onbCatDepartment;

  /// No description provided for @onbCatOther.
  ///
  /// In es, this message translates to:
  /// **'Otro rubro'**
  String get onbCatOther;

  /// No description provided for @onbCatOtherName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del rubro'**
  String get onbCatOtherName;

  /// No description provided for @onbCatAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get onbCatAdd;

  /// No description provided for @onbBaseTitle.
  ///
  /// In es, this message translates to:
  /// **'Todo lo demás'**
  String get onbBaseTitle;

  /// No description provided for @onbBaseSub.
  ///
  /// In es, this message translates to:
  /// **'Lo que gana una compra fuera de estos rubros (tasa base)'**
  String get onbBaseSub;

  /// No description provided for @onbAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'Guarda lo que configuraste'**
  String get onbAccountTitle;

  /// No description provided for @onbAccountSub.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta para no perder tu tarjeta y usar tu verificación gratis.'**
  String get onbAccountSub;

  /// No description provided for @onbAccountCardSub.
  ///
  /// In es, this message translates to:
  /// **'{bank} · {unit} en {currency}'**
  String onbAccountCardSub(String bank, String unit, String currency);

  /// No description provided for @onbAccountCurrencyDetected.
  ///
  /// In es, this message translates to:
  /// **'moneda por detectar'**
  String get onbAccountCurrencyDetected;

  /// No description provided for @onbAccountPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Tu PDF se lee en memoria y nunca se guarda. De tu tarjeta solo guardamos los últimos 4 dígitos.'**
  String get onbAccountPrivacy;

  /// No description provided for @onbSyncFailed.
  ///
  /// In es, this message translates to:
  /// **'Creaste tu cuenta, pero no pudimos guardar tu configuración. Revisa tu conexión y reintenta.'**
  String get onbSyncFailed;

  /// No description provided for @onbSyncing.
  ///
  /// In es, this message translates to:
  /// **'Guardando tu configuración…'**
  String get onbSyncing;

  /// No description provided for @onbFreeCheckPill.
  ///
  /// In es, this message translates to:
  /// **'1 verificación gratis'**
  String get onbFreeCheckPill;

  /// No description provided for @onbHello.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}'**
  String onbHello(String name);

  /// No description provided for @onbPdfTitle.
  ///
  /// In es, this message translates to:
  /// **'Sube tu primer estado de cuenta'**
  String get onbPdfTitle;

  /// No description provided for @onbPdfSub.
  ///
  /// In es, this message translates to:
  /// **'Elige el PDF que te dio tu banco. Lo leemos en memoria y no lo guardamos.'**
  String get onbPdfSub;

  /// No description provided for @onbPdfPick.
  ///
  /// In es, this message translates to:
  /// **'Elegir PDF'**
  String get onbPdfPick;

  /// No description provided for @onbPdfChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar PDF'**
  String get onbPdfChange;

  /// No description provided for @onbPdfForCard.
  ///
  /// In es, this message translates to:
  /// **'Para {card}'**
  String onbPdfForCard(String card);

  /// No description provided for @onbPdfStart.
  ///
  /// In es, this message translates to:
  /// **'Analizar con mi verificación gratis'**
  String get onbPdfStart;

  /// No description provided for @onbPdfLater.
  ///
  /// In es, this message translates to:
  /// **'Ahora no, ir a mi inicio'**
  String get onbPdfLater;

  /// No description provided for @onbPdfReadingTitle.
  ///
  /// In es, this message translates to:
  /// **'Leyendo tu estado de cuenta'**
  String get onbPdfReadingTitle;

  /// No description provided for @onbFirstVerification.
  ///
  /// In es, this message translates to:
  /// **'Tu primera verificación'**
  String get onbFirstVerification;

  /// No description provided for @onbSavedSummary.
  ///
  /// In es, this message translates to:
  /// **'Quedó guardado: tu tarjeta {card}, {count, plural, =0{sin rubros} =1{1 rubro} other{{count} rubros}} y esta verificación.'**
  String onbSavedSummary(String card, int count);

  /// No description provided for @onbSeeDetail.
  ///
  /// In es, this message translates to:
  /// **'Ver el detalle'**
  String get onbSeeDetail;

  /// No description provided for @onbGoHome.
  ///
  /// In es, this message translates to:
  /// **'Ir a mi inicio'**
  String get onbGoHome;

  /// No description provided for @onbContributes.
  ///
  /// In es, this message translates to:
  /// **'{name} aporta {amount} ({count, plural, =1{1 compra} other{{count} compras}}).'**
  String onbContributes(String name, String amount, int count);

  /// No description provided for @onbVerdictStatusUnder.
  ///
  /// In es, this message translates to:
  /// **'De menos'**
  String get onbVerdictStatusUnder;

  /// No description provided for @onbVerdictStatusOver.
  ///
  /// In es, this message translates to:
  /// **'De más'**
  String get onbVerdictStatusOver;

  /// No description provided for @onbVerdictStatusMatch.
  ///
  /// In es, this message translates to:
  /// **'Bien'**
  String get onbVerdictStatusMatch;

  /// No description provided for @processingTitle.
  ///
  /// In es, this message translates to:
  /// **'Leyendo tu estado de cuenta'**
  String get processingTitle;

  /// No description provided for @processingAnalyzing.
  ///
  /// In es, this message translates to:
  /// **'Analizando con IA'**
  String get processingAnalyzing;

  /// No description provided for @processingEta.
  ///
  /// In es, this message translates to:
  /// **'unos 40 s'**
  String get processingEta;

  /// No description provided for @processingStepCard.
  ///
  /// In es, this message translates to:
  /// **'Es tu tarjeta'**
  String get processingStepCard;

  /// No description provided for @processingStepPeriod.
  ///
  /// In es, this message translates to:
  /// **'Encontrando el periodo y los movimientos'**
  String get processingStepPeriod;

  /// No description provided for @processingStepClassify.
  ///
  /// In es, this message translates to:
  /// **'Clasificando compras en tus rubros'**
  String get processingStepClassify;

  /// No description provided for @processingStepRates.
  ///
  /// In es, this message translates to:
  /// **'Revisar tus % y calcular'**
  String get processingStepRates;

  /// No description provided for @processingCardLine.
  ///
  /// In es, this message translates to:
  /// **'Verificando que sea la tarjeta elegida'**
  String get processingCardLine;

  /// No description provided for @processingCanLeave.
  ///
  /// In es, this message translates to:
  /// **'Puedes cerrar la app: seguiremos analizando y lo verás en Inicio. La verificación solo se usa si la lectura sale bien.'**
  String get processingCanLeave;

  /// No description provided for @processingLeave.
  ///
  /// In es, this message translates to:
  /// **'Ir a mi inicio'**
  String get processingLeave;

  /// No description provided for @processingDismiss.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get processingDismiss;

  /// No description provided for @pendingFailedTitle.
  ///
  /// In es, this message translates to:
  /// **'No se pudo analizar'**
  String get pendingFailedTitle;

  /// No description provided for @failureNotAStatement.
  ///
  /// In es, this message translates to:
  /// **'El archivo no parece un estado de cuenta. Tu verificación fue devuelta: elige otro PDF.'**
  String get failureNotAStatement;

  /// No description provided for @failureExtraction.
  ///
  /// In es, this message translates to:
  /// **'No pudimos leer tu estado de cuenta. Tu verificación fue devuelta: inténtalo de nuevo.'**
  String get failureExtraction;

  /// No description provided for @failureInterrupted.
  ///
  /// In es, this message translates to:
  /// **'El análisis se interrumpió. Tu verificación fue devuelta: inténtalo de nuevo.'**
  String get failureInterrupted;

  /// No description provided for @pendingProcessingTitle.
  ///
  /// In es, this message translates to:
  /// **'Analizando…'**
  String get pendingProcessingTitle;

  /// No description provided for @pendingProcessingBody.
  ///
  /// In es, this message translates to:
  /// **'{card} · puedes cerrar la app'**
  String pendingProcessingBody(String card);

  /// No description provided for @pendingAwaitingTitle.
  ///
  /// In es, this message translates to:
  /// **'Lista para confirmar'**
  String get pendingAwaitingTitle;

  /// No description provided for @pendingAwaitingBody.
  ///
  /// In es, this message translates to:
  /// **'Falta confirmar tus %'**
  String get pendingAwaitingBody;

  /// No description provided for @pendingCompletedTitle.
  ///
  /// In es, this message translates to:
  /// **'Resultado nuevo'**
  String get pendingCompletedTitle;

  /// No description provided for @pendingCompletedBody.
  ///
  /// In es, this message translates to:
  /// **'{card} · toca para verlo'**
  String pendingCompletedBody(String card);

  /// No description provided for @pendingFollow.
  ///
  /// In es, this message translates to:
  /// **'Seguir'**
  String get pendingFollow;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In es, this message translates to:
  /// **'{name, select, none{Buenos días} other{Buenos días, {name}}}'**
  String homeGreetingMorning(String name);

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In es, this message translates to:
  /// **'{name, select, none{Buenas tardes} other{Buenas tardes, {name}}}'**
  String homeGreetingAfternoon(String name);

  /// No description provided for @homeGreetingEvening.
  ///
  /// In es, this message translates to:
  /// **'{name, select, none{Buenas noches} other{Buenas noches, {name}}}'**
  String homeGreetingEvening(String name);

  /// No description provided for @homeTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu cashback'**
  String get homeTitle;

  /// No description provided for @homeProfileAria.
  ///
  /// In es, this message translates to:
  /// **'Perfil y ajustes'**
  String get homeProfileAria;

  /// No description provided for @homeFreeChecks.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 verificación gratis disponible} other{{n} verificaciones gratis disponibles}}'**
  String homeFreeChecks(int n);

  /// No description provided for @homeEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Empecemos por tu tarjeta'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyCardPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Tu tarjeta'**
  String get homeEmptyCardPlaceholder;

  /// No description provided for @homeStep1Bold.
  ///
  /// In es, this message translates to:
  /// **'Agrega tu tarjeta'**
  String get homeStep1Bold;

  /// No description provided for @homeStep1Rest.
  ///
  /// In es, this message translates to:
  /// **' con sus rubros y porcentajes.'**
  String get homeStep1Rest;

  /// No description provided for @homeStep2Bold.
  ///
  /// In es, this message translates to:
  /// **'Sube tu PDF'**
  String get homeStep2Bold;

  /// No description provided for @homeStep2Rest.
  ///
  /// In es, this message translates to:
  /// **' y en menos de un minuto sabrás si te pagaron bien.'**
  String get homeStep2Rest;

  /// No description provided for @homeAddMyCard.
  ///
  /// In es, this message translates to:
  /// **'Agregar mi tarjeta'**
  String get homeAddMyCard;

  /// No description provided for @homeNoChecksTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes verificaciones'**
  String get homeNoChecksTitle;

  /// No description provided for @homeNoChecksBody.
  ///
  /// In es, this message translates to:
  /// **'Aquí verás cada veredicto de tu banco.'**
  String get homeNoChecksBody;

  /// No description provided for @homeGuidedSetup.
  ///
  /// In es, this message translates to:
  /// **'Prefiero la configuración guiada'**
  String get homeGuidedSetup;

  /// No description provided for @homeFreshBanner.
  ///
  /// In es, this message translates to:
  /// **'{name, select, none{Listo. Aquí está todo lo que configuraste: tu tarjeta, sus rubros y tu primera verificación.} other{Listo, {name}. Aquí está todo lo que configuraste: tu tarjeta, sus rubros y tu primera verificación.}}'**
  String homeFreshBanner(String name);

  /// No description provided for @homeVerifyStatement.
  ///
  /// In es, this message translates to:
  /// **'Verificar estado de cuenta'**
  String get homeVerifyStatement;

  /// No description provided for @homeUsedFree.
  ///
  /// In es, this message translates to:
  /// **'Usaste tu verificación gratis'**
  String get homeUsedFree;

  /// No description provided for @homeGetMore.
  ///
  /// In es, this message translates to:
  /// **'Obtener más'**
  String get homeGetMore;

  /// No description provided for @homeChecksAvailable.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 verificación disponible} other{{n} verificaciones disponibles}}'**
  String homeChecksAvailable(int n);

  /// No description provided for @homeMyCard.
  ///
  /// In es, this message translates to:
  /// **'Mi tarjeta'**
  String get homeMyCard;

  /// No description provided for @homeMyCards.
  ///
  /// In es, this message translates to:
  /// **'Mis tarjetas'**
  String get homeMyCards;

  /// No description provided for @homeTapToEdit.
  ///
  /// In es, this message translates to:
  /// **'Toca para editar'**
  String get homeTapToEdit;

  /// No description provided for @homeAddAnotherCard.
  ///
  /// In es, this message translates to:
  /// **'Agregar otra tarjeta'**
  String get homeAddAnotherCard;

  /// No description provided for @homeAddCardTile.
  ///
  /// In es, this message translates to:
  /// **'Agregar tarjeta'**
  String get homeAddCardTile;

  /// No description provided for @homeCardMeta.
  ///
  /// In es, this message translates to:
  /// **'{bank} · base {rate} · {rules}'**
  String homeCardMeta(String bank, String rate, String rules);

  /// No description provided for @homeEverythingElse.
  ///
  /// In es, this message translates to:
  /// **'Todo lo demás {rate}'**
  String homeEverythingElse(String rate);

  /// No description provided for @homeFirstVerification.
  ///
  /// In es, this message translates to:
  /// **'Tu primera verificación'**
  String get homeFirstVerification;

  /// No description provided for @homeUncategorized.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 compra quedó sin rubro} other{{n} compras quedaron sin rubro}} · revísalas gratis'**
  String homeUncategorized(int n);

  /// No description provided for @homeLatestChecks.
  ///
  /// In es, this message translates to:
  /// **'Últimas verificaciones'**
  String get homeLatestChecks;

  /// No description provided for @homeSeeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todas'**
  String get homeSeeAll;

  /// No description provided for @homeOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Mostrando datos guardados.'**
  String get homeOffline;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get navHistory;

  /// No description provided for @navCategories.
  ///
  /// In es, this message translates to:
  /// **'Rubros'**
  String get navCategories;

  /// No description provided for @navProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @navAria.
  ///
  /// In es, this message translates to:
  /// **'Navegación principal'**
  String get navAria;

  /// No description provided for @cardBasicCaption.
  ///
  /// In es, this message translates to:
  /// **'Básico'**
  String get cardBasicCaption;

  /// No description provided for @cardNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la tarjeta'**
  String get cardNameLabel;

  /// No description provided for @cardLast4Short.
  ///
  /// In es, this message translates to:
  /// **'Últimos 4'**
  String get cardLast4Short;

  /// No description provided for @cardRewardKindQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Qué te da?'**
  String get cardRewardKindQuestion;

  /// No description provided for @cardUnitCashback.
  ///
  /// In es, this message translates to:
  /// **'Cashback en dinero'**
  String get cardUnitCashback;

  /// No description provided for @cardUnitPoints.
  ///
  /// In es, this message translates to:
  /// **'Puntos o millas'**
  String get cardUnitPoints;

  /// No description provided for @cardBaseRateLabel.
  ///
  /// In es, this message translates to:
  /// **'Tasa base'**
  String get cardBaseRateLabel;

  /// No description provided for @cardBaseRateHelp.
  ///
  /// In es, this message translates to:
  /// **'Lo que gana cualquier compra que no está en un rubro especial.'**
  String get cardBaseRateHelp;

  /// No description provided for @cardRulesTitle.
  ///
  /// In es, this message translates to:
  /// **'Rubros con % especial'**
  String get cardRulesTitle;

  /// No description provided for @cardAddRule.
  ///
  /// In es, this message translates to:
  /// **'+ Agregar rubro'**
  String get cardAddRule;

  /// No description provided for @cardAddCap.
  ///
  /// In es, this message translates to:
  /// **'+ Tope mensual'**
  String get cardAddCap;

  /// No description provided for @cardAdvancedTitle.
  ///
  /// In es, this message translates to:
  /// **'Opciones avanzadas'**
  String get cardAdvancedTitle;

  /// No description provided for @cardAdvancedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Red, moneda, programa a auditar…'**
  String get cardAdvancedSubtitle;

  /// No description provided for @cardNetworkLabel.
  ///
  /// In es, this message translates to:
  /// **'Red'**
  String get cardNetworkLabel;

  /// No description provided for @cardOptionalTag.
  ///
  /// In es, this message translates to:
  /// **'(opcional)'**
  String get cardOptionalTag;

  /// No description provided for @cardNetworkOther.
  ///
  /// In es, this message translates to:
  /// **'Otra'**
  String get cardNetworkOther;

  /// No description provided for @cardNetworkOtherHint.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la red'**
  String get cardNetworkOtherHint;

  /// No description provided for @cardMainCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda principal de la tarjeta'**
  String get cardMainCurrency;

  /// No description provided for @cardProgramLabel.
  ///
  /// In es, this message translates to:
  /// **'Programa a auditar'**
  String get cardProgramLabel;

  /// No description provided for @cardProgramHelp.
  ///
  /// In es, this message translates to:
  /// **'Si tu estado de cuenta trae varios programas (cash, puntos, millas), elige cuál revisamos.'**
  String get cardProgramHelp;

  /// No description provided for @cardRewardCurrencyQuestion.
  ///
  /// In es, this message translates to:
  /// **'Moneda en que recibes el cashback'**
  String get cardRewardCurrencyQuestion;

  /// No description provided for @cardRewardDetect.
  ///
  /// In es, this message translates to:
  /// **'Detectar sola'**
  String get cardRewardDetect;

  /// No description provided for @cardRewardCurrencyNote.
  ///
  /// In es, this message translates to:
  /// **'Si es distinta a la de tus compras, te pediremos el tipo de cambio al verificar.'**
  String get cardRewardCurrencyNote;

  /// No description provided for @cardCurrencyOtherHint.
  ///
  /// In es, this message translates to:
  /// **'Otro código (3 letras)'**
  String get cardCurrencyOtherHint;

  /// No description provided for @cardDeleteAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar tarjeta'**
  String get cardDeleteAction;

  /// No description provided for @cardDeleteNote.
  ///
  /// In es, this message translates to:
  /// **'También se elimina su historial de verificaciones.'**
  String get cardDeleteNote;

  /// No description provided for @cardClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get cardClose;

  /// No description provided for @catalogNewCategory.
  ///
  /// In es, this message translates to:
  /// **'+ Nuevo rubro'**
  String get catalogNewCategory;

  /// No description provided for @catalogIntroTitle.
  ///
  /// In es, this message translates to:
  /// **'Los rubros son los tipos de compra que tu banco premia más'**
  String get catalogIntroTitle;

  /// No description provided for @catalogIntroBody.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo, 7% en supermercados. Créalos una vez y los usamos en todas tus tarjetas. No necesitas registrar comercios: la IA reconoce que «Farmacia Kielsa 61» es una farmacia.'**
  String get catalogIntroBody;

  /// No description provided for @catalogQuickAdd.
  ///
  /// In es, this message translates to:
  /// **'Agrega con un toque'**
  String get catalogQuickAdd;

  /// No description provided for @catalogCreateOther.
  ///
  /// In es, this message translates to:
  /// **'Crear otro rubro'**
  String get catalogCreateOther;

  /// No description provided for @catalogOptionalNote.
  ///
  /// In es, this message translates to:
  /// **'Registrar comercios es opcional; sirve para que una compra siempre caiga en el rubro correcto.'**
  String get catalogOptionalNote;

  /// No description provided for @catalogByAi.
  ///
  /// In es, this message translates to:
  /// **'Por IA'**
  String get catalogByAi;

  /// No description provided for @catalogAddMerchant.
  ///
  /// In es, this message translates to:
  /// **'+ Agregar comercio'**
  String get catalogAddMerchant;

  /// No description provided for @catalogMore.
  ///
  /// In es, this message translates to:
  /// **'Más acciones'**
  String get catalogMore;

  /// No description provided for @catalogRuleTag.
  ///
  /// In es, this message translates to:
  /// **'{card} {rate}'**
  String catalogRuleTag(String card, String rate);

  /// No description provided for @verifyStepCard.
  ///
  /// In es, this message translates to:
  /// **'1 · ¿De qué tarjeta es?'**
  String get verifyStepCard;

  /// No description provided for @verifyStepFile.
  ///
  /// In es, this message translates to:
  /// **'2 · El PDF del banco'**
  String get verifyStepFile;

  /// No description provided for @verifyPickHint.
  ///
  /// In es, this message translates to:
  /// **'El original que descargas de la banca en línea. Se lee en memoria y no se guarda.'**
  String get verifyPickHint;

  /// No description provided for @verifyCardCashback.
  ///
  /// In es, this message translates to:
  /// **'Cashback en {currency} · {rules}'**
  String verifyCardCashback(String currency, String rules);

  /// No description provided for @verifyCardPoints.
  ///
  /// In es, this message translates to:
  /// **'Puntos · {rules}'**
  String verifyCardPoints(String rules);

  /// No description provided for @verifyAvailablePill.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 disponible} other{{n} disponibles}}'**
  String verifyAvailablePill(int n);

  /// No description provided for @verifyNoneLeftPill.
  ///
  /// In es, this message translates to:
  /// **'Sin verificaciones'**
  String get verifyNoneLeftPill;

  /// No description provided for @verifyCreditNote.
  ///
  /// In es, this message translates to:
  /// **'Se usa una verificación solo si la lectura sale bien. Recalcular es gratis.'**
  String get verifyCreditNote;

  /// No description provided for @verifyCta.
  ///
  /// In es, this message translates to:
  /// **'Analizar'**
  String get verifyCta;

  /// No description provided for @verifyCtaPickFile.
  ///
  /// In es, this message translates to:
  /// **'Analizar · elige un PDF'**
  String get verifyCtaPickFile;

  /// No description provided for @verifyCtaPickCard.
  ///
  /// In es, this message translates to:
  /// **'Analizar · elige una tarjeta'**
  String get verifyCtaPickCard;

  /// No description provided for @verifyClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get verifyClose;

  /// No description provided for @processingBackground.
  ///
  /// In es, this message translates to:
  /// **'Seguir en segundo plano'**
  String get processingBackground;

  /// No description provided for @processingFileBadge.
  ///
  /// In es, this message translates to:
  /// **'PDF'**
  String get processingFileBadge;

  /// No description provided for @processingUploadingEta.
  ///
  /// In es, this message translates to:
  /// **'subiendo…'**
  String get processingUploadingEta;

  /// No description provided for @failureRefundedPill.
  ///
  /// In es, this message translates to:
  /// **'Verificación devuelta'**
  String get failureRefundedPill;

  /// No description provided for @failureRetry.
  ///
  /// In es, this message translates to:
  /// **'Intentar de nuevo'**
  String get failureRetry;

  /// No description provided for @failureChooseAnother.
  ///
  /// In es, this message translates to:
  /// **'Elegir otro PDF'**
  String get failureChooseAnother;

  /// No description provided for @failureTitleNotAStatement.
  ///
  /// In es, this message translates to:
  /// **'No parece un estado de cuenta'**
  String get failureTitleNotAStatement;

  /// No description provided for @failureTitleExtraction.
  ///
  /// In es, this message translates to:
  /// **'No pudimos leerlo'**
  String get failureTitleExtraction;

  /// No description provided for @failureTitleInterrupted.
  ///
  /// In es, this message translates to:
  /// **'Se interrumpió el análisis'**
  String get failureTitleInterrupted;

  /// No description provided for @errVerificationNotReady.
  ///
  /// In es, this message translates to:
  /// **'Tu estado de cuenta todavía se está analizando. Espera a que termine.'**
  String get errVerificationNotReady;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
