// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Cashback Audit';

  @override
  String get tagline => 'Check that your bank pays you what you are owed.';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get continueLabel => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get devSignIn => 'Sign in as test user (development)';

  @override
  String get back => 'Back';

  @override
  String get loading => 'Loading…';

  @override
  String get offlineBanner => 'You are offline. Showing saved data.';

  @override
  String get errNetwork =>
      'We could not reach the server. Check your connection and try again.';

  @override
  String get errTimeout => 'The request took too long. Try again.';

  @override
  String get errUnauthorized => 'Your session expired. Sign in again.';

  @override
  String get errNoCredits =>
      'You have no checks available. Subscribe or buy a pack to continue.';

  @override
  String get errRatesRequired =>
      'Enter the percentage for the categories marked as required.';

  @override
  String get errProgramAmbiguous =>
      'Your statement lists several reward programs. Choose which one to audit.';

  @override
  String get errTransactionNotFound => 'We could not find that transaction.';

  @override
  String get errTransactionNotClassifiable =>
      'This transaction earns no reward, so it cannot be assigned to a category.';

  @override
  String get errVerificationNotFound =>
      'This check no longer exists. Checks not confirmed within 7 days are deleted.';

  @override
  String get errValidation => 'Check the data and try again.';

  @override
  String get errNotFound => 'We could not find what you were looking for.';

  @override
  String get errConflict => 'That action conflicts with existing data.';

  @override
  String get errTooLarge => 'The file exceeds the 10 MB limit.';

  @override
  String get errNotPdf => 'Only PDF files are accepted.';

  @override
  String get errRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get errServer =>
      'Something went wrong on our side. Try again in a few minutes.';

  @override
  String get errUnknown => 'An unexpected error occurred.';

  @override
  String get errCategoryNameTaken =>
      'You already have a category with that name.';

  @override
  String get errMerchantNameTaken =>
      'You already have a merchant with that name.';

  @override
  String get errCategoryInUse =>
      'This category has merchants or card rules. Choose which category to move them to.';

  @override
  String get errInvalidPdf => 'The file is not a valid PDF.';

  @override
  String get errUnreadable =>
      'We could not read that statement. Download the original PDF from your bank (not a photo or a password-protected file).';

  @override
  String get errRewardRateRequired =>
      'Enter what the reward currency is worth so we can convert it.';

  @override
  String get errInvalidExchangeRate =>
      'Check the exchange rates: they must be numbers greater than 0 (up to 6 decimals).';

  @override
  String get errRewardNotFound =>
      'The statement does not show the reward your bank paid you. Enter it to continue.';

  @override
  String get errExtractionFailed =>
      'The analysis did not return a usable result. Retrying usually works.';

  @override
  String get errExtractionUnavailable =>
      'The analysis service is busy. Try again later.';

  @override
  String get errIdentityToken =>
      'We could not validate your account. Try again.';

  @override
  String get errIdentityUnavailable => 'Sign-in is not available right now.';

  @override
  String get errSignInFailed => 'We could not complete the sign-in. Try again.';

  @override
  String get sessionExpiredTitle => 'Session ended';

  @override
  String get onb1Title => 'Check what your bank owes you';

  @override
  String get onb1Body =>
      'Upload your statement and we calculate how much cashback or how many points you should have received.';

  @override
  String get onb2Title => 'Register your cards and categories';

  @override
  String get onb2Body =>
      'Enter each card’s base rate and the percentages per category (groceries, fuel, restaurants…). Assign each merchant to the category where you expect it to earn.';

  @override
  String get onb3Title => 'Upload the PDF and review the verdict';

  @override
  String get onb3Body =>
      'We show whether the payout matches, is under or over, with the detail by category and by transaction.';

  @override
  String get onb4Title => 'Your privacy comes first';

  @override
  String get onb4Body =>
      'We never store your PDF or your full card number: only the last 4 digits and the analysis results.';

  @override
  String get start => 'Get started';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle =>
      'Use your account to save your cards, categories and check history.';

  @override
  String get signInGoogle => 'Continue with Google';

  @override
  String get signInApple => 'Continue with Apple';

  @override
  String get loginLegal => 'We do not store your PDF or your full card number.';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get last4Invalid => 'Enter exactly 4 digits';

  @override
  String get currencyInvalid => 'Use a 3-letter code (USD, MXN…)';

  @override
  String get numberInvalid => 'Enter a valid number';

  @override
  String get percentRange => 'Must be between 0 and 100';

  @override
  String get capInvalid => 'Must be greater than 0 (up to 2 decimals)';

  @override
  String get pointsFactorInvalid => 'Must be greater than 0 and up to 1000';

  @override
  String get homeCards => 'My cards';

  @override
  String get homeNoCardsTitle => 'You have no cards yet';

  @override
  String get homeNoCardsBody =>
      'Add your first card with its reward rates to start auditing.';

  @override
  String get addCard => 'Add card';

  @override
  String get manageCategories => 'Categories and merchants';

  @override
  String get logout => 'Sign out';

  @override
  String get loadError => 'We could not load your data.';

  @override
  String get newCard => 'New card';

  @override
  String get editCard => 'Edit card';

  @override
  String get cardAlias => 'Alias';

  @override
  String get cardAliasHint => 'E.g. Daily card';

  @override
  String get cardBank => 'Bank';

  @override
  String get cardLast4 => 'Last 4 digits';

  @override
  String get cardLast4Helper => 'We never ask for the full number.';

  @override
  String get cardNetwork => 'Network (optional)';

  @override
  String get cardCurrency => 'Currency';

  @override
  String get cardRewardProgram => 'Reward program to audit';

  @override
  String get cardRewardProgramHelper =>
      'Optional. If your statement lists several programs (e.g. CASH BAC), enter the name of the one you want to audit.';

  @override
  String get cardRewardCurrency => 'Currency in which you receive the reward';

  @override
  String get cardRewardCurrencyHelper =>
      'Optional. If your bank pays the reward in a different currency than your purchases (e.g. dollars), enter it. Empty = detect automatically.';

  @override
  String get cardRewardCurrencyAuto => 'Detect automatically';

  @override
  String get rewardUnitLabel => 'Reward type';

  @override
  String get unitCashback => 'Cashback';

  @override
  String get unitPoints => 'Points';

  @override
  String get pointsPerUnit => 'Points per \$1 of reward';

  @override
  String get baseRate => 'Base rate (%)';

  @override
  String get baseRateHelper =>
      'Applies to all spending without a category rule.';

  @override
  String get rulesTitle => 'Category rules';

  @override
  String get rulesHelper =>
      'Set a different rate for each category, with an optional monthly cap.';

  @override
  String get addRule => 'Add rule';

  @override
  String get ruleCategory => 'Category';

  @override
  String get ruleRate => 'Rate (%)';

  @override
  String get ruleCap => 'Monthly cap';

  @override
  String get ruleCapHelper => 'Optional';

  @override
  String get removeRule => 'Remove rule';

  @override
  String get ruleNeedsCategories =>
      'Create at least one category first to define rules.';

  @override
  String get ruleCategoryRequired => 'Choose a category';

  @override
  String get ruleDuplicateCategory =>
      'There is already a rule for that category';

  @override
  String get deleteCardTitle => 'Delete card';

  @override
  String get cardSaved => 'Card saved';

  @override
  String get cardDeleted => 'Card deleted';

  @override
  String get catalogTitle => 'Categories and merchants';

  @override
  String get addCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryDescription => 'Description (optional)';

  @override
  String get addMerchant => 'Add merchant';

  @override
  String get editMerchant => 'Edit merchant';

  @override
  String get merchantName => 'Merchant name';

  @override
  String get merchantKeywords => 'Statement keywords';

  @override
  String get merchantKeywordsHelper =>
      'As they appear on your statement, separated by commas. E.g. WAL MART, WALMART SUC';

  @override
  String get merchantCategory => 'Expected category';

  @override
  String get noMerchants => 'No merchants';

  @override
  String get catalogEmptyTitle => 'Create your first category';

  @override
  String get catalogEmptyBody =>
      'Categories (groceries, fuel, restaurants…) group merchants and get special rates on your cards.';

  @override
  String get deleteCategoryTitle => 'Delete category';

  @override
  String get reassignTo => 'Move to';

  @override
  String get reassignAndDelete => 'Move and delete';

  @override
  String get deleteMerchantTitle => 'Delete merchant';

  @override
  String get needOtherCategory =>
      'Create another category so you can move the items.';

  @override
  String get settingsTitle => 'Profile and settings';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get longPressHint => 'Press and hold a card to delete it';

  @override
  String get uploadTitle => 'Check a statement';

  @override
  String get uploadStep1 => 'Choose the card';

  @override
  String get uploadStep2 => 'Select the PDF';

  @override
  String get pickPdf => 'Choose PDF';

  @override
  String get changePdf => 'Change file';

  @override
  String get noCardsForUpload =>
      'Add a card first so you can check a statement.';

  @override
  String get verify => 'Check';

  @override
  String get uploading => 'Uploading file…';

  @override
  String get analyzing => 'Analyzing your statement…';

  @override
  String get analyzingHint =>
      'It can take up to a minute. Do not close the app.';

  @override
  String get uploadPrivacy =>
      'We process the PDF in memory and do not store it.';

  @override
  String get fileTooLarge => 'The file exceeds the 10 MB limit.';

  @override
  String get fileNotPdf => 'Choose a PDF file.';

  @override
  String get uploadTimeout =>
      'The analysis took too long. Check your history before retrying: it may have already been processed.';

  @override
  String get overrideTitle => 'Enter the reward your bank gave you';

  @override
  String get overrideLabel => 'Reported reward';

  @override
  String get overrideHelper =>
      'Find it on your statement (bonus or points for the period).';

  @override
  String get overrideInvalid => 'Enter a valid amount (up to 2 decimals)';

  @override
  String get selectCardFirst => 'Choose a card';

  @override
  String get analyzingStepUpload => 'File received';

  @override
  String get analyzingStepRead => 'Reading your statement';

  @override
  String get analyzingStepClassify => 'Classifying transactions';

  @override
  String get analyzingExpect =>
      'This step usually takes about 1 minute. Then you can confirm the percentages.';

  @override
  String get confirmRatesTitle => 'Confirm the percentages';

  @override
  String get recalcRatesTitle => 'Recalculate with other %';

  @override
  String get confirmRatesIntro =>
      'Banks change their policies often. Review the percentages we will use to calculate what you should have received.';

  @override
  String get confirmRatesNoCharge =>
      'Calculating and recalculating does not use up checks.';

  @override
  String get rateBaseTitle => 'Base rate';

  @override
  String get rateBaseSubtitle =>
      'Applies to all spending outside your categories.';

  @override
  String get rateFieldLabel => 'Percentage';

  @override
  String get rateCapLabel => 'Monthly cap (optional)';

  @override
  String get badgeStatement => 'Detected in your statement';

  @override
  String get badgeCardRule => 'From your card rules';

  @override
  String get badgePrevious => 'The ones you used before';

  @override
  String get badgeRequired => 'Required';

  @override
  String get rateRequiredError => 'Enter the percentage to continue';

  @override
  String get saveToCardTitle => 'Save these % on the card';

  @override
  String get saveToCardSubtitle =>
      'Replaces your card’s base rate and category rules.';

  @override
  String get exchangeRateTitle => 'Exchange rate (optional)';

  @override
  String get exchangeRateMissing =>
      'There are foreign-currency purchases. Without an exchange rate they will be left out of the calculation.';

  @override
  String get exchangeRateInvalid =>
      'Enter a number greater than 0 (up to 6 decimals)';

  @override
  String get rewardRateRequiredError => 'Enter the exchange rate to continue';

  @override
  String get foreignRatesTitle => 'Purchases in other currencies';

  @override
  String get foreignRatesHelper =>
      'Optional. If you leave an exchange rate empty, purchases in that currency are left out of the calculation.';

  @override
  String get foreignRateOptional => 'Optional';

  @override
  String get suggestionsTitle =>
      'Your statement mentions categories you do not have';

  @override
  String get suggestionsHelper =>
      'Create them to audit those purchases with the percentage your bank states.';

  @override
  String get suggestionsFree => 'It is free: it does not use up checks.';

  @override
  String get createSuggestions => 'Create selected categories';

  @override
  String get creatingSuggestions => 'Creating categories…';

  @override
  String get suggestionsCreated =>
      'Categories created. They now appear below with the percentage from your statement.';

  @override
  String get programChooserTitle => 'Choose the program to audit';

  @override
  String get programChooserHelper =>
      'Your statement lists several reward programs.';

  @override
  String get programRequired => 'Choose a program to continue';

  @override
  String get calculateResult => 'Calculate result';

  @override
  String get calculating => 'Calculating…';

  @override
  String get confirmLoadError => 'We could not load this check.';

  @override
  String get resultTitle => 'Result';

  @override
  String get resultNotConfirmed =>
      'This check has no result yet. Confirm the percentages to calculate it.';

  @override
  String get verdictMatch => 'All good';

  @override
  String get verdictUnderpaid => 'You were underpaid';

  @override
  String get verdictOverpaid => 'You were overpaid';

  @override
  String get verdictMatchHint => 'The reward matches what was expected.';

  @override
  String get expectedLabel => 'Expected';

  @override
  String get reportedLabel => 'Reported';

  @override
  String get differenceLabel => 'Difference';

  @override
  String get reportedOverrideNote => 'Entered by you';

  @override
  String get breakdownTitle => 'Breakdown by category';

  @override
  String get baseRateLine => 'Base rate';

  @override
  String get capped => 'Cap reached';

  @override
  String get transactionsTitle => 'Transactions';

  @override
  String get filterAll => 'All';

  @override
  String get filterCounted => 'In category';

  @override
  String get filterUncounted => 'No category';

  @override
  String get filterExcluded => 'Excluded';

  @override
  String get countedLabel => 'Counted in category';

  @override
  String get uncountedLabel => 'No category';

  @override
  String get excludedLabel => 'Earns no reward';

  @override
  String get aiChip => 'AI';

  @override
  String get aiChipTooltip => 'Assigned by artificial intelligence';

  @override
  String get userChip => 'You';

  @override
  String get userChipTooltip => 'Category corrected by you';

  @override
  String get excludedPayment => 'Payments earn no reward';

  @override
  String get excludedFee => 'Fee or charge';

  @override
  String get excludedInterest => 'Interest';

  @override
  String get excludedInsurance => 'Insurance';

  @override
  String get excludedOther => 'Transaction that earns no reward';

  @override
  String get changeCategory => 'Change category';

  @override
  String get changeCategoryTitle => 'Change this transaction’s category';

  @override
  String get noCategoryOption => 'No category';

  @override
  String get categoryChanged => 'Category updated and result recalculated';

  @override
  String get recalcFailedAfterChange =>
      'You changed the category, but we could not recalculate the result. The amounts shown are still the previous ones.';

  @override
  String get recalcNeedsRate =>
      'That category needs a percentage. Confirm it to recalculate.';

  @override
  String get recalcAction => 'Recalculate';

  @override
  String get recalcWithOtherRates => 'Recalculate with other %';

  @override
  String get explanationTitle => 'In short';

  @override
  String get loyaltyTitle => 'Reward programs';

  @override
  String get loyaltyAudited => 'Audited';

  @override
  String get loyaltyCumulativeChip => 'Possible accumulated balance';

  @override
  String get loyaltyProgram => 'Program';

  @override
  String get loyaltyAccumulated => 'Accumulated';

  @override
  String get loyaltyAvailable => 'Available';

  @override
  String get loyaltyRedeemed => 'Redeemed';

  @override
  String get loyaltyExpiring => 'Expiring';

  @override
  String get loyaltyForfeited => 'Forfeited';

  @override
  String get currenciesTitle => 'Subtotals by currency';

  @override
  String get currencySpent => 'Net spending';

  @override
  String get currencyEligible => 'Considered';

  @override
  String get currencyReward => 'Reward (uncapped)';

  @override
  String get appliedRatesTitle => 'Percentages used';

  @override
  String get warnLast4 =>
      'This statement seems to belong to another card: the last 4 digits do not match.';

  @override
  String get warnCurrencyMismatch =>
      'None of the statement’s currencies matches your card’s currency.';

  @override
  String get warnTotalMismatch =>
      'The transactions read do not add up to the statement total. Some may be missing and the result may be unreliable.';

  @override
  String get warnNoTransactions => 'We found no transactions in the statement.';

  @override
  String get warnAiUnavailable =>
      'AI classification was unavailable for some transactions; only your registered merchants were used.';

  @override
  String get warnNoExchangeRate =>
      'There are foreign-currency purchases without an exchange rate: they were left out of the calculation.';

  @override
  String get warnExchangeMultiple =>
      'The exchange rate was applied to more than one foreign currency.';

  @override
  String get warnCumulative =>
      'The reported figure looks like an accumulated balance rather than what was earned this period. Check the program.';

  @override
  String get warnUnitDiffers =>
      'The program reports a different unit than your card; the card’s setting was used.';

  @override
  String get assignToCategory => 'Remember merchant in a category';

  @override
  String get assignedNotice => 'Assigned for future checks';

  @override
  String get baseOnly => 'Base rate only';

  @override
  String get creditPayment => 'Card payment';

  @override
  String get creditRefund => 'Refund';

  @override
  String get creditOther => 'Other credit / bonus';

  @override
  String get rewardRateDetailTitle => 'Reward conversion';

  @override
  String get rewardRateFromStatement => 'Taken from your statement';

  @override
  String get rewardRateUserEntered => 'Entered by you';

  @override
  String get assignSheetTitle => 'Assign merchant to a category';

  @override
  String get noCategoriesToAssign =>
      'Create a category first so you can assign this merchant.';

  @override
  String get goToCategories => 'Go to categories';

  @override
  String get merchantAssigned => 'Merchant assigned';

  @override
  String get warningsTitle => 'Notices';

  @override
  String get noTransactionsMatch => 'There are no transactions in this view.';

  @override
  String get periodLabel => 'Period';

  @override
  String get deleteVerification => 'Delete check';

  @override
  String get deleteVerificationBody => 'Delete this check from your history?';

  @override
  String get awaitingRatesChip => 'Waiting for % confirmation';

  @override
  String get historyTitle => 'History';

  @override
  String get historyEmptyTitle => 'No checks yet';

  @override
  String get historyEmptyBody =>
      'When you check a statement it will appear here.';

  @override
  String get allCards => 'All';

  @override
  String get loadMore => 'Show more';

  @override
  String get latestVerifications => 'Latest checks';

  @override
  String get seeAll => 'See all';

  @override
  String get verifyAction => 'Check statement';

  @override
  String get historyAction => 'History';

  @override
  String get creditsNone => 'No checks available';

  @override
  String get uploadFreeNotice => 'Your first check is free.';

  @override
  String get uploadNoCredits =>
      'You have no checks available to analyze another statement.';

  @override
  String get seePlans => 'See plans';

  @override
  String get creditsTitle => 'Checks';

  @override
  String get creditsHistoryTitle => 'Check history';

  @override
  String get creditsHistoryEmptyTitle => 'No activity yet';

  @override
  String get creditsHistoryEmptyBody =>
      'Here you will see when you receive, use or get refunded checks.';

  @override
  String get creditsBuy => 'Buy checks';

  @override
  String get creditReasonGrantFree => 'Free check';

  @override
  String get creditReasonGrantPlan => 'Checks from your subscription';

  @override
  String get creditReasonGrantPack => 'Purchased pack';

  @override
  String get creditReasonConsume => 'Statement analyzed';

  @override
  String get creditReasonRefund => 'Check refunded';

  @override
  String get creditReasonExpirePlan => 'Plan balance expired';

  @override
  String get creditReasonOther => 'Adjustment';

  @override
  String get creditBucketFree => 'Free';

  @override
  String get creditBucketPlan => 'Plan';

  @override
  String get creditBucketPurchased => 'Purchased';

  @override
  String get paywallTitle => 'Cashback Audit Pro';

  @override
  String get paywallHeadline => 'More checks, whenever you need them';

  @override
  String get paywallBenefit1 => 'Each statement you analyze uses 1 check';

  @override
  String get paywallBenefit2 =>
      'Confirming, recalculating and correcting transactions costs nothing';

  @override
  String get paywallBenefit3 => 'Your history is always available';

  @override
  String get paywallSubscriptionTitle => 'Monthly subscription';

  @override
  String get paywallSubscriptionPerks =>
      '5 checks per month · they do not roll over';

  @override
  String get paywallPacksTitle => 'Check packs';

  @override
  String get paywallPacksSubtitle => 'One-time purchase, they never expire.';

  @override
  String get paywallBuy => 'Buy';

  @override
  String get paywallSuccessPack => 'Your checks are now available.';

  @override
  String get paywallConfirmingPurchase => 'Confirming your purchase…';

  @override
  String get paywallPendingPack =>
      'Your purchase is being processed. The checks may take a few seconds to appear.';

  @override
  String get restoreNothing =>
      'We found no purchases to restore on this account.';

  @override
  String get paywallSubscribe => 'Subscribe';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallLegal =>
      'The subscription renews automatically. You can cancel at any time from your app store settings.';

  @override
  String get paywallNoPackages =>
      'No plans are available right now. Try again later.';

  @override
  String get paywallLoadFailed =>
      'We could not load the plans. Check your connection and try again.';

  @override
  String get paywallPurchaseFailed =>
      'The purchase could not be completed. You were not charged.';

  @override
  String get paywallRestoreFailed =>
      'We could not restore your purchases. Try again.';

  @override
  String get paywallConfirming => 'Confirming your purchase…';

  @override
  String get paywallPending =>
      'Your purchase is being processed. It may take a few seconds to show up.';

  @override
  String get paywallCheckAgain => 'Check again';

  @override
  String get paywallSuccessTitle => 'All set!';

  @override
  String get paywallSuccessBody => 'Your subscription is active.';

  @override
  String get paywallDevNoticeTitle => 'Purchases not configured';

  @override
  String get paywallDevNotice =>
      'This build has no RevenueCat key (REVENUECAT_IOS_KEY / REVENUECAT_ANDROID_KEY). Set it with --dart-define to test purchases.';

  @override
  String get subscriptionTitle => 'Subscription';

  @override
  String get subscribeNow => 'See plans';

  @override
  String get subscriptionNone => 'No active subscription';

  @override
  String get subscriptionActive => 'Pro active';

  @override
  String get subscriptionCancelled => 'Cancelled';

  @override
  String get subscriptionBillingIssue => 'Billing issue';

  @override
  String get subscriptionExpired => 'Expired';

  @override
  String get subscriptionBillingIssueHint =>
      'Update your payment method in the store so you do not lose access.';

  @override
  String get restoreDone => 'Purchases restored';

  @override
  String fieldTooLong(int max) {
    return 'Maximum $max characters';
  }

  @override
  String greeting(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Hello',
      'other': 'Hello, $name',
    });
    return '$_temp0';
  }

  @override
  String deleteCardBody(String alias) {
    return 'Delete \"$alias\"? Its check history will also be deleted.';
  }

  @override
  String ruleCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n rules',
      one: '1 rule',
      zero: 'No rules',
    );
    return '$_temp0';
  }

  @override
  String ruleCountPlain(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String baseRateShort(String rate) {
    return 'Base $rate';
  }

  @override
  String deleteCategoryBody(String name) {
    return 'Delete the category \"$name\"?';
  }

  @override
  String reassignBody(String merchants, String rules) {
    return 'This category has $merchants and $rules on your cards. Choose which category to move them to before deleting it.';
  }

  @override
  String deleteMerchantBody(String name) {
    return 'Delete \"$name\"? It will stop being assigned to its category.';
  }

  @override
  String merchantCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n merchants',
      one: '1 merchant',
    );
    return '$_temp0';
  }

  @override
  String evidenceQuote(String text) {
    return '“$text”';
  }

  @override
  String exchangeRateHelper(String primary) {
    return 'How many $primary 1 unit of the foreign currency is worth. Without it, purchases in another currency do not count toward the reward.';
  }

  @override
  String exchangeRateStatement(String from, String to, String rate) {
    return 'Your statement says 1 $from = $rate $to.';
  }

  @override
  String howManyIs(String primary, String foreign) {
    return 'How many $primary is 1 $foreign worth?';
  }

  @override
  String rewardConversionTitle(String reward, String primary) {
    return 'Your bank pays the reward in $reward and your purchases are in $primary';
  }

  @override
  String rewardConversionHelper(String reward) {
    return 'We need this exchange rate to convert what you should have received into $reward. It is required.';
  }

  @override
  String foreignRateEmptyNote(String currency) {
    return 'Without an exchange rate, purchases in $currency do not count.';
  }

  @override
  String suggestionLines(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n transactions',
      one: '1 transaction',
      zero: 'No transactions',
    );
    return '$_temp0';
  }

  @override
  String verdictUnderpaidHint(String amount) {
    return 'The bank owes you $amount. You can claim it with your statement.';
  }

  @override
  String verdictOverpaidHint(String amount) {
    return 'The bank paid you $amount too much.';
  }

  @override
  String breakdownDetail(String spend, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$spend in $_temp0';
  }

  @override
  String capOf(String cap) {
    return 'Cap $cap';
  }

  @override
  String filterWithCount(String label, int n) {
    return '$label ($n)';
  }

  @override
  String transactionsSummary(int counted, int uncounted, int excluded) {
    return '$counted in category · $uncounted no category · $excluded excluded';
  }

  @override
  String convertedAs(String amount) {
    return '≈ $amount';
  }

  @override
  String excludedNoRate(String currency) {
    return '$currency purchase without exchange rate';
  }

  @override
  String currencyRate(String from, String to, String rate) {
    return '1 $from = $rate $to';
  }

  @override
  String currencyExcluded(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n transactions excluded',
      one: '1 transaction excluded',
    );
    return '$_temp0';
  }

  @override
  String assignedTo(String category) {
    return 'Assigned to $category · will apply to the next check';
  }

  @override
  String appliedRate(String rate) {
    return 'Rate $rate';
  }

  @override
  String bankConsiders(String hint) {
    return 'Your bank treats it as: $hint';
  }

  @override
  String equivalentTo(String money) {
    return 'Equivalent to $money';
  }

  @override
  String rewardRateDetail(String reward, String rate, String primary) {
    return '1 $reward = $rate $primary';
  }

  @override
  String creditsAvailable(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n checks available',
      one: '1 check available',
    );
    return '$_temp0';
  }

  @override
  String uploadCreditNotice(int n) {
    return 'This check will use 1 of your $n available.';
  }

  @override
  String creditsBreakdown(int free, int plan, int purchased) {
    return 'Free $free · Plan $plan · Purchased $purchased';
  }

  @override
  String creditsPlanExpires(String date) {
    return 'Plan checks expire on $date';
  }

  @override
  String packTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n checks',
      one: '1 check',
    );
    return '$_temp0';
  }

  @override
  String paywallFreeBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'You have $n free checks. Use them before buying anything.',
      one: 'You have 1 free check. Use it before buying anything.',
    );
    return '$_temp0';
  }

  @override
  String subscriptionRenews(String date) {
    return 'Renews on $date';
  }

  @override
  String subscriptionEnds(String date) {
    return 'Active until $date';
  }

  @override
  String stepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get assignCategory => 'Assign category';

  @override
  String get showDetails => 'Show details';

  @override
  String get hideDetails => 'Hide details';

  @override
  String get splashTagline => 'What your bank owes you';

  @override
  String get languageAutomatic => 'Automatic';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String onbLangAria(String language) {
    return 'Language: $language. Change';
  }

  @override
  String get onbHaveAccount => 'I have an account';

  @override
  String get onbDemoTitle => 'Did your bank pay all your cashback?';

  @override
  String get onbDemoStatementSays => 'Your statement says';

  @override
  String get onbDemoPharmacy => 'Kielsa Pharmacy · 7%';

  @override
  String get onbDemoPayment => 'Payment received · not counted';

  @override
  String get onbDemoOwed => 'You were owed';

  @override
  String get onbDemoSub =>
      'Upload the PDF, AI reads every purchase and we tell you if you were paid right, short or over. We will set up your card while you try it.';

  @override
  String get onbDemoCta => 'Run my free check';

  @override
  String get onbDemoFoot => 'About 3 minutes · no payment details needed';

  @override
  String get onbStepBank => 'Your bank';

  @override
  String get onbStepCard => 'Your card';

  @override
  String get onbStepCategories => 'Your categories';

  @override
  String get onbStepAccount => 'Your account';

  @override
  String get onbStepFreeCheck => 'Free check';

  @override
  String onbStepLabel(int step, int total, String name) {
    return 'Step $step of $total · $name';
  }

  @override
  String get onbBankTitle => 'Which bank is your card from?';

  @override
  String get onbBankSub =>
      'Works with any bank in any country. We use it to recognize your statement.';

  @override
  String get onbBankSearch => 'Search your bank';

  @override
  String get onbBankTested => 'Tested';

  @override
  String get onbBankOther => 'Other bank';

  @override
  String get onbBankOtherName => 'Your bank name';

  @override
  String onbCardTitle(String bank) {
    return 'Your $bank card';
  }

  @override
  String get onbCardName => 'Name';

  @override
  String get onbCardLast4 => 'Last 4';

  @override
  String get onbCardLast4Note => 'We only store these 4 digits.';

  @override
  String get onbRewardKind => 'What does the card give you?';

  @override
  String get onbRewardCashback => 'Cashback';

  @override
  String get onbRewardPoints => 'Points or miles';

  @override
  String get onbRewardCurrency => 'Which currency is it paid in?';

  @override
  String get onbCurrencyDetect => 'I don\'t know, detect it';

  @override
  String get onbRewardLabelCashback => 'CASHBACK';

  @override
  String get onbRewardLabelPoints => 'POINTS';

  @override
  String get onbCatsTitle => 'Where does your card give you more?';

  @override
  String get onbCatsSub =>
      'Check the categories of your card and their percentage. If you do not know it, leave it empty: we look for it in your statement.';

  @override
  String get onbCatSupermarkets => 'Supermarkets';

  @override
  String get onbCatPharmacy => 'Pharmacy';

  @override
  String get onbCatRestaurants => 'Restaurants and fast food';

  @override
  String get onbCatGas => 'Gas stations';

  @override
  String get onbCatDepartment => 'Department stores';

  @override
  String get onbCatOther => 'Another category';

  @override
  String get onbCatOtherName => 'Category name';

  @override
  String get onbCatAdd => 'Add';

  @override
  String get onbBaseTitle => 'Everything else';

  @override
  String get onbBaseSub =>
      'What a purchase earns outside these categories (base rate)';

  @override
  String get onbAccountTitle => 'Save what you set up';

  @override
  String get onbAccountSub =>
      'Create your account so you do not lose your card and can use your free check.';

  @override
  String onbAccountCardSub(String bank, String unit, String currency) {
    return '$bank · $unit in $currency';
  }

  @override
  String get onbAccountCurrencyDetected => 'currency to detect';

  @override
  String get onbAccountPrivacy =>
      'Your PDF is read in memory and never stored. We only keep the last 4 digits of your card.';

  @override
  String get onbSyncFailed =>
      'Your account is ready, but we could not save your setup. Check your connection and retry.';

  @override
  String get onbSyncing => 'Saving your setup…';

  @override
  String get onbFreeCheckPill => '1 free check';

  @override
  String onbHello(String name) {
    return 'Hi, $name';
  }

  @override
  String get onbPdfTitle => 'Upload your first statement';

  @override
  String get onbPdfSub =>
      'Pick the PDF your bank gave you. We read it in memory and never store it.';

  @override
  String get onbPdfPick => 'Choose PDF';

  @override
  String get onbPdfChange => 'Change PDF';

  @override
  String onbPdfForCard(String card) {
    return 'For $card';
  }

  @override
  String get onbPdfStart => 'Analyze with my free check';

  @override
  String get onbPdfLater => 'Not now, go to my home';

  @override
  String get onbPdfReadingTitle => 'Reading your statement';

  @override
  String get onbFirstVerification => 'Your first check';

  @override
  String onbSavedSummary(String card, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
      zero: 'no categories',
    );
    return 'Saved: your $card card, $_temp0 and this check.';
  }

  @override
  String get onbSeeDetail => 'See the details';

  @override
  String get onbGoHome => 'Go to my home';

  @override
  String onbContributes(String name, String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count purchases',
      one: '1 purchase',
    );
    return '$name adds $amount ($_temp0).';
  }

  @override
  String get onbVerdictStatusUnder => 'Underpaid';

  @override
  String get onbVerdictStatusOver => 'Overpaid';

  @override
  String get onbVerdictStatusMatch => 'Correct';

  @override
  String get processingTitle => 'Reading your statement';

  @override
  String get processingAnalyzing => 'Analyzing with AI';

  @override
  String get processingEta => 'about 40 s';

  @override
  String get processingStepCard => 'This is your card';

  @override
  String get processingStepPeriod => 'Finding the period and the movements';

  @override
  String get processingStepClassify => 'Sorting purchases into your categories';

  @override
  String get processingStepRates => 'Review your % and calculate';

  @override
  String get processingCardLine => 'Checking it matches the chosen card';

  @override
  String get processingCanLeave =>
      'You can close the app: we will keep analyzing and you will see it on Home. The check is only used if the reading succeeds.';

  @override
  String get processingLeave => 'Go to my home';

  @override
  String get processingDismiss => 'Got it';

  @override
  String get pendingFailedTitle => 'Could not analyze';

  @override
  String get failureNotAStatement =>
      'The file does not look like a statement. Your check was refunded: choose another PDF.';

  @override
  String get failureExtraction =>
      'We could not read your statement. Your check was refunded: try again.';

  @override
  String get failureInterrupted =>
      'The analysis was interrupted. Your check was refunded: try again.';

  @override
  String get pendingProcessingTitle => 'Analyzing…';

  @override
  String pendingProcessingBody(String card) {
    return '$card · you can close the app';
  }

  @override
  String get pendingAwaitingTitle => 'Ready to confirm';

  @override
  String get pendingAwaitingBody => 'Your % still need confirming';

  @override
  String get pendingCompletedTitle => 'New result';

  @override
  String pendingCompletedBody(String card) {
    return '$card · tap to see it';
  }

  @override
  String get pendingFollow => 'Continue';

  @override
  String homeGreetingMorning(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Good morning',
      'other': 'Good morning, $name',
    });
    return '$_temp0';
  }

  @override
  String homeGreetingAfternoon(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Good afternoon',
      'other': 'Good afternoon, $name',
    });
    return '$_temp0';
  }

  @override
  String homeGreetingEvening(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'Good evening',
      'other': 'Good evening, $name',
    });
    return '$_temp0';
  }

  @override
  String get homeTitle => 'Your cashback';

  @override
  String get homeProfileAria => 'Profile and settings';

  @override
  String homeFreeChecks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n free checks available',
      one: '1 free check available',
    );
    return '$_temp0';
  }

  @override
  String get homeEmptyTitle => 'Let us start with your card';

  @override
  String get homeEmptyCardPlaceholder => 'Your card';

  @override
  String get homeStep1Bold => 'Add your card';

  @override
  String get homeStep1Rest => ' with its categories and percentages.';

  @override
  String get homeStep2Bold => 'Upload your PDF';

  @override
  String get homeStep2Rest =>
      ' and in under a minute you will know if you were paid right.';

  @override
  String get homeAddMyCard => 'Add my card';

  @override
  String get homeNoChecksTitle => 'You have no checks yet';

  @override
  String get homeNoChecksBody =>
      'Every verdict from your bank will show up here.';

  @override
  String get homeGuidedSetup => 'I prefer the guided setup';

  @override
  String homeFreshBanner(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'none': 'All set. Here is everything you set up: your card, its categories and your first check.',
      'other':
          'All set, $name. Here is everything you set up: your card, its categories and your first check.',
    });
    return '$_temp0';
  }

  @override
  String get homeVerifyStatement => 'Check a statement';

  @override
  String get homeUsedFree => 'You used your free check';

  @override
  String get homeGetMore => 'Get more';

  @override
  String homeChecksAvailable(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n checks available',
      one: '1 check available',
    );
    return '$_temp0';
  }

  @override
  String get homeMyCard => 'My card';

  @override
  String get homeMyCards => 'My cards';

  @override
  String get homeTapToEdit => 'Tap to edit';

  @override
  String get homeAddAnotherCard => 'Add another card';

  @override
  String get homeAddCardTile => 'Add card';

  @override
  String homeCardMeta(String bank, String rate, String rules) {
    return '$bank · base $rate · $rules';
  }

  @override
  String homeEverythingElse(String rate) {
    return 'Everything else $rate';
  }

  @override
  String get homeFirstVerification => 'Your first check';

  @override
  String homeUncategorized(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n purchases have no category',
      one: '1 purchase has no category',
    );
    return '$_temp0 · review them for free';
  }

  @override
  String get homeLatestChecks => 'Latest checks';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeOffline => 'Offline. Showing saved data.';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navCategories => 'Categories';

  @override
  String get navProfile => 'Profile';

  @override
  String get navAria => 'Main navigation';

  @override
  String get cardBasicCaption => 'Basics';

  @override
  String get cardNameLabel => 'Card name';

  @override
  String get cardLast4Short => 'Last 4';

  @override
  String get cardRewardKindQuestion => 'What does it give you?';

  @override
  String get cardUnitCashback => 'Cash back';

  @override
  String get cardUnitPoints => 'Points or miles';

  @override
  String get cardBaseRateLabel => 'Base rate';

  @override
  String get cardBaseRateHelp =>
      'What any purchase outside a bonus category earns.';

  @override
  String get cardRulesTitle => 'Categories with a bonus rate';

  @override
  String get cardAddRule => '+ Add category';

  @override
  String get cardAddCap => '+ Monthly cap';

  @override
  String get cardAdvancedTitle => 'Advanced options';

  @override
  String get cardAdvancedSubtitle => 'Network, currency, audited program…';

  @override
  String get cardNetworkLabel => 'Network';

  @override
  String get cardOptionalTag => '(optional)';

  @override
  String get cardNetworkOther => 'Other';

  @override
  String get cardNetworkOtherHint => 'Network name';

  @override
  String get cardMainCurrency => 'Card\'s main currency';

  @override
  String get cardProgramLabel => 'Program to audit';

  @override
  String get cardProgramHelp =>
      'If your statement lists several programs (cash, points, miles), pick the one we check.';

  @override
  String get cardRewardCurrencyQuestion => 'Currency you receive cashback in';

  @override
  String get cardRewardDetect => 'Detect it';

  @override
  String get cardRewardCurrencyNote =>
      'If it differs from your purchases, we\'ll ask for the exchange rate when checking.';

  @override
  String get cardCurrencyOtherHint => 'Other code (3 letters)';

  @override
  String get cardDeleteAction => 'Delete card';

  @override
  String get cardDeleteNote => 'Its verification history is deleted too.';

  @override
  String get cardClose => 'Close';

  @override
  String get catalogNewCategory => '+ New category';

  @override
  String get catalogIntroTitle =>
      'Categories are the kinds of purchases your bank rewards most';

  @override
  String get catalogIntroBody =>
      'For example, 7% at supermarkets. Create them once and we use them across all your cards. No need to register merchants: AI knows «Farmacia Kielsa 61» is a pharmacy.';

  @override
  String get catalogQuickAdd => 'Add with one tap';

  @override
  String get catalogCreateOther => 'Create another category';

  @override
  String get catalogOptionalNote =>
      'Registering merchants is optional; it makes a purchase always land in the right category.';

  @override
  String get catalogByAi => 'By AI';

  @override
  String get catalogAddMerchant => '+ Add merchant';

  @override
  String get catalogMore => 'More actions';

  @override
  String catalogRuleTag(String card, String rate) {
    return '$card $rate';
  }
}
