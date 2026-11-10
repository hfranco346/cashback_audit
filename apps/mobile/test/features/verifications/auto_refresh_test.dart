import 'dart:async';

import 'package:cashback_audit/core/routing/app_routes.dart';
import 'package:cashback_audit/core/routing/home_return_notifier.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/domain/verification_events.dart';
import 'package:cashback_audit/features/verifications/presentation/auto_refresh.dart';
import 'package:cashback_audit/features/verifications/presentation/history_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import '../../support/lifecycle.dart';

const _five = Duration(seconds: 5);

VerificationSummary _s(String id, String status) => VerificationMapper.summary({
  ...summaryJson(id),
  'status': status,
  if (status != 'COMPLETED') 'verdict': null,
});

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => setAppLifecycle(binding, AppLifecycleState.resumed));

  group('AutoRefresh', () {
    late int refreshes;
    late int polls;
    late bool pending;
    late VerificationEvents events;
    late RxInt tab;

    AutoRefresh make({
      Future<void> Function()? refresh,
      bool Function()? onTop,
      int tabIndex = 0,
    }) => AutoRefresh(
      refresh: refresh ?? () async => refreshes++,
      poll: () async => polls++,
      hasPending: () => pending,
      events: events,
      tab: tab,
      tabIndex: tabIndex,
      isRouteOnTop: onTop,
    );

    setUp(() {
      refreshes = 0;
      polls = 0;
      pending = true;
      events = VerificationEvents();
      tab = 0.obs;
    });

    test('polls every 5 s while something is processing, then stops', () {
      fakeAsync((async) {
        final a = make()..start();
        a.sync();
        expect(a.polling, isTrue);
        async.elapse(_five * 3);
        expect(polls, 3);
        pending = false;
        async.elapse(_five); // the next tick sees nothing pending
        expect(polls, 3);
        expect(a.polling, isFalse);
        async.elapse(_five * 4);
        expect(polls, 3);
        a.dispose();
      });
    });

    test('does not poll when nothing is processing', () {
      fakeAsync((async) {
        pending = false;
        final a = make()..start();
        a.sync();
        expect(a.polling, isFalse);
        async.elapse(_five * 3);
        expect(polls, 0);
        a.dispose();
      });
    });

    test('stops when the tab is not visible and resumes when shown', () {
      fakeAsync((async) {
        final a = make()..start();
        a.sync();
        async.elapse(_five);
        expect(polls, 1);
        tab.value = 1; // another tab
        async.flushMicrotasks();
        expect(a.polling, isFalse);
        async.elapse(_five * 3);
        expect(polls, 1);
        tab.value = 0; // back: refreshes right away and polls again
        async.flushMicrotasks();
        expect(refreshes, 1);
        expect(a.polling, isTrue);
        async.elapse(_five);
        expect(polls, 2);
        a.dispose();
      });
    });

    test('stops while another route covers the screen', () {
      fakeAsync((async) {
        var onTop = true;
        final a = make(onTop: () => onTop)..start();
        a.sync();
        async.elapse(_five);
        expect(polls, 1);
        onTop = false;
        async.elapse(_five);
        expect(polls, 1);
        expect(a.polling, isFalse);
        a.dispose();
      });
    });

    test(
      'stops when the app goes to the background and refreshes on resume',
      () {
        fakeAsync((async) {
          final a = make()..start();
          a.sync();
          async.elapse(_five);
          expect(polls, 1);
          setAppLifecycle(binding, AppLifecycleState.paused);
          expect(a.polling, isFalse);
          async.elapse(_five * 4);
          expect(polls, 1);
          setAppLifecycle(binding, AppLifecycleState.resumed);
          async.flushMicrotasks();
          expect(refreshes, 1);
          expect(a.polling, isTrue);
          async.elapse(_five);
          expect(polls, 2);
          a.dispose();
        });
      },
    );

    test('a change event refreshes right away', () {
      fakeAsync((async) {
        final a = make()..start();
        events.notify();
        async.flushMicrotasks();
        expect(refreshes, 1);
        events.notify();
        async.flushMicrotasks();
        expect(refreshes, 2);
        a.dispose();
        events.notify();
        async.flushMicrotasks();
        expect(refreshes, 2); // disposed: no longer listening
      });
    });

    test('requests never overlap and a change during one is not lost', () {
      fakeAsync((async) {
        final gate = Completer<void>();
        var running = 0;
        var maxRunning = 0;
        var calls = 0;
        final a = make(
          refresh: () async {
            calls++;
            running++;
            if (running > maxRunning) maxRunning = running;
            if (calls == 1) await gate.future;
            running--;
          },
        )..start();
        a.sync();
        events.notify();
        async.flushMicrotasks();
        expect(calls, 1);
        // Ticks and more events while the request is still running.
        async.elapse(_five * 2);
        events.notify();
        async.flushMicrotasks();
        expect(polls, 0); // poll skipped: a refresh is in flight
        expect(calls, 1);
        gate.complete();
        async.flushMicrotasks();
        expect(calls, 2); // the pending change ran once, after the first
        expect(maxRunning, 1);
        a.dispose();
      });
    });

    test('a failing refresh keeps the timer alive', () {
      fakeAsync((async) {
        var calls = 0;
        final a = AutoRefresh(
          refresh: () async {},
          poll: () async {
            calls++;
            throw StateError('offline');
          },
          hasPending: () => true,
        );
        a.sync();
        async.elapse(_five * 3);
        expect(calls, 3);
        a.dispose();
      });
    });
  });

  group('HistoryController', () {
    late FakeVerificationRepository repo;
    late VerificationEvents events;
    late RxInt tab;
    late HistoryController c;

    HistoryController make({bool Function()? onTop}) => HistoryController(
      repository: repo,
      navigator: FakeNavigator(),
      events: events,
      shell: tab,
      isRouteOnTop: onTop,
    );

    setUp(() {
      repo = FakeVerificationRepository();
      events = VerificationEvents();
      tab = 1.obs; // History is visible
    });

    test('updates a processing row by itself and stops when done', () {
      fakeAsync((async) {
        repo.items = [_s('a', 'PROCESSING')];
        c = make()..onInit();
        c.onReady();
        async.flushMicrotasks();
        expect(c.items.single.isProcessing, isTrue);
        expect(repo.historyCalls, 1);

        async.elapse(_five);
        expect(repo.historyCalls, 2);
        expect(c.items.single.isProcessing, isTrue);

        // The backend finishes: the next tick shows it, no pull needed.
        repo.items = [_s('a', 'AWAITING_RATES')];
        async.elapse(_five);
        expect(repo.historyCalls, 3);
        expect(c.items.single.isAwaitingRates, isTrue);

        // Nothing processing anymore: polling stops.
        async.elapse(_five * 4);
        expect(repo.historyCalls, 3);
        c.onClose();
      });
    });

    test('does not poll without processing items or off its tab', () {
      fakeAsync((async) {
        repo.items = [_s('a', 'COMPLETED')];
        c = make()..onInit();
        c.onReady();
        async.flushMicrotasks();
        async.elapse(_five * 3);
        expect(repo.historyCalls, 1);
        c.onClose();

        repo.items = [_s('a', 'PROCESSING')];
        tab.value = 0; // Home tab
        final other = make()..onInit();
        other.onReady();
        async.flushMicrotasks();
        final before = repo.historyCalls;
        async.elapse(_five * 3);
        expect(repo.historyCalls, before);
        // Showing History refreshes it at once.
        tab.value = 1;
        async.flushMicrotasks();
        expect(repo.historyCalls, before + 1);
        other.onClose();
      });
    });

    test('refreshes on a change event without a spinner', () {
      fakeAsync((async) {
        repo.items = [_s('a', 'COMPLETED')];
        c = make()..onInit();
        c.onReady();
        async.flushMicrotasks();
        repo.items = [_s('b', 'PROCESSING'), _s('a', 'COMPLETED')];
        var loadingSeen = false;
        c.loading.listen((v) => loadingSeen = loadingSeen || v);
        events.notify();
        async.flushMicrotasks();
        expect(c.items.map((e) => e.id), ['b', 'a']);
        expect(loadingSeen, isFalse);
        // A new processing row starts the poll by itself.
        async.elapse(_five);
        expect(repo.historyCalls, 3);
        c.onClose();
      });
    });

    test('keeps the loaded pages and updates rows in place', () {
      fakeAsync((async) {
        repo.items = [
          _s('v0', 'PROCESSING'),
          _s('v1', 'COMPLETED'),
          _s('v2', 'COMPLETED'),
        ];
        c = HistoryController(
          repository: repo,
          navigator: FakeNavigator(),
          pageSize: 2,
          events: events,
        )..onInit();
        c.onReady();
        async.flushMicrotasks();
        c.loadMore();
        async.flushMicrotasks();
        expect(c.items.map((e) => e.id), ['v0', 'v1', 'v2']);
        repo.items = [
          _s('v0', 'AWAITING_RATES'),
          _s('v1', 'COMPLETED'),
          _s('v2', 'COMPLETED'),
        ];
        events.notify();
        async.flushMicrotasks();
        expect(c.items.map((e) => e.id), ['v0', 'v1', 'v2']);
        expect(c.items.first.isAwaitingRates, isTrue);
        c.onClose();
      });
    });

    test('a failing silent refresh keeps the list, no error and the poll', () {
      fakeAsync((async) {
        repo.items = [_s('a', 'PROCESSING')];
        c = make()..onInit();
        c.onReady();
        async.flushMicrotasks();
        repo.historyError = StateError('offline');
        async.elapse(_five * 2);
        expect(repo.historyCalls, 3);
        expect(c.items.single.id, 'a');
        expect(c.errorMessage.value, isNull);
        repo.historyError = null;
        repo.items = [_s('a', 'COMPLETED')];
        async.elapse(_five);
        expect(c.items.single.isCompleted, isTrue);
        c.onClose();
      });
    });
  });

  group('return to Home', () {
    late VerificationEvents events;
    late int notified;

    setUp(() {
      events = VerificationEvents();
      notified = 0;
      events.changes.listen((_) => notified++);
    });

    test('coming back to Home notifies', () async {
      notifyOnReturnToHome(
        Routing(current: Routes.home, previous: Routes.result, isBack: true),
        events,
      );
      await Future<void>.delayed(Duration.zero);
      expect(notified, 1);
    });

    test('other navigation does not', () async {
      notifyOnReturnToHome(null, events);
      notifyOnReturnToHome(Routing(current: Routes.home), events);
      notifyOnReturnToHome(
        Routing(current: Routes.upload, previous: Routes.home),
        events,
      );
      notifyOnReturnToHome(
        Routing(current: Routes.result, previous: Routes.home, isBack: true),
        events,
      );
      notifyOnReturnToHome(
        Routing(current: Routes.home, isBack: true, isDialog: true),
        events,
      );
      await Future<void>.delayed(Duration.zero);
      expect(notified, 0);
    });
  });
}
