import '../l10n/strings.dart';
import 'app_exception.dart';

/// Maps an [AppException] to a user-friendly Spanish message. API `code`
/// wins over the coarse `kind`; the server's English `message` is never shown.
String userMessageFor(Object error) {
  if (error is! AppException) return S.errUnknown;
  switch (error.code) {
    case 'CATEGORY_NAME_TAKEN':
      return S.errCategoryNameTaken;
    case 'MERCHANT_NAME_TAKEN':
      return S.errMerchantNameTaken;
    case 'CATEGORY_IN_USE':
      return S.errCategoryInUse;
    case 'INVALID_PDF':
      return S.errInvalidPdf;
    case 'UNREADABLE_STATEMENT':
      return S.errUnreadable;
    case 'REPORTED_REWARD_NOT_FOUND':
      return S.errRewardNotFound;
    case 'EXTRACTION_FAILED':
      return S.errExtractionFailed;
    case 'EXTRACTION_UNAVAILABLE':
      return S.errExtractionUnavailable;
    case 'INVALID_IDENTITY_TOKEN':
      return S.errIdentityToken;
    case 'IDENTITY_PROVIDER_UNAVAILABLE':
      return S.errIdentityUnavailable;
    case 'NO_CREDITS':
      return S.errNoCredits;
    case 'RATES_REQUIRED':
      return S.errRatesRequired;
    case 'REWARD_PROGRAM_AMBIGUOUS':
      return S.errProgramAmbiguous;
    case 'REWARD_EXCHANGE_RATE_REQUIRED':
      return S.errRewardRateRequired;
    case 'INVALID_EXCHANGE_RATE':
      return S.errInvalidExchangeRate;
    case 'TRANSACTION_NOT_FOUND':
      return S.errTransactionNotFound;
    case 'TRANSACTION_NOT_CLASSIFIABLE':
      return S.errTransactionNotClassifiable;
    case 'VERIFICATION_NOT_READY':
      return S.errVerificationNotReady;
    case 'VERIFICATION_NOT_FOUND':
      return S.errVerificationNotFound;
    case 'DUPLICATE_RULE_CATEGORY':
      return S.errValidation;
  }
  return switch (error.kind) {
    AppErrorKind.network => S.errNetwork,
    AppErrorKind.timeout => S.errTimeout,
    AppErrorKind.unauthorized => S.errUnauthorized,
    AppErrorKind.noCredits => S.errNoCredits,
    AppErrorKind.validation => S.errValidation,
    AppErrorKind.notFound => S.errNotFound,
    AppErrorKind.conflict => S.errConflict,
    AppErrorKind.payloadTooLarge => S.errTooLarge,
    AppErrorKind.unsupportedMedia => S.errNotPdf,
    AppErrorKind.unprocessable => S.errUnreadable,
    AppErrorKind.rateLimited => S.errRateLimited,
    AppErrorKind.server => S.errServer,
    AppErrorKind.cancelled => S.errUnknown,
    AppErrorKind.unknown => S.errUnknown,
  };
}
