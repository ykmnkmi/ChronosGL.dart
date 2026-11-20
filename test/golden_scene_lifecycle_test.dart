@TestOn('chrome')
library;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';

import 'support/golden_scenes.dart';

void main() {
  test('golden fixtures explicitly release their GPU owners', () {
    for (final name in goldenSceneNames) {
      final fixture = GoldenScene(name);
      addTearDown(fixture.dispose);
      final programs = <RenderProgram>{};
      final meshes = <GpuMesh>{};
      final textures = <Texture>{};
      void collect(Node node) {
        if (node is MeshNode) {
          meshes.add(node.mesh);
          textures.addAll(
            node.material.getUniforms().values.whereType<Texture>(),
          );
        }
        for (final child in node.children) {
          collect(child);
        }
      }

      for (final batch in fixture.phase.batches) {
        programs.add(batch.program);
        for (final group in batch.uniforms) {
          textures.addAll(group.getUniforms().values.whereType<Texture>());
        }
        for (final node in batch.nodes) {
          collect(node);
        }
      }
      expect(programs, isNotEmpty, reason: name);
      expect(meshes, isNotEmpty, reason: name);
      fixture
        ..dispose()
        ..dispose();
      expect(fixture.framebuffer.isDisposed, isTrue, reason: name);
      expect(
        programs.map((program) => program.isDisposed),
        everyElement(isTrue),
        reason: name,
      );
      expect(
        meshes.map((mesh) => mesh.isDisposed),
        everyElement(isTrue),
        reason: name,
      );
      expect(
        textures.map((texture) => texture.isDisposed),
        everyElement(isTrue),
        reason: name,
      );
      expect(fixture.render, throwsStateError, reason: name);
    }
  });
}
