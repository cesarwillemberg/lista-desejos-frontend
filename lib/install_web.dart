import 'dart:js_interop';

@JS('wishlyCanInstall')
external JSBoolean wishlyCanInstall();

@JS('wishlyPromptInstall')
external void wishlyPromptInstall();

bool canInstallApp() {
  try {
    return wishlyCanInstall().toDart;
  } catch (_) {
    return false;
  }
}

void promptInstall() {
  try {
    wishlyPromptInstall();
  } catch (_) {}
}
