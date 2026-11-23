import 'dart:async';
import 'dart:js_interop';

@JS('document.documentElement')
external _HtmlElement get _root;

@JS('document.querySelector')
external JSObject? _query(JSString selector);

@JS('document.createElement')
external JSObject _create(JSString tag);

extension type _HtmlElement(JSObject _) implements JSObject {
  external void setAttribute(JSString name, JSString value);
  external _CssStyle get style;
}

extension type _CssStyle(JSObject _) implements JSObject {
  external void setProperty(JSString property, JSString value);
}

extension type _Node(JSObject _) implements JSObject {
  external JSObject? get shadowRoot;
  external JSObject? querySelector(JSString selector);
  external void appendChild(JSObject node);
  external void setAttribute(JSString name, JSString value);
  external set textContent(JSString value);
}

void applyDocumentScheme(bool dark) {
  final scheme = (dark ? 'dark' : 'light').toJS;
  _root.setAttribute('data-wishly-theme'.toJS, scheme);
  _root.style.setProperty('color-scheme'.toJS, scheme);
  _root.style.setProperty('background-color'.toJS, (dark ? '#1A1410' : '#F3EEE6').toJS);
  _paintInputs();
  for (final wait in const [Duration(milliseconds: 400), Duration(seconds: 2)]) {
    unawaited(Future<void>.delayed(wait, _paintInputs));
  }
}

void _paintInputs() {
  final found = _query('flt-glass-pane'.toJS);
  if (found == null) return;
  final pane = _Node(found);
  final root = _Node(pane.shadowRoot ?? found);
  final css = 'input,textarea{background:transparent!important;color:transparent!important;-webkit-text-fill-color:transparent!important;caret-color:transparent!important;text-shadow:none!important;}';
  final existing = root.querySelector('#wishly-input-color'.toJS);
  if (existing != null) {
    _Node(existing).textContent = css.toJS;
    return;
  }
  final style = _Node(_create('style'.toJS));
  style.textContent = css.toJS;
  style.setAttribute('id'.toJS, 'wishly-input-color'.toJS);
  root.appendChild(style);
}
