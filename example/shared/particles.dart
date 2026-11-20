/// Star fields and particle artwork shared by the examples.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart' as cg;
import 'package:web/web.dart' as web;

/// Creates a caller-owned texture with the examples' radial particle artwork.
cg.Texture createParticleTexture(
  cg.ChronosGL cgl, [
  String name = 'example::particles',
]) => cg.ImageTexture.fromCanvas(
  context: cgl,
  name: name,
  canvas: createParticleCanvas(),
);

/// Paints a 64 by 64 radial sprite for demonstration particles.
web.HTMLCanvasElement createParticleCanvas() {
  const d = 64;
  final canvas = web.HTMLCanvasElement()
    ..width = d
    ..height = d;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  const x = d ~/ 2, y = d ~/ 2;

  var gradient = ctx.createRadialGradient(x, y, 1, x, y, 22);
  gradient.addColorStop(0, 'gray');
  gradient.addColorStop(1, 'black');

  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, d, d);

  gradient = ctx.createRadialGradient(x, y, 1, x, y, 6);
  gradient.addColorStop(0, 'white');
  gradient.addColorStop(1, 'gray');

  ctx.globalAlpha = 0.9;
  ctx.fillStyle = gradient;
  ctx.arc(x, y, 4, 0, 2 * math.pi);
  ctx.fill();
  return canvas;
}

/// Creates caller-owned random points inside a cube of side [dimension].
///
/// Supplying [random] explicitly allows an example to use a repeatable seed.
cg.GpuMesh makeStarMesh(
  cg.RenderProgram prog,
  int numPoints,
  double dimension, {
  required math.Random random,
}) {
  final positions = Float32List(numPoints * 3);
  for (var i = 0; i < positions.length; i++) {
    positions[i] = (random.nextDouble() - 0.5) * dimension;
  }
  return prog.makeGpuMesh('stars_$numPoints', cg.glPoints)
    ..addVertices(positions);
}

/// Creates a material borrowing a new particle texture in its `uTexture`
/// uniform. The caller must dispose that texture after use.
cg.Material makeStarMaterial(cg.ChronosGL cgl, [double size = 1000.0]) =>
    cg.Material.transparent('stars', cg.blendEquationMix)
      ..setUniform(cg.uTexture, createParticleTexture(cgl))
      ..setUniform(cg.uPointSize, size);

/// Creates a demo node with a caller-owned point mesh and particle texture.
///
/// Dispose the mesh and the material's `uTexture` texture after use.
cg.MeshNode makeParticles(
  cg.RenderProgram prog,
  int numPoints, {
  double dimension = 100.0,
  required math.Random random,
}) {
  final material = makeStarMaterial(prog.getContext());
  final mesh = makeStarMesh(prog, numPoints, dimension, random: random);
  return cg.MeshNode(mesh.name, mesh, material);
}
