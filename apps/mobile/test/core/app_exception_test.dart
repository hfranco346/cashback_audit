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

  test('402 means subscription required', () {
    final e = AppException.fromDio(
      _bad(402, {'statusCode': 402, 'code': 'SUBSCRIPTION_REQUIRED'}),
    );
    expect(e.isSubscriptionRequired, isTrue);
    expect(userMessageFor(e), S.errSubscription);
  });

  test('network and timeout errors', () {
    final req = RequestOptions(path: '/x');
    expect(
      AppException.fromDio(
        DioException(requestOptions: req, type: DioExceptionType.connectionError),
      ).kind,
      AppErrorKind.network,
    );
    expect(
      AppException.fromDio(
        DioException(requestOptions: req, type: DioExceptionType.receiveTimeout),
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
