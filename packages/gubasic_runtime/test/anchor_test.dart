import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

void main() {
  GbControlState control(String name, String anchor) =>
      GbControlState(name, GbControlKind.button, {
        'Caption': name,
        'Left': 100,
        'Top': 50,
        'Width': 80,
        'Height': 20,
        'Anchor': anchor,
      });

  GbFormModel model(List<GbControlState> controls) => GbFormModel(
    form: {'Caption': '', 'Width': 300, 'Height': 200},
    controls: controls,
    onEvent: (_, _) {},
  );

  GbRect rect(GbControlState c) => (
    left: c.integer('Left'),
    top: c.integer('Top'),
    width: c.integer('Width'),
    height: c.integer('Height'),
  );

  test('gbAnchored keeps the distance to the edges named, stretches '
      'between two, and centres with none, rounded down', () {
    const base = (left: 100, top: 50, width: 80, height: 20);
    GbRect at(String anchor, int width, int height) => gbAnchored(
      base,
      anchor,
      baseWidth: 300,
      baseHeight: 200,
      width: width,
      height: height,
    );
    expect(at('Left Top', 400, 260), base);
    expect(at('Right Bottom', 400, 260), (
      left: 200,
      top: 110,
      width: 80,
      height: 20,
    ));
    expect(at('Left Right', 400, 260), (
      left: 100,
      top: 80,
      width: 180,
      height: 20,
    ));
    expect(at('Left Top Right Bottom', 250, 150), (
      left: 100,
      top: 50,
      width: 30,
      height: 0,
    ));
    expect(at('', 301, 199), (left: 100, top: 49, width: 80, height: 20));
  });

  test('the user resizing the form moves the controls, and back as it was '
      'puts them back exactly', () {
    final ok = control('btnOk', 'Right Bottom');
    final middle = control('lblMiddle', '');
    final m = model([ok, middle]);
    m.resize(401, 263);
    expect(rect(ok), (left: 201, top: 113, width: 80, height: 20));
    expect(rect(middle), (left: 150, top: 81, width: 80, height: 20));
    m.resize(299, 197);
    m.resize(300, 200);
    expect(rect(ok), (left: 100, top: 50, width: 80, height: 20));
    expect(rect(middle), (left: 100, top: 50, width: 80, height: 20));
  });

  test('a control the program places is kept there, and follows its Anchor '
      'from there; the form\'s Width set by the program moves them too', () {
    final ok = control('btnOk', 'Right Bottom');
    final m = model([ok]);
    m.resize(400, 200);
    m.setProperty('btnOk', 'Left', 10);
    expect(rect(ok).left, 10);
    m.setProperty(null, 'Width', 450);
    expect(rect(ok).left, 60);
    expect(m.form.integer('Width'), 450);
    m.setProperty('btnOk', 'Anchor', 'Left Top');
    m.resize(300, 200);
    expect(rect(ok).left, 60);
  });

  testWidgets('the form view shows the controls where the model puts them', (
    tester,
  ) async {
    final ok = control('btnOk', 'Right Bottom');
    final m = model([ok]);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: GbFormView(model: m),
        ),
      ),
    );
    m.resize(500, 300);
    await tester.pump();
    expect(tester.getSize(find.byType(GbFormView)), const Size(500, 300));
    expect(tester.getTopLeft(find.byType(GbButton)), const Offset(300, 150));
  });
}
