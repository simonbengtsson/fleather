// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/editor_input_client_mixin.dart';
import 'package:fleather/src/widgets/text_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_delta/quill_delta.dart';

var delta = Delta()..insert('This House Is A Circus\n');

class EditorSandBox {
  factory EditorSandBox({
    required WidgetTester tester,
    FocusNode? focusNode,
    ParchmentDocument? document,
    FleatherThemeData? fleatherTheme,
    bool autofocus = false,
    FakeSpellCheckService? spellCheckService,
    FleatherEmbedBuilder embedBuilder = defaultFleatherEmbedBuilder,
  }) {
    focusNode ??= FocusNode();
    document ??= ParchmentDocument.fromDelta(delta);
    var controller = FleatherController(document: document);

    Widget widget = _FleatherSandbox(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      spellCheckService: spellCheckService,
      embedBuilder: embedBuilder,
    );

    if (fleatherTheme != null) {
      widget = FleatherTheme(data: fleatherTheme, child: widget);
    }
    widget = MaterialApp(home: widget);

    return EditorSandBox._(tester, focusNode, document, controller, widget,
        spellCheckService: spellCheckService);
  }

  EditorSandBox._(
      this.tester, this.focusNode, this.document, this.controller, this.widget,
      {this.spellCheckService});

  final WidgetTester tester;
  final FocusNode focusNode;
  final ParchmentDocument document;
  final FleatherController controller;
  final Widget widget;
  final FakeSpellCheckService? spellCheckService;

  TextSelection get selection => controller.selection;

  Future<void> unfocus() {
    focusNode.unfocus();
    return tester.pumpAndSettle();
  }

  Future<void> updateSelection({required int base, required int extent}) {
    controller.updateSelection(
      TextSelection(baseOffset: base, extentOffset: extent),
    );
    return tester.pumpAndSettle();
  }

  Future<void> disable() {
    final state =
        tester.state(find.byType(_FleatherSandbox)) as _FleatherSandboxState;
    state.disable();
    return tester.pumpAndSettle();
  }

  Future<void> pump() async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  Future<void> tap() async {
    await tester.tap(find.byType(RawEditor).first);
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
  }

  Future<void> pumpAndTap() async {
    await pump();
    await tap();
  }

  Future<void> tapHideKeyboardButton() async {
    await tapButtonWithIcon(Icons.keyboard_hide);
  }

  Future<void> tapButtonWithIcon(IconData icon) async {
    await tester.tap(find.widgetWithIcon(RawMaterialButton, icon));
    await tester.pumpAndSettle();
  }

  Future<void> tapButtonWithText(String text) async {
    await tester.tap(find.widgetWithText(RawMaterialButton, text));
    await tester.pumpAndSettle();
  }

  RawMaterialButton findButtonWithIcon(IconData icon) {
    final button = tester.widget(find.widgetWithIcon(RawMaterialButton, icon))
        as RawMaterialButton;
    return button;
  }

  RawMaterialButton findButtonWithText(String text) {
    final button = tester.widget(find.widgetWithText(RawMaterialButton, text))
        as RawMaterialButton;
    return button;
  }

  Finder findSelectionHandles() => find.byType(SelectionHandleOverlay);

  Future<void> enterText(TextEditingValue text) async {
    return TestAsyncUtils.guard<void>(() async {
      await showKeyboard();
      tester.binding.testTextInput.updateEditingValue(text);
      await tester.idle();
    });
  }

  Future<void> showKeyboard() async {
    return TestAsyncUtils.guard<void>(() async {
      final editor = tester.state<RawEditorState>(find.byType(RawEditor));
      editor.requestKeyboard();
      await pump();
    });
  }
}

class _FleatherSandbox extends StatefulWidget {
  const _FleatherSandbox({
    Key? key,
    required this.controller,
    required this.focusNode,
    this.autofocus = false,
    this.spellCheckService,
    this.embedBuilder = defaultFleatherEmbedBuilder,
  }) : super(key: key);

  final FleatherController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final FakeSpellCheckService? spellCheckService;
  final FleatherEmbedBuilder embedBuilder;

  @override
  _FleatherSandboxState createState() => _FleatherSandboxState();
}

class _FleatherSandboxState extends State<_FleatherSandbox> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FleatherField(
        embedBuilder: widget.embedBuilder,
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: !_enabled,
        autofocus: widget.autofocus,
        spellCheckConfiguration: widget.spellCheckService != null
            ? SpellCheckConfiguration(
                spellCheckService: widget.spellCheckService,
              )
            : null,
      ),
    );
  }

  void disable() {
    setState(() {
      _enabled = false;
    });
  }
}

class TestUpdateWidget extends StatefulWidget {
  const TestUpdateWidget(
      {Key? key,
      required this.focusNodeAfterChange,
      this.testField = false,
      this.document})
      : super(key: key);

  final FocusNode focusNodeAfterChange;
  final bool testField;
  final ParchmentDocument? document;

  @override
  State<StatefulWidget> createState() => TestUpdateWidgetState();
}

class TestUpdateWidgetState extends State<TestUpdateWidget> {
  FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () =>
                setState(() => focusNode = widget.focusNodeAfterChange),
            child: const Text('Change state'),
          ),
          widget.testField
              ? FleatherField(
                  controller: FleatherController(document: widget.document),
                  focusNode: focusNode,
                )
              : FleatherEditor(
                  controller: FleatherController(document: widget.document),
                  focusNode: focusNode,
                ),
        ],
      );
}

RawEditorStateTextInputClientMixin getInputClient() =>
    (find.byType(RawEditor).evaluate().single as StatefulElement).state
        as RawEditorStateTextInputClientMixin;

class FakeSpellCheckService implements SpellCheckService {
  Future<List<SuggestionSpan>?> Function(Locale local, String text)? stub;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
      Locale locale, String text) async {
    return await (stub ?? (() => Future.value(null)))(locale, text);
  }
}
