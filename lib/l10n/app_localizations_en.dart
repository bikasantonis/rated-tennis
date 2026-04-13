// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RATED';

  @override
  String get appTitleFull => 'RATED — Tennis Rankings';

  @override
  String get navHome => 'Home';

  @override
  String get navLeaderboard => 'Leaderboard';

  @override
  String get navMatches => 'Matches';

  @override
  String get navTournaments => 'Tournaments';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionCreate => 'Create';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionDecline => 'Decline';

  @override
  String get actionAccept => 'Accept';

  @override
  String get actionDispute => 'Dispute';

  @override
  String get actionRegister => 'Register';

  @override
  String get actionRequest => 'Request';

  @override
  String get actionChange => 'Change';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionSignIn => 'Sign In';

  @override
  String get actionCreateAccount => 'Create Account';

  @override
  String get actionSendRequest => 'Send request';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNotLoggedIn => 'Not logged in.';

  @override
  String get errorProfileNotFound => 'Profile not found.';

  @override
  String get errorTournamentNotFound => 'Tournament not found.';

  @override
  String get errorCouldNotLoadHistory => 'Could not load rating history.';

  @override
  String get errorCouldNotLoadMatches => 'Could not load matches.';

  @override
  String get errorSearchFailed => 'Search failed.';

  @override
  String get errorPickDate => 'Please choose a proposed date & time.';

  @override
  String get errorPickStartDate => 'Please pick a start date.';

  @override
  String get errorAcceptPrivacy =>
      'Please accept the Privacy Policy to continue.';

  @override
  String get onboardingTitle1 => 'Track Your Game';

  @override
  String get onboardingBody1 =>
      'Get your personal rating based on real match results.';

  @override
  String get onboardingTitle2 => 'Challenge Players';

  @override
  String get onboardingBody2 =>
      'Find and schedule matches with players at your level.';

  @override
  String get onboardingTitle3 => 'Compete & Climb';

  @override
  String get onboardingBody3 =>
      'Enter tournaments, track your progress, and rise through the ranks.';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get loginTabLogin => 'Login';

  @override
  String get loginTabRegister => 'Register';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginDisplayNameLabel => 'Display name';

  @override
  String get loginPasswordShow => 'Show password';

  @override
  String get loginPasswordHide => 'Hide password';

  @override
  String get loginContinueGoogle => 'Continue with Google';

  @override
  String get loginContinueApple => 'Continue with Apple';

  @override
  String get loginEmailConfirmation =>
      'Check your email to confirm your account.';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordDialogTitle => 'Reset password';

  @override
  String get forgotPasswordDialogBody =>
      'Enter your email and we\'ll send you a reset link.';

  @override
  String get forgotPasswordSend => 'Send reset link';

  @override
  String get forgotPasswordSuccess =>
      'Check your email for a password reset link.';

  @override
  String get loginPrivacyConsent => 'I agree to the Privacy Policy';

  @override
  String get questionnaireTitle => 'Tell us about yourself';

  @override
  String get questionnaireGetMyRating => 'Get my rating';

  @override
  String get questionnaireFrequencyTitle => 'How often do you play?';

  @override
  String get questionnaireFrequencyRarely => 'Rarely';

  @override
  String get questionnaireFrequencyMonthly => 'Monthly';

  @override
  String get questionnaireFrequencyWeekly => 'Weekly';

  @override
  String get questionnaireFrequencyMultiple => 'Multiple times a week';

  @override
  String get questionnaireLevelTitle => 'How would you rate yourself?';

  @override
  String get questionnaireLevelBeginner => 'Beginner';

  @override
  String get questionnaireLevelIntermediate => 'Intermediate';

  @override
  String get questionnaireLevelAdvanced => 'Advanced';

  @override
  String get questionnaireLevelCompetitive => 'Competitive';

  @override
  String get questionnaireYearsTitle => 'How many years have you been playing?';

  @override
  String get questionnaireSurfaceTitle => 'Preferred surface?';

  @override
  String get questionnaireSurfaceClay => 'Clay';

  @override
  String get questionnaireSurfaceHard => 'Hard';

  @override
  String get questionnaireSurfaceGrass => 'Grass';

  @override
  String get questionnaireSurfaceIndoor => 'Indoor';

  @override
  String get questionnaireSurfaceNoPreference => 'No preference';

  @override
  String get questionnaireTournamentTitle =>
      'Have you competed in official tournaments?';

  @override
  String get questionnaireTournamentYes => 'Yes';

  @override
  String get questionnaireTournamentNo => 'No';

  @override
  String get homeTitle => 'RATED';

  @override
  String get homeRecentMatches => 'Recent Matches';

  @override
  String get homeNoMatches =>
      'No confirmed matches yet.\nSubmit your first result!';

  @override
  String get homeSubmitMatch => 'Submit Match';

  @override
  String get homeScheduleMatch => 'Request Match';

  @override
  String homeMatchWonVs(String opponent) {
    return 'Won vs $opponent';
  }

  @override
  String homeMatchLostVs(String opponent) {
    return 'Lost vs $opponent';
  }

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get leaderboardAllClubs => 'All clubs';

  @override
  String get leaderboardNoPlayers => 'No players found.';

  @override
  String leaderboardPage(int page) {
    return 'Page $page';
  }

  @override
  String get leaderboardFilterByClub => 'Filter by club';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileMyProfile => 'My Profile';

  @override
  String get profileEloHistory => 'Rating History';

  @override
  String get profileMatchHistory => 'Match History';

  @override
  String get profileNoEloHistory => 'No rating history yet.';

  @override
  String get profileNoMatches => 'No confirmed matches yet.';

  @override
  String get profileEditDisplayName => 'Edit display name';

  @override
  String get profileDisplayNameLabel => 'Display name';

  @override
  String get profileStatPlayed => 'Played';

  @override
  String get profileStatWon => 'Won';

  @override
  String get profileStatWinPct => 'Win %';

  @override
  String get profileStatElo => 'Rating';

  @override
  String get submitMatchTitle => 'Submit Match Result';

  @override
  String get submitMatchSearchOpponent => 'Search opponent…';

  @override
  String get submitMatchNoResults => 'No players found.';

  @override
  String get submitMatchOutcomeWon => 'I won';

  @override
  String get submitMatchOutcomeLost => 'Opponent won';

  @override
  String submitMatchSet(int number) {
    return 'Set $number';
  }

  @override
  String get submitMatchAddSet => 'Add set';

  @override
  String get submitMatchDateLabel => 'When was it played?';

  @override
  String get submitMatchSubmit => 'Submit result';

  @override
  String get submitMatchSuccess => 'Match submitted — awaiting confirmation';

  @override
  String get submitMatchScoreTitle => 'Score';

  @override
  String get submitMatchFormatTitle => 'Match Format';

  @override
  String get submitMatchSuperTiebreak => 'Super tie-break';

  @override
  String get submitMatchFormatBo3Standard => 'Best of 3 — 3rd set';

  @override
  String get submitMatchFormatBo3SuperTb => 'Best of 3 — Super tie-break';

  @override
  String get submitMatchFormatBo3Mini3rd => 'Best of 3 mini-sets — 3rd set';

  @override
  String get submitMatchFormatBo3MiniSuper =>
      'Best of 3 mini-sets — Super tie-break';

  @override
  String get submitMatchFormatOneFullSet => '1 full set';

  @override
  String get submitMatchFormatOneMiniSet => '1 mini-set';

  @override
  String scoreInvalidSet(int number) {
    return 'Set $number score is invalid';
  }

  @override
  String get scoreMatchIncomplete => 'Match is incomplete — add more sets';

  @override
  String scoreWinnerMustWin(int sets) {
    return 'Winner must win $sets sets';
  }

  @override
  String get scoreExtraSets => 'Match already decided — remove extra sets';

  @override
  String get inboxTitle => 'Matches';

  @override
  String get inboxTabToConfirm => 'To Confirm';

  @override
  String get inboxTabRequests => 'Requests';

  @override
  String get inboxNoPendingResults =>
      'No matches waiting for your confirmation.';

  @override
  String get inboxNoPendingRequests => 'No pending match requests.';

  @override
  String get inboxConfirmSuccess => 'Match confirmed — Rating updated!';

  @override
  String get inboxRequestAccepted => 'Request accepted!';

  @override
  String get inboxRequestDeclined => 'Request declined.';

  @override
  String get inboxDisputeTitle => 'Dispute result';

  @override
  String get inboxDisputeEnterScore => 'Enter the correct score:';

  @override
  String get inboxDisputeSubmit => 'Submit dispute';

  @override
  String inboxProposedDate(String date) {
    return 'Proposed: $date';
  }

  @override
  String inboxWonDef(String winner, String loser) {
    return '$winner def. $loser';
  }

  @override
  String inboxPlayedOn(String date) {
    return 'Played $date';
  }

  @override
  String get scheduleTitle => 'Schedule a Match';

  @override
  String get scheduleProposedDateTime => 'Proposed date & time';

  @override
  String get schedulePickDateTime => 'Pick a date & time';

  @override
  String get scheduleVenueLabel => 'Venue (optional)';

  @override
  String get scheduleVenueHint => 'e.g. Court 3, City Club';

  @override
  String get scheduleMessageLabel => 'Message (optional)';

  @override
  String get scheduleMessageHint => 'e.g. \"Warm-up at 09:45?\"';

  @override
  String get scheduleNoPlayersInRange =>
      'No players found in your rating range.';

  @override
  String get scheduleRequestSent => 'Match request sent!';

  @override
  String get tournamentsTitle => 'Tournaments';

  @override
  String get tournamentsTabOpen => 'Open';

  @override
  String get tournamentsTabInProgress => 'In Progress';

  @override
  String get tournamentsTabPast => 'Past';

  @override
  String get tournamentsTabAll => 'All';

  @override
  String get tournamentsNone => 'No tournaments found.';

  @override
  String get tournamentStatusOpen => 'Open';

  @override
  String get tournamentStatusLive => 'Live';

  @override
  String get tournamentStatusCompleted => 'Completed';

  @override
  String get tournamentStatusDraft => 'Draft';

  @override
  String get tournamentStatusCancelled => 'Cancelled';

  @override
  String get tournamentFormatSingleElim => 'Single Elimination';

  @override
  String get tournamentFormatRoundRobin => 'Round Robin';

  @override
  String tournamentStarts(String date) {
    return 'Starts $date';
  }

  @override
  String tournamentEloRange(String min, String max) {
    return 'Rating $min – $max';
  }

  @override
  String get tournamentDetailTitle => 'Tournament';

  @override
  String get tournamentDetailParticipants => 'Participants';

  @override
  String get tournamentDetailNoParticipants => 'No approved participants yet.';

  @override
  String get tournamentDetailRegisterSuccess => 'Registration submitted!';

  @override
  String get tournamentDetailFormatLabel => 'Format';

  @override
  String get tournamentDetailStartsLabel => 'Starts';

  @override
  String get tournamentDetailEndsLabel => 'Ends';

  @override
  String get tournamentDetailMaxPlayersLabel => 'Max players';

  @override
  String get tournamentDetailEloRangeLabel => 'Rating range';

  @override
  String get tournamentDetailMultiplierLabel => 'Rating multiplier';

  @override
  String get organizerTitle => 'My Tournaments';

  @override
  String get organizerTabOpen => 'Open';

  @override
  String get organizerTabInProgress => 'In Progress';

  @override
  String get organizerTabCompleted => 'Completed';

  @override
  String get organizerManage => 'Manage';

  @override
  String get organizerCreateTitle => 'Create Tournament';

  @override
  String get organizerNameLabel => 'Tournament name';

  @override
  String get organizerDescLabel => 'Description (optional)';

  @override
  String get organizerFormatLabel => 'Format';

  @override
  String get organizerEloMinLabel => 'Rating min';

  @override
  String get organizerEloMaxLabel => 'Rating max';

  @override
  String get organizerMaxPlayersLabel => 'Max players';

  @override
  String get organizerMultiplierLabel => 'Rating multiplier';

  @override
  String get organizerPickStartDate => 'Pick start date';

  @override
  String get organizerCreateButton => 'Create tournament';

  @override
  String get organizerCreateSuccess => 'Tournament created!';

  @override
  String get organizerMyTournaments => 'My Tournaments';

  @override
  String get organizerNoTournaments => 'No tournaments yet.';

  @override
  String get organizerNoRegistrations => 'No registrations yet.';

  @override
  String get organizerGenerateBracket => 'Generate Bracket & Start';

  @override
  String get organizerGenerateBracketSuccess =>
      'Bracket generated — tournament is live!';

  @override
  String get organizerOpenRegistration => 'Open Registration';

  @override
  String get organizerCompleteTourn => 'Mark as Completed';

  @override
  String get organizerBracketSection => 'Bracket';

  @override
  String get organizerManageTournament => 'Manage Tournament';

  @override
  String get organizerTabRegistrations => 'Registrations';

  @override
  String get organizerTabStatusControls => 'Status';

  @override
  String get organizerRegStatusPending => 'Pending';

  @override
  String get organizerRegStatusApproved => 'Approved';

  @override
  String get organizerRegStatusRejected => 'Rejected';

  @override
  String get organizerOpenRegistrationDesc =>
      'Allow players to sign up for this tournament.';

  @override
  String get organizerGenerateBracketDesc =>
      'Seed participants by rating and generate the single-elimination bracket. This will also start the tournament.';

  @override
  String get organizerCompleteTournDesc =>
      'Mark the tournament as finished. This cannot be undone.';

  @override
  String get organizerTournamentCompleted => 'Tournament completed!';

  @override
  String get organizerBracketNotGeneratedYet =>
      'Bracket will appear here once you generate it.';

  @override
  String get settingsOrganizerSection => 'Organiser';

  @override
  String get settingsRequestOrganizer => 'Request Organiser Rights';

  @override
  String get settingsRequestOrganizerSub =>
      'Apply to create and manage tournaments.';

  @override
  String get settingsOrganizerRequestPending => 'Request pending…';

  @override
  String get settingsOrganizerRequestPendingSub =>
      'An admin will review your request shortly.';

  @override
  String get settingsOrganizerRequestDenied => 'Request not approved';

  @override
  String get settingsOrganizerRequestDeniedSub =>
      'You may submit a new request.';

  @override
  String get settingsIsOrganizer => 'You are an Organiser';

  @override
  String get settingsIsOrganizerSub => 'You can create and manage tournaments.';

  @override
  String get settingsOrganizerRequestConfirmTitle =>
      'Request Organiser Rights?';

  @override
  String get settingsOrganizerRequestConfirmBody =>
      'An admin will review your request and notify you by push and email once a decision is made.';

  @override
  String get settingsOrganizerRequestSuccess => 'Request submitted!';

  @override
  String get adminTitle => 'Admin Panel';

  @override
  String get adminTabDisputes => 'Match Disputes';

  @override
  String get adminTabRequests => 'Organiser Requests';

  @override
  String get adminRequestsNone => 'No pending requests.';

  @override
  String get adminRequestsApprove => 'Approve';

  @override
  String get adminRequestsDeny => 'Deny';

  @override
  String get adminRequestsApproveSuccess => 'Organiser rights granted.';

  @override
  String get adminRequestsDenySuccess => 'Request declined.';

  @override
  String get bracketTitle => 'Bracket';

  @override
  String get bracketNotGenerated => 'Bracket has not been generated yet.';

  @override
  String bracketRound(int n) {
    return 'Round $n';
  }

  @override
  String get bracketSemifinal => 'Semifinal';

  @override
  String get bracketFinal => 'Final';

  @override
  String get bracketBye => 'Bye';

  @override
  String get bracketRecordResult => 'Record result';

  @override
  String get bracketSelectWinner => 'Select winner';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsSectionLocation => 'Location';

  @override
  String get settingsLocationEnable => 'Enable location features';

  @override
  String get settingsLocationEnableSub => 'Find nearby tournaments and players';

  @override
  String get settingsLocationUnknownArea => 'Your area';

  @override
  String get settingsLocationNotifyNearby =>
      'Notify me about nearby tournaments';

  @override
  String get settingsLocationNotifyNearbySub =>
      'Get a push notification when a tournament opens near you';

  @override
  String get settingsLocationRadius => 'Search radius';

  @override
  String settingsLocationRadiusKm(int km) {
    return '$km km';
  }

  @override
  String get settingsLocationRevokeTitle => 'Remove location data?';

  @override
  String get settingsLocationRevokeBody =>
      'This will delete your stored location, disable nearby features, and stop nearby-tournament notifications.';

  @override
  String get settingsLocationRevokeConfirm => 'Remove';

  @override
  String get settingsLocationConsentTitle => 'Location features';

  @override
  String get settingsLocationConsentBody =>
      'RATED will use your device location to:\n\n• Show tournaments near you in the Tournaments tab\n• Show players near you on the Leaderboard\n• Notify you when a tournament opens near your home area\n\nYou can withdraw this consent at any time in Settings.';

  @override
  String get settingsLocationConsentPrivacyNote =>
      'Your location is rounded to ~1 km precision and stored securely. It is never shared with other users without your consent.';

  @override
  String get settingsLocationConsentAccept => 'Enable location';

  @override
  String get locationPermissionDenied =>
      'Location permission was denied. You can enable it in your device settings.';

  @override
  String get locationServiceDisabled =>
      'Location services are disabled. Please enable them in your device settings.';

  @override
  String get tournamentsTabNearMe => 'Near Me';

  @override
  String tournamentDistanceKm(String km) {
    return '$km km';
  }

  @override
  String tournamentsNearMeEmpty(int km) {
    return 'No tournaments found near you within $km km.';
  }

  @override
  String get tournamentsLocationPromptTitle => 'Find nearby tournaments';

  @override
  String get tournamentsLocationPromptBody =>
      'Enable location features in Settings to see tournaments near you.';

  @override
  String get tournamentsGoToSettings => 'Go to Settings';

  @override
  String get leaderboardNearMe => 'Near Me';

  @override
  String leaderboardNearMeEmpty(int km) {
    return 'No players found near you within $km km.';
  }

  @override
  String leaderboardDistanceKm(String km) {
    return '$km km';
  }

  @override
  String get organizerCityLabel => 'City (optional)';

  @override
  String get organizerCountryLabel => 'Country code (e.g. GR)';

  @override
  String get organizerUseMyLocation => 'Use my location';

  @override
  String get organizerLocationSet => 'Location set';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsChooseLanguage => 'Choose language';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Permanently deletes all your data (GDPR Art. 17)';

  @override
  String get settingsDeleteAccountTitle => 'Delete account?';

  @override
  String get settingsDeleteAccountBody =>
      'This will permanently delete your profile and all match data. This action cannot be undone.';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get disputeTitle => 'Dispute Resolution';

  @override
  String get disputeNoDisputes => 'No disputed matches.';

  @override
  String get disputeOriginalScore => 'Original score';

  @override
  String get disputeDisputedScore => 'Disputed score';

  @override
  String get disputeKeepOriginal => 'Keep original';

  @override
  String get disputeAcceptDispute => 'Accept dispute';

  @override
  String get disputeAcceptedSuccess => 'Dispute accepted — Rating updated.';

  @override
  String get disputeOverriddenSuccess =>
      'Original score kept — Rating updated.';

  @override
  String get tierBeginner => 'Beginner';

  @override
  String get tierBronze => 'Bronze';

  @override
  String get tierSilver => 'Silver';

  @override
  String get tierGold => 'Gold';

  @override
  String get tierPlatinum => 'Platinum';

  @override
  String get tierElite => 'Elite';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsChangePasswordDialogTitle => 'Change password';

  @override
  String get settingsChangePasswordNew => 'New password';

  @override
  String get settingsChangePasswordConfirm => 'Confirm new password';

  @override
  String get settingsChangePasswordMismatch => 'Passwords do not match.';

  @override
  String get settingsChangePasswordTooShort =>
      'Password must be at least 8 characters.';

  @override
  String get settingsChangePasswordSuccess => 'Password updated successfully.';

  @override
  String eloLabel(String value) {
    return 'Rating $value';
  }

  @override
  String setLabel(int number) {
    return 'Set $number';
  }

  @override
  String pageLabel(int number) {
    return 'Page $number';
  }
}
