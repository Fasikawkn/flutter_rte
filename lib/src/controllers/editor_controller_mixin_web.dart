import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_rte/src/controllers/editor_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

mixin PlatformSpecificMixin {
  ///
  String viewId = '';

  ///
  final String filePath = 'packages/flutter_rte/lib/assets/document.html';

  ///
  WebViewController get editorController =>
      throw Exception('webview controller does not exist on web.');

  ///
  set editorController(WebViewController controller) =>
      throw Exception('webview controller does not exist on web.');

  ///
  StreamSubscription<web.MessageEvent>? _eventSub;

  ///
  HtmlEditorController? _c;

  ///
  final jsonEncoder = const JsonEncoder();

  ///
  /// Helper function to run javascript and check current environment
  Future<void> evaluateJavascript({required Map<String, Object?> data}) async {
    if (_c == null) return;
    if (!(_c?.initialized ?? false) && data['type'] != 'toIframe: initEditor') {
      log('HtmlEditorController error:',
          error:
              'HtmlEditorController called an editor widget that\n does not exist.\n'
              'This may happen because the widget\n'
              'initialization has been called but not completed,\n'
              'or because the editor widget was destroyed.\n'
              'Method called: [${data['type']}]');
      return;
    }
    data['view'] = viewId;
    var json = jsonEncoder.convert(data);
    web.window.postMessage(json.toJS, '*'.toJS);
  }

  ///
  Future<void> init(
      BuildContext initBC, double initHeight, HtmlEditorController c) async {
    await _eventSub?.cancel();
    _eventSub = web.window.onMessage.listen((event) {
      c.processEvent((event.data as JSString).toDart);
    }, onError: (e, s) {
      log('Event stream error: ${e.toString()}');
      log('Stack trace: ${s.toString()}');
    }, onDone: () {
      log('Event stream done.');
    });
    final iframe = web.HTMLIFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      // ignore: unsafe_html, necessary to load HTML string
      ..srcdoc = (await c.getInitialContent()).toJS
      ..style.border = 'none'
      ..style.overflow = 'hidden'
      ..id = viewId
      ..onLoad.listen((event) async {
        var data = <String, Object>{'type': 'toIframe: initEditor'};
        data['view'] = viewId;
        var jsonStr = jsonEncoder.convert(data);
        web.window.postMessage(jsonStr.toJS, '*'.toJS);
      });
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) => iframe);
  }

  ///
  void dispose() {
    _eventSub?.cancel();
  }

  ///
  Widget view(HtmlEditorController controller) {
    _c = controller;
    return HtmlElementView(viewType: viewId);
  }
}
