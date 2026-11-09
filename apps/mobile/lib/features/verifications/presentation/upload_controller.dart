import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../cards/presentation/cards_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../domain/pdf_picker.dart';
import '../domain/verification_repository.dart';

enum UploadPhase { idle, uploading, analyzing }

class UploadController extends GetxController {
  UploadController({
    required this._repository,
    required this._picker,
    required this._cards,
    required this._credits,
    required this._navigator,
    this.onVerified,
    this.initialCardId,
  });

  static const maxBytes = 10 * 1024 * 1024;

  final VerificationRepository _repository;
  final PdfPicker _picker;
  final CardsController _cards;
  final CreditsController _credits;
  final AppNavigator _navigator;
  final VoidCallback? onVerified;
  final String? initialCardId;

  final cardId = RxnString();
  final file = Rxn<PickedPdf>();
  final phase = UploadPhase.idle.obs;
  final progress = 0.0.obs;
  final errorMessage = RxnString();

  CardsController get cards => _cards;
  CreditsController get credits => _credits;
  bool get busy => phase.value != UploadPhase.idle;

  @override
  void onInit() {
    super.onInit();
    cardId.value = initialCardId;
    _autoSelectSingleCard();
  }

  void _autoSelectSingleCard() {
    if (cardId.value == null && _cards.cards.length == 1) {
      cardId.value = _cards.cards.first.id;
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (_credits.balance.value == null) _credits.fetch();
    if (!_cards.loaded.value) {
      _cards.load().then((_) => _autoSelectSingleCard());
    }
  }

  void selectCard(String? id) => cardId.value = id;

  Future<void> pickFile() async {
    final picked = await _picker.pick();
    if (picked == null) return;
    if (!picked.name.toLowerCase().endsWith('.pdf')) {
      errorMessage.value = S.fileNotPdf;
      return;
    }
    if (picked.sizeBytes > maxBytes) {
      errorMessage.value = S.fileTooLarge;
      return;
    }
    errorMessage.value = null;
    file.value = picked;
  }

  bool get canSubmit => cardId.value != null && file.value != null && !busy;

  Future<void> submit() async {
    if (!canSubmit) return;
    errorMessage.value = null;
    if (!await _hasCredits()) {
      errorMessage.value = S.uploadNoCredits;
      _navigator.push(Routes.paywall);
      return;
    }
    phase.value = UploadPhase.uploading;
    progress.value = 0;
    try {
      final verification = await _repository.upload(
        cardId: cardId.value!,
        filePath: file.value!.path,
        onProgress: (sent, total) {
          if (total <= 0) return;
          progress.value = sent / total;
          if (sent >= total) phase.value = UploadPhase.analyzing;
        },
      );
      onVerified?.call();
      _credits.fetch(); // the analysis just spent one
      // The analysis runs in the backend: the progress page polls it.
      _navigator.replace(
        Routes.verificationProgress,
        arguments: verification.id,
      );
    } on AppException catch (e) {
      _handleError(e);
    } finally {
      phase.value = UploadPhase.idle;
    }
  }

  /// A known empty balance is re-checked once (it may be stale) before the
  /// user is sent to the paywall; an unknown balance never blocks.
  Future<bool> _hasCredits() async {
    final known = _credits.balance.value;
    if (known == null || known.hasCredits) return true;
    final fresh = await _credits.fetch();
    return fresh == null || fresh.hasCredits;
  }

  void _handleError(AppException e) {
    if (e.isNoCredits) {
      _credits.applyFromError(e);
      _navigator.push(Routes.paywall);
      errorMessage.value = userMessageFor(e);
      return;
    }
    errorMessage.value = e.kind == AppErrorKind.timeout
        ? S.uploadTimeout
        : userMessageFor(e);
  }
}
