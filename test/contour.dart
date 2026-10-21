//@TestOn("dartium")
import 'dart:html' as html;

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';

//import "package:test/test.dart";
import 'polygon_data.dart' as data;

final html.InputElement gScale =
    html.document.querySelector('#scale') as html.InputElement;

final html.CanvasElement gCanvas =
    html.document.querySelector('#canvas') as html.CanvasElement;
final int gWidth = gCanvas.width!;
final int gHeight = gCanvas.height!;
final html.CanvasRenderingContext2D gContext = gCanvas.context2D;

void drawContour(List<vm.Vector2> contour, String color) {
  gContext
    ..beginPath()
    ..moveTo(contour[0].x, contour[0].y);
  for (vm.Vector2 v in contour.sublist(1)) {
    gContext.lineTo(v.x, v.y);
  }
  gContext
    ..closePath()
    ..strokeStyle = color
    ..lineWidth = 5
    ..stroke();
}

void drawMovement(
  List<vm.Vector2> contour,
  List<vm.Vector2> movement,
  double scale,
  String color,
) {
  assert(contour.length == movement.length);
  gContext.beginPath();

  for (int i = 0; i < contour.length; i++) {
    gContext
      ..moveTo(contour[i].x, contour[i].y)
      ..lineTo(
        contour[i].x + scale * movement[i].x,
        contour[i].y + scale * movement[i].y,
      );
  }
  gContext
    ..closePath()
    ..strokeStyle = color
    ..lineWidth = 5
    ..stroke();
}

void clearCanvas() {
  gContext
    ..fillStyle = "red"
    ..fillRect(0, 0, gWidth, gHeight);
}

Map<String, List<vm.Vector2>> gContours = {
  "Building": data.makeContour(data.buildingData, 4.0, 16.0, -600.0, -70.0),
  "Bird": data.makeContour(data.birdData, 40.0, 40.0, 12.0, 12.0),
};

Map<String, List<vm.Vector2>> gGradients = {};

void main() {
  for (String k in gContours.keys) {
    gContours[k] = filterDupsAndColinear(gContours[k]!);
    gGradients[k] = getContourGradient(gContours[k]!);
  }

  void animate(num timeMs) {
    clearCanvas();
    html.window.animationFrame.then(animate);
    String k = "Building";
    List<vm.Vector2> c = gContours[k]!;
    List<vm.Vector2> g = gGradients[k]!;
    drawContour(c, "blue");
    drawMovement(c, g, 50.0, "green");
    List<vm.Vector2> scaled = List.generate(c.length, (i) => vm.Vector2.zero());
    for (int i = 0; i < c.length; ++i) {
      scaled[i] = c[i] + g[i].scaled(gScale.valueAsNumber!.toDouble());
    }
    drawContour(scaled, "yellow");
  }

  animate(0.0);
}
