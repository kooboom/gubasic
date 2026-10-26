/// Runs a GuBASIC project's form (docs/DESIGN.md D79): reads the project,
/// connects the interpreter to `gubasic_runtime` and shows the run window.
/// The IDE's run window and the player app both use it, so a program runs
/// the same in both.
library;

export 'src/app_view.dart';
export 'src/bundle.dart';
export 'src/fit_view.dart';
export 'src/form_window.dart';
export 'src/pictures.dart';
export 'src/player_strings.dart';
export 'src/project.dart';
export 'src/run_host.dart';
export 'src/run_session.dart';
export 'src/run_window.dart';
