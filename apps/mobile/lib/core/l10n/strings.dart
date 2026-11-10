import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_es.dart';

/// Compatibility layer over the generated [AppLocalizations].
///
/// Legacy screens still read copy through `S.xxx`. New code must use
/// `context.l10n` instead (see `L10nContext`). [S.current] follows the active
/// locale: `LocaleController` and the app `builder` keep it in sync.
abstract final class S {
  static AppLocalizations current = AppLocalizationsEs();

  /// Points [current] at the localizations resolved for [context].
  static void bind(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (l != null) current = l;
  }

  static AppLocalizations get _l => current;

  static String get retry => _l.retry;
  static String get delete => _l.delete;
  static String get offlineBanner => _l.offlineBanner;
  static String get errNetwork => _l.errNetwork;
  static String get errTimeout => _l.errTimeout;
  static String get errUnauthorized => _l.errUnauthorized;
  static String get errNoCredits => _l.errNoCredits;
  static String get errRatesRequired => _l.errRatesRequired;
  static String get errProgramAmbiguous => _l.errProgramAmbiguous;
  static String get errTransactionNotFound => _l.errTransactionNotFound;
  static String get errTransactionNotClassifiable =>
      _l.errTransactionNotClassifiable;
  static String get errVerificationNotFound => _l.errVerificationNotFound;
  static String get errValidation => _l.errValidation;
  static String get errNotFound => _l.errNotFound;
  static String get errConflict => _l.errConflict;
  static String get errVerificationNotReady => _l.errVerificationNotReady;
  static String get errTooLarge => _l.errTooLarge;
  static String get errNotPdf => _l.errNotPdf;
  static String get errRateLimited => _l.errRateLimited;
  static String get errServer => _l.errServer;
  static String get errUnknown => _l.errUnknown;
  static String get errCategoryNameTaken => _l.errCategoryNameTaken;
  static String get errMerchantNameTaken => _l.errMerchantNameTaken;
  static String get errCategoryInUse => _l.errCategoryInUse;
  static String get errInvalidPdf => _l.errInvalidPdf;
  static String get errUnreadable => _l.errUnreadable;
  static String get errRewardRateRequired => _l.errRewardRateRequired;
  static String get errNotAStatement => _l.errNotAStatement;
  static String get errProgramNotFound => _l.errProgramNotFound;
  static String get errPreviousBalanceRequired => _l.errPreviousBalanceRequired;
  static String get reportingPreviousLabel => _l.reportingPreviousLabel;
  static String get errInvalidExchangeRate => _l.errInvalidExchangeRate;
  static String get errInvalidCurrencies => _l.errInvalidCurrencies;
  static String get errRewardNotFound => _l.errRewardNotFound;
  static String get errExtractionFailed => _l.errExtractionFailed;
  static String get errExtractionUnavailable => _l.errExtractionUnavailable;
  static String get errIdentityToken => _l.errIdentityToken;
  static String get errIdentityUnavailable => _l.errIdentityUnavailable;
  static String get sessionExpiredTitle => _l.sessionExpiredTitle;
  static String get loginTitle => _l.loginTitle;
  static String get signInGoogle => _l.signInGoogle;
  static String get signInApple => _l.signInApple;
  static String get fieldRequired => _l.fieldRequired;
  static String get last4Invalid => _l.last4Invalid;
  static String get currencyInvalid => _l.currencyInvalid;
  static String get numberInvalid => _l.numberInvalid;
  static String get percentRange => _l.percentRange;
  static String get capInvalid => _l.capInvalid;
  static String get pointsFactorInvalid => _l.pointsFactorInvalid;
  static String get newCard => _l.newCard;
  static String get editCard => _l.editCard;
  static String get ruleCategoryRequired => _l.ruleCategoryRequired;
  static String get ruleDuplicateCategory => _l.ruleDuplicateCategory;
  static String get noMerchants => _l.noMerchants;
  static String get themeSystem => _l.themeSystem;
  static String get themeLight => _l.themeLight;
  static String get themeDark => _l.themeDark;
  static String get fileTooLarge => _l.fileTooLarge;
  static String get fileNotPdf => _l.fileNotPdf;
  static String get uploadTimeout => _l.uploadTimeout;
  static String get overrideInvalid => _l.overrideInvalid;
  static String get rateBaseTitle => _l.rateBaseTitle;
  static String get rateRequiredError => _l.rateRequiredError;
  static String get exchangeRateInvalid => _l.exchangeRateInvalid;
  static String get rewardRateRequiredError => _l.rewardRateRequiredError;
  static String get categoryChanged => _l.categoryChanged;
  static String get recalcFailedAfterChange => _l.recalcFailedAfterChange;
  static String get recalcNeedsRate => _l.recalcNeedsRate;
  static String get uploadNoCredits => _l.uploadNoCredits;
  static String get creditsHistoryEmptyTitle => _l.creditsHistoryEmptyTitle;
  static String get paywallSubscriptionTitle => _l.paywallSubscriptionTitle;
  static String get paywallSubscriptionPerks => _l.paywallSubscriptionPerks;
  static String get paywallBuy => _l.paywallBuy;
  static String get paywallSuccessPack => _l.paywallSuccessPack;
  static String get restoreNothing => _l.restoreNothing;
  static String get paywallSubscribe => _l.paywallSubscribe;
  static String get paywallNoPackages => _l.paywallNoPackages;
  static String get paywallLoadFailed => _l.paywallLoadFailed;
  static String get paywallPurchaseFailed => _l.paywallPurchaseFailed;
  static String get paywallRestoreFailed => _l.paywallRestoreFailed;
  static String get paywallCheckAgain => _l.paywallCheckAgain;
  static String get paywallSuccessTitle => _l.paywallSuccessTitle;
  static String get paywallSuccessBody => _l.paywallSuccessBody;
  static String get paywallDevNotice => _l.paywallDevNotice;
  static String get restoreDone => _l.restoreDone;
  static String fieldTooLong(int max) => _l.fieldTooLong(max);
  static String packTitle(int n) => _l.packTitle(n);
  static String paywallFreeBanner(int n) => _l.paywallFreeBanner(n);
}
