import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../cards/presentation/cards_controller.dart';
import '../domain/pdf_picker.dart';
import '../domain/verification_repository.dart';

enum UploadPhase { idle, uploading, analyzing }

class UploadController extends GetxController {
  UploadController({
    required this._repository,
    required this._picker,
    required this._cards,
    required this._navigator,
    this.onVerified,
    this.initialCardId,
  });

  static const maxBytes = 10 * 1024 * 1024;

  final VerificationRepository _repository;
  final PdfPicker _picker;
  final CardsController _cards;
  final AppNavigator _navigator;
  final VoidCallback? onVerified;
  final String? initialCardId;

  final cardId = RxnString();
  final file = Rxn<PickedPdf>();
  final phase = UploadPhase.idle.obs;
  final progress = 0.0.obs;
  final errorMessage = RxnString();

  /// Set when the statement shows no reward figure; asks the user to type it.
  final needsOverride = false.obs;
  final overrideText = TextEditingController();
  final overrideError = RxnString();

  CardsController get cards => _cards;
  bool get busy => phase.value != UploadPhase.idle;

  static final _amount = RegExp(r'^\d+([.,]\d{1,2})?$');

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
    String? override;
    if (needsOverride.value) {
      final text = overrideText.text.trim();
      if (!_amount.hasMatch(text)) {
        overrideError.value = S.overrideInvalid;
        return;
      }
      override = text;
    }
    overrideError.value = null;
    errorMessage.value = null;
    phase.value = UploadPhase.uploading;
    progress.value = 0;
    try {
      final verification = await _repository.verify(
        cardId: cardId.value!,
        filePath: file.value!.path,
        reportedRewardOverride: override,
        onProgress: (sent, total) {
          if (total <= 0) return;
          progress.value = sent / total;
          if (sent >= total) phase.value = UploadPhase.analyzing;
        },
      );
      onVerified?.call();
      _navigator.replace(Routes.result, arguments: verification);
    } on AppException catch (e) {
      _handleError(e);
    } finally {
      phase.value = UploadPhase.idle;
    }
  }

  void _handleError(AppException e) {
    if (e.isSubscriptionRequired) {
      _navigator.push(Routes.paywall);
      errorMessage.value = userMessageFor(e);
      return;
    }
    if (e.code == 'REPORTED_REWARD_NOT_FOUND') {
      needsOverride.value = true;
    }
    errorMessage.value = e.kind == AppErrorKind.timeout
        ? S.uploadTimeout
        : userMessageFor(e);
  }

  @override
  void onClose() {
    overrideText.dispose();
    super.onClose();
  }
}
