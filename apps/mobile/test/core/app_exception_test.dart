import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/errors/error_messages.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _bad(int status, [Object? body]) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: status, data: body),
  );
}

void main() {
  test('maps the API error body', () {
    final e = AppException.fromDio(
      _bad(409, {
        'statusCode': 409,
        'code': 'CATEGORY_IN_USE',
        'message': 'x',
        'details': {'merchants': 2, 'cardRules': 1},
      }),
    );
    expect(e.kind, AppErrorKind.conflict);
    expect(e.code, 'CATEGORY_IN_USE');
    expect((e.details as Map)['merchants'], 2);
    expect(userMessageFor(e), S.errCategoryInUse);
  });

  test('402 NO_CREDITS means the user has no credits left', () {
    final e = AppException.fromDio(
      _bad(402, {'statusCode': 402, 'code': 'NO_CREDITS'}),
    );
    expect(e.isNoCredits, isTrue);
    expect(userMessageFor(e), S.errNoCredits);
  });

  test('new verification error codes map to Spanish copy', () {
    String msg(String code, int status) => userMessageFor(
      AppException.fromDio(_bad(status, {'statusCode': status, 'code': code})),
    );
    expect(msg('RATES_REQUIRED', 422), S.errRatesRequired);
    expect(msg('REWARD_PROGRAM_AMBIGUOUS', 422), S.errProgramAmbiguous);
    expect(msg('REPORTED_REWARD_NOT_FOUND', 422), S.errRewardNotFound);
    expect(msg('TRANSACTION_NOT_FOUND', 404), S.errTransactionNotFound);
    expect(
      msg('TRANSACTION_NOT_CLASSIFIABLE', 422),
      S.errTransactionNotClassifiable,
    );
  });

  test('network and timeout errors', () {
    final req = RequestOptions(path: '/x');
    expect(
      AppException.fromDio(
        DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
        ),
      ).kind,
      AppErrorKind.network,
    );
    expect(
      AppException.fromDio(
        DioException(
          requestOptions: req,
          type: DioExceptionType.receiveTimeout,
        ),
      ).kind,
      AppErrorKind.timeout,
    );
  });

  test('falls back on status when the body is not an API error', () {
    expect(AppException.fromDio(_bad(503, 'oops')).kind, AppErrorKind.server);
    expect(userMessageFor(Object()), S.errUnknown);
  });

  test('guardApi converts DioException', () async {
    await expectLater(
      guardApi<void>(() => throw _bad(404, {'code': 'CARD_NOT_FOUND'})),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'CARD_NOT_FOUND'),
      ),
    );
  });
}
