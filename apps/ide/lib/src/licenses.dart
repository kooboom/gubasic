import 'package:flutter/services.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// The licences the IDE shows besides Flutter's (docs/DESIGN.md D120):
/// GuBASIC's, and those of the three fonts it carries.
void addIdeLicenses() => addGubasicLicenses({
  pretendardFont: () => rootBundle.loadString('fonts/pretendard/LICENSE.txt'),
  d2codingFont: () => rootBundle.loadString('fonts/d2coding/OFL.txt'),
  nanumGothicFont: () => rootBundle.loadString('fonts/nanumgothic/OFL.txt'),
});
