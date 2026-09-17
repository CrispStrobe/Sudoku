import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'technique_solver.dart';

String techniqueLabel(BuildContext context, Technique t) {
  final l10n = AppLocalizations.of(context)!;
  switch (t) {
    case Technique.nakedSingle:
      return l10n.techniqueNakedSingle;
    case Technique.hiddenSingle:
      return l10n.techniqueHiddenSingle;
    case Technique.lockedCandidates:
      return l10n.techniqueLockedCandidates;
    case Technique.nakedPair:
      return l10n.techniqueNakedPair;
    case Technique.nakedTriple:
      return l10n.techniqueNakedTriple;
    case Technique.hiddenPair:
      return l10n.techniqueHiddenPair;
    case Technique.xWing:
      return l10n.techniqueXWing;
    case Technique.guess:
      return l10n.techniqueNextStep;
  }
}
