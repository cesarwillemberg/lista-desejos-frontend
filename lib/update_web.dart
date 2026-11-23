import 'dart:js_interop';

@JS('wishlyApplyUpdate')
external JSPromise<JSAny?> wishlyApplyUpdate();

Future<void> applyAppUpdate() async {
  try {
    await wishlyApplyUpdate().toDart;
  } catch (_) {}
}
