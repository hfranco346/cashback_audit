import 'package:fake_async/fake_async.dart';
import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/attention_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/verification_poller.dart';
import 'package:cashback_audit/features/verifications/presentation/verification_progress_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';

Map<String, dynamic> _processing() => {
  ...verificationJson(),
  'status': 'PROCESSING',
};

void main() {
  group('VerificationPoller', () {
    test('polls every interval until the status leaves PROCESSING', () {
      fakeAsync((async) {
        final repo = FakeVerificationRepository()
          ..getResults.addAll([
            _processing(),
            _processing(),
            awaitingVerificationJson(),
          ]);
        final poller = VerificationPoller(repository: repo);
        final seen = <VerificationStatus>[];
        poller.start('v1', onUpdate: (v) => seen.add(v.status));
        async.elapse(const Duration(seconds: 3));
        expect(repo.getCalls, 0);
        async.elapse(const Duration(seconds: 1));
        expect(repo.getCalls, 1);
        async.elapse(const Duration(seconds: 8));
        expect(seen, [
          VerificationStatus.processing,
          VerificationStatus.processing,
          VerificationStatus.awaitingRates,
        ]);
        // Terminal status: nothing else is scheduled.
        async.elapse(const Duration(seconds: 30));
        expect(repo.getCalls, 3);
        expect(poller.isRunning, isFalse);
      });
    });

    test('stop cancels the schedule', () {
      fakeAsync((async) {
        final repo = FakeVerificationRepository()
          ..getResults.add(_processing());
        final poller = VerificationPoller(repository: repo)
          ..start('v1', onUpdate: (_) {});
        async.elapse(const Duration(seconds: 4));
        expect(repo.getCalls, 1);
        poller.stop();
        async.elapse(const Duration(seconds: 40));
        expect(repo.getCalls, 1);
      });
    });

    test('transient errors keep polling, fatal ones stop it', () {
      fakeAsync((async) {
        final repo = FakeVerificationRepository()
          ..getResults.addAll([
            const AppException(kind: AppErrorKind.network),
            _processing(),
            const AppException(kind: AppErrorKind.notFound),
          ]);
        final flags = <bool>[];
        final poller = VerificationPoller(repository: repo)
          ..start(
            'v1',
            onUpdate: (_) {},
            onError: (e, {required fatal}) => flags.add(fatal),
          );
        async.elapse(const Duration(seconds: 20));
        expect(repo.getCalls, 3);
        expect(flags, [false, true]);
        expect(poller.isRunning, isFalse);
      });
    });
  });

  group('AttentionController', () {
    late FakeVerificationRepository repo;
    late FakeNavigator nav;
    late AttentionController c;
    setUp(() {
      repo = FakeVerificationRepository();
      nav = FakeNavigator();
      c = AttentionController(repository: repo, navigator: nav);
    });

    VerificationSummary item(String id, String status, {String? code}) =>
        VerificationMapper.summary({
          ...summaryJson(id),
          'status': status,
          'failureCode': code,
        });

    test('reload fills the list and keeps it when the refresh fails', () async {
      repo.attentionItems = [item('a', 'PROCESSING')];
      await c.reload();
      expect(c.items.map((e) => e.id), ['a']);
      repo.attentionError = const AppException(kind: AppErrorKind.network);
      await c.reload();
      expect(c.items, hasLength(1));
      expect(c.failed.value, isTrue);
    });

    test('markSeen removes the row and calls the backend', () async {
      repo.attentionItems = [item('a', 'COMPLETED')];
      await c.reload();
      await c.markSeen('a');
      expect(c.items, isEmpty);
      expect(repo.seen, ['a']);
    });

    test('open routes by status and marks finished results as seen', () async {
      await c.open(item('p', 'PROCESSING'));
      expect(nav.pushed.last, '/verification-progress');
      expect(nav.pushedArgs.last, 'p');

      await c.open(item('r', 'AWAITING_RATES'));
      expect(nav.pushed.last, '/confirm-rates');
      expect((nav.pushedArgs.last as ConfirmRatesArgs).verificationId, 'r');
      expect(repo.seen, isEmpty);

      await c.open(item('c', 'COMPLETED'));
      expect(nav.pushed.last, '/result');
      expect(repo.seen, ['c']);

      VerificationSummary? explained;
      await c.open(
        item('f', 'FAILED', code: 'NOT_A_STATEMENT'),
        showFailure: (i) async => explained = i,
      );
      expect(explained?.failureCode, FailureCode.notAStatement);
      expect(repo.seen, ['c', 'f']);
    });
  });

  group('VerificationProgressController', () {
    test('goes to the rates screen when the analysis is ready', () {
      fakeAsync((async) {
        final repo = FakeVerificationRepository()
          ..getResults.addAll([_processing(), awaitingVerificationJson()]);
        final nav = FakeNavigator();
        final c = VerificationProgressController(
          verificationId: 'v1',
          repository: repo,
          navigator: nav,
        )..onReady();
        async.flushMicrotasks();
        expect(nav.replaced, isEmpty);
        async.elapse(const Duration(seconds: 4));
        expect(nav.replaced, ['/confirm-rates']);
        expect(
          (nav.replacedArgs.single as ConfirmRatesArgs).verification?.id,
          'v1',
        );
        c.onClose();
      });
    });

    test('leaving stops the polling and the backend keeps the job', () {
      fakeAsync((async) {
        final repo = FakeVerificationRepository()
          ..getResults.add(_processing());
        final nav = FakeNavigator();
        final c = VerificationProgressController(
          verificationId: 'v1',
          repository: repo,
          navigator: nav,
        )..onReady();
        async.elapse(const Duration(seconds: 9));
        final calls = repo.getCalls;
        expect(calls, greaterThan(1));
        c.leave();
        async.elapse(const Duration(seconds: 60));
        expect(repo.getCalls, calls);
        expect(nav.pops, 1);
      });
    });

    test('a failed analysis stays on screen and polling stops', () {
      fakeAsync((async) {
        final repo = FakeVerificationRepository()
          ..getResults.add({
            ...verificationJson(),
            'status': 'FAILED',
            'failureCode': 'EXTRACTION_FAILED',
          });
        final nav = FakeNavigator();
        final c = VerificationProgressController(
          verificationId: 'v1',
          repository: repo,
          navigator: nav,
        )..onReady();
        async.flushMicrotasks();
        expect(c.verification.value?.failureCode, FailureCode.extractionFailed);
        async.elapse(const Duration(seconds: 30));
        expect(repo.getCalls, 1);
        expect(nav.replaced, isEmpty);
      });
    });
  });
}
