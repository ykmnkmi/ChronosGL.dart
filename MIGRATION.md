# Migrating to ChronosGL 5.0.0

Version 5.0.0 changes API names and browser types. Use Dart 3.14.0 or later
within Dart 3, then update the dependencies in your application:

```yaml
dependencies:
  chronosgl: ^5.0.0
  vector_math: ^2.4.4
  web: ^1.1.2
```

Declare `vector_math` and `web` directly when your application imports them.
Run `dart pub get` and `dart analyze` after updating names and imports. For Wasm,
replace all legacy SDK browser imports in your application as well as upgrading
ChronosGL; legacy DOM compatibility is available only for JavaScript builds.

## Camera semantics and resource lifetimes

Migrate camera pose, input and rendering together. All gallery examples now use
the supported API; [minimal.dart](example/minimal/minimal.dart) is a standalone
starting point with explicit cleanup.

| Previous use | Supported replacement |
| --- | --- |
| `Spatial` or `OrbitCamera` as the camera | `PerspectiveCamera` or `OrthographicCamera` with a world-space pose |
| `Perspective(orbit, near, far)` | `CameraUniforms(camera)`, with projection parameters on the camera |
| Per-frame `orbit.animate(...)` | `controls.update(deltaSeconds)` on `OrbitControls.forCamera` |
| A fixed orbit increment per frame | Radians per second multiplied by elapsed seconds |
| `PerspectiveResizeAware`, `RenderPhaseResizeAware` | `CanvasViewport.forCanvas` and an optional screen `RenderPass` |
| `Node(...)`, `Scene`, `RenderPhase`, `MeshData` | `MeshNode`, `RenderBatch`, `RenderPass`, `GpuMesh` |
| Upload helpers named `geometryBuilderToMeshData*` | `uploadGeometry`, `uploadWireframeGeometry` |

Camera matrices describe distinct coordinate changes. `worldMatrix` maps
camera-local coordinates to world coordinates; `viewMatrix` is its inverse;
`viewProjectionMatrix` is `projection * view`. `lookAt(target)` changes only
orientation and preserves the world eye position. `CameraUniforms` sends that
position as `uEyePosition`, independent of the view matrix's translation.

If application code previously used `spatial.transform` as a view matrix, read
the view with `getViewMatrix(output)` using a separate matrix, or migrate to
`camera.viewMatrix`. Lighting and reflections now use the preserved world eye.
[Legacy camera position](#preserved-camera-position)

Camera, projection and `Transform` getters return independent snapshots.
Use `setPosition`, `setRotation`, `setProjection`, `lookAt` and transform
setters to commit edits. [Matrix access and updates](#matrix-access-and-updates)

Programs, GPU meshes, textures and framebuffers have explicit, repeat-safe
`dispose()` operations. Passes, batches, nodes, programs and materials borrow
their supplied resources. Removing a node or replacing a material does not
dispose a shared mesh or texture. Factory-created meshes belong to the caller.
External mesh attribute buffers are borrowed unless supplied to
`changeAttributeBuffer` with `takeOwnership: true`.
Framebuffers created with `defaultFramebuffer` or `effect` own their attachments.
Use `Framebuffer.withAttachments(..., takeOwnership: [...])` to transfer
ownership of external textures. Dispose diagnostic visualizers before the
resources they borrow.

Assigning a framebuffer attachment now updates the GPU binding and borrows
the newly supplied texture. Use `replaceAttachments` to set the complete
configuration in one operation, including any ownership transfers. Omitted
slots are cleared. Validation or setup failure preserves the previous
configuration. A successful replacement releases displaced owned textures
once their last slot in the framebuffer is removed.

At teardown, stop animation frames and asynchronous callbacks, detach controls
with `await controls.dispose()`, disconnect the viewport and dispose owned GPU
resources after their last consumer. Stop media tracks and close MIDI ports
owned by an application. Asynchronous asset callbacks must check whether their
scene is still alive before creating resources or drawing. The gallery's
`example/shared/lifetime.dart` implements this policy with explicit registration.
Its `ownPass` and `ownBatch` opt into ownership of reachable resources; this is
an example helper and does not alter engine borrowing contracts. Register
removed or replaced resources separately so teardown can still find them.

### Legacy DOM compatibility

Use `package:web` for new browser code. Typed constructors include
`ChronosGL.fromCanvas`, `ImageTexture.fromCanvas/fromImage/fromVideo`,
`Keyboard.forTarget`, `Mouse.forTarget`, `OrbitControls.forCamera`,
`CanvasViewport.forCanvas`, `StatsPanel.attach` and `FpsPanel.attach`.
The previous Object-based context, texture, input, panel, orbit and resize
constructors remain deprecated migration adapters. They accept legacy SDK DOM
objects only in JavaScript; they do not make `dart:html`, `dart:web_gl` or other
SDK browser libraries available to Wasm applications. Use `dart:js_interop`
callbacks/promises and `package:web` throughout the application and its browser
dependencies before selecting `dart2wasm`. CPU imports such as `core.dart` and
`camera.dart` remain usable on the Dart VM without these browser dependencies.

## Supported public API

Import public modules from `package:chronosgl/`.

| Import | Supported use | Runtime |
| --- | --- | --- |
| `core.dart` | Transform, immutable Color and palette | VM and browser |
| `camera.dart` | Cameras and reusable projections | VM and browser |
| `geometry.dart` | CPU builders, shapes and polygon algorithms | VM and browser |
| `animation.dart` | Skeletons, keyframes and pose calculation | VM and browser |
| `importers.dart` | Wavefront, ThreeJS and Assimp parsing | VM and browser |
| `shaders.dart` | Shader descriptions, canonical names and GLSL | VM and browser |
| `webgl.dart` | WebGL2 context, handles and numeric constants | Browser |
| `render.dart` | Programs, GPU meshes, uniforms, materials, textures and lights | Browser |
| `mesh.dart` | GPU meshes, geometry uploads and shape factories | Browser |
| `scene.dart` | Nodes, batches and passes | Browser |
| `shadows.dart` | Shadow map computation | Browser |
| `web.dart` | Input, controls, viewport, URL loading and browser assets | Browser |
| `debug.dart` | Statistics panels and visualizers | Browser, explicit import |

`chronosgl.dart` combines the supported engine modules. Add
`import 'package:chronosgl/debug.dart';` wherever you use panels or visualizers.
Use the public entry points for application imports. [Class and architecture guide](class_glossary.md)

`MidiInput`, `findBridge`, and the unfinished GPU `extractWireframe` helper are
removed from supported exports. Use `uploadWireframeGeometry` with the source
CPU geometry for wireframes. MIDI and polygon-hole bridging have no implemented
replacement. `UnknownEntity`, `kUnknownEntity`, `Face1`, `Face2`, `Edge3`,
`hashVector3`, storage-column indices, shader-name prefix codes, icosahedron
tables/UV helpers, `noWebglMessage`, `textureChannelsByType`, `isCubeChildTextureType`,
`drawRecursively`, and `getOrthogonalVector3` are implementation details. Keep
application-specific equivalents locally where needed; use `Face3`, `Face4`,
public shape factories and scene traversal operations for supported behavior.

### Explicit shader stages and typed uniforms

```dart
final vertex = ShaderObject.vertex('vertex')
  ..addAttributeVars([aPosition])
  ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
final fragment = ShaderObject.fragment('fragment')
  ..addUniformVars([uColor])
  ..setBodyWithMain(['$oFragColor = vec4($uColor, 1.0);']);
final program = RenderProgram.create(
  name: 'solid',
  context: cgl,
  vertexShader: vertex,
  fragmentShader: fragment,
);

final material = Material('paint')
  ..set(UniformKeys.color, colorWhite.toVector3());
material.force(UniformKeys.color, colorBlue.toVector3());
final color = material.get(UniformKeys.color);
```

`ShaderObject.create(name: ..., stage: ShaderStage.vertex)`,
`.vertex(name)` and `.fragment(name)` declare the stage explicitly, including
for attribute-free vertex shaders.
The deprecated `ShaderObject(name)` constructor retains the previous inference
for migration. Set interface variables before generating or assigning the body;
subsequent edits throw `StateError`. Shader variable lists and layout maps are
read-only snapshots.

Canonical `u*` strings keep their GLSL values. Existing
`setUniform(name, value)` and `forceUniform(name, value)` remain supported string
boundaries. Prefer `set`, `force`, and `get` with `UniformKeys`, or register a
custom `ShaderVarDesc` then use `UniformKey<T>('uCustom')`. Typed calls validate
both the Dart value and the registered GLSL shape. Matrix arrays use flattened
`Float32List` values; integer arrays use `Int32List`. `set` and `setUniform`
reject an existing key with `StateError`; use `force` or `forceUniform` to
replace it.

### Named constructors, units, and typed browser objects

| Existing construction | Preferred entrypoint |
| --- | --- |
| `ChronosGL(canvas, ...)` | `ChronosGL.fromCanvas(packageWebCanvas, ...)` |
| `RenderProgram(name, cgl, vertex, fragment)` | `RenderProgram.create(name: ..., context: ..., vertexShader: ..., fragmentShader: ...)` |
| `Keyboard(target)`, `Mouse(target)` | `Keyboard.forTarget(target)`, `Mouse.forTarget(target)` |
| `OrbitControls(camera, target, ...)` | `OrbitControls.forCamera(camera: ..., eventTarget: ..., ...)` |
| `OrbitCamera(radius, azimuth, polar, target)` | A mathematical camera with `OrbitControls.forCamera(camera: ..., eventTarget: ..., radius: ..., azimuth: ..., polar: ...)` |
| `CanvasViewport(cgl, canvas, camera, ...)` | `CanvasViewport.forCanvas(cgl: ..., canvas: ..., camera: ..., ...)` |
| `ImageTexture(cgl, name, element, properties)` | `ImageTexture.fromImage/fromCanvas/fromVideo/fromImageBitmap(context: ..., name: ..., image/canvas/video/bitmap: ..., properties: ...)` |
| `CubeTexture(cgl, name, images)` | `CubeTexture.fromImages(context: ..., name: ..., images: ...)` |
| `StatsPanel(root, foreground, background)` | `StatsPanel.attach(root: ..., foreground: ..., background: ...)` |
| `FpsPanel(root, foreground, background)` | `FpsPanel.attach(root: ..., foreground: ..., background: ...)` |
| `RenderBatch(name, program, uniforms)`, `RenderPass(name, cgl, framebuffer)` | `RenderBatch.named`, `RenderPass.named` |
| Positional typed texture constructors | `TypedTexture.allocate`, `TypedTextureMutable.allocate` (named pixel dimensions and formats) |
| Positional light constructors | `PointLight.named`, `DirectionalLight.named`, `SpotLight.named` |
| Positional animation constructors | `Bone.named`, `BoneAnimation.keyframes`, `SkeletalAnimation.named` |
| `coneGeometryWireframeFrienly(radius, height, subdivisions)` | `coneGeometryWireframeFriendly(radius: ..., height: ..., radialSubdivisions: ...)` |

Constructors whose original meaning remains valid still work. Typed browser
constructors require `package:web` objects. Deprecated Object-based browser
constructors are compatibility boundaries; SDK `dart:html` objects work only in
JavaScript builds. Use typed constructors for JavaScript and Wasm applications.
Texture sources, event targets and panel roots remain borrowed.

Camera and light angles are radians (`SpotLight.named.angleRadians` is the cone
half-angle); positions, near/far distances, light ranges and directional shadow
extents use consistent application world units. Viewport sizes are framebuffer
pixels, CSS sizes are CSS pixels, and pixel ratio converts between them. Controls
consume elapsed seconds; FPS panels consume monotonic timestamps in
milliseconds. Use consistent units for animation keys, sample time and clip
duration. The ThreeJS importer copies key times and duration from the file.
The Assimp importer divides key times by `tickspersecond` and leaves the
imported `duration` in ticks. Convert that duration to seconds if you use it
for looping over the imported key times. Each bone track holds its final
keyframe from that key's timestamp onward.

### Errors and collection mutation

Handle `ArgumentError` for invalid inputs, `StateError` for invalid object
state (including disposed use), `UnsupportedError` for unsupported operations,
and `ShaderCompilationException` for shader compilation or program linking.
The shader exception carries the driver message, optional stage and source;
link failures have no stage. Public checks no longer rely on assertions or
throw string values.
Rendering controls and active uniform values are validated before changing
WebGL state, including controls supplied through legacy string setters.
Uniforms optimized out by the shader linker are skipped, including inactive
samplers. `uninitializedInputs()` continues to report missing active inputs.
`GpuMesh.changeFaces` requires an index buffer created by `addFaces`. Calling
it before `addFaces`, or after `clearData()` without recreating the index buffer,
throws `StateError` before changing mesh data or WebGL bindings.

`UniformGroup.getUniforms()` returns a read-only map snapshot. Replace edits to
that map with `setUniform`, `forceUniform`, `addUniforms`, `removeUniform`, or
`clearUniforms`. Values remain borrowed: copy a vector/matrix explicitly if
independent value ownership is needed. `CameraUniforms` preserves its earlier
contract: each read returns a fresh caller-owned mutable map with independent
camera matrix/vector snapshots, so editing it cannot change the adapter.

Shader interfaces/layouts, animation track views, GPU readback snapshots and
the easing registry similarly protect their structural invariants. Use
`SkeletalAnimation.insertBone` to add a track. Scene child/root lists and batch
uniform lists remain editable between draws; cycles are checked during
traversal. CPU geometry remains editable and must pass `validate()` before
upload.

## Scene graph and geometry

Use these names through `package:chronosgl/chronosgl.dart`:

| Previous API | Current API |
| --- | --- |
| `Node.container(name, child)` | `GroupNode(name, child)` |
| `Node(name, mesh, material)` | `MeshNode(name, mesh, material)` |
| `node.meshData` | `meshNode.mesh` |
| `Scene` | `RenderBatch` |
| `RenderPhase` | `RenderPass` |
| `MeshData` | `GpuMesh` |
| `program.makeMeshData(name, mode)` | `program.makeGpuMesh(name, mode)` |
| `geometryBuilderToMeshData(name, program, geometry)` | `uploadGeometry(name, program, geometry)` |
| `geometryBuilderToMeshDataWireframe(name, program, geometry)` | `uploadWireframeGeometry(name, program, geometry)` |

Legacy constructors redirect to the concrete node types. `Node` is now an
abstract common type for transforms and child links, without `meshData` or
`material`. Change declarations that access drawable resources to `MeshNode`,
or narrow a general node using `if (node is MeshNode)`. `MeshNode.meshData`
remains a deprecated alias for `mesh`. Mesh and material references are required;
removing a node or changing its resource does not dispose either resource.
Custom node subclasses should extend `GroupNode` or `MeshNode`; `Node` now
provides factory constructors rather than a public generative constructor.
The previous batch, pass and mesh type names remain aliases, and the previous
upload methods remain wrappers.

Traversal remains depth-first in insertion order, drawing a parent before its
children. World matrices are `parentWorld * local` for each path, so a shared
node draws separately in each branch. Cycles throw `StateError`. Change graph
links between draws. Transform values supplied to individual draws are
independent; subsequent paths and errors do not corrupt earlier values.

`RenderBatch` copies the supplied uniform list. To add or remove groups after
construction, edit `batch.uniforms`; editing the original list no longer changes
the batch. Contained groups remain shared. Drawing leaves supplied groups and
lists unchanged, including on failure. An enabled `RenderPass` with a nonempty
viewport clears selected framebuffer buffers once before drawing its batches.
Invoke passes in the desired order and disable clear flags on later passes
when preserving earlier output. A disabled pass performs no framebuffer work.

Import `package:chronosgl/geometry.dart` for CPU builders, shape factories,
polygon algorithms, and attribute metadata on the Dart VM. Existing browser
imports export the same declarations and shader attribute registry. Call
`geometry.validate()` to check edited geometry: invalid indices, nonfinite
coordinates, faces on point clouds, and malformed attributes throw `StateError`.
Uploads validate before allocating GPU storage and release partial uploads on
failure. CPU builders and the uploaded mesh hold independent numeric data.
`wedgeGeometry(computeNormals: false)` now omits the normal attribute entirely,
so geometry created without normals passes validation.
`gridGeometry(xstrips, ystrips, xlen, ylen)` and `shapeGrid` handle independent
subdivision counts and full side lengths. Review rectangular grids if your
application compensated for the previous indexing or height calculation.

GPU meshes and programs expose immutable `attributeLayout` snapshots. Use
`mesh.isCompatibleWith(program)` before sharing across programs: the WebGL
context, required attribute names, locations, types, widths, and instancing
divisors must agree. Extra mesh bindings are allowed. An incompatible draw
throws `ArgumentError` before changing WebGL state. Populate the required
buffers and keep them alive until the mesh's last draw.

## Helpers and settings

The aggregate import still exposes supported browser helpers. Use `mesh.dart`
for GPU mesh factories, `shadows.dart` for shadow computation, and `debug.dart`
for optional panels and visualizers. Example-only artwork, particles and
shaders live under `example/shared/`.

| Previous use | Current use |
| --- | --- |
| `setUniform(uColor, colorWhite)` | `setUniform(uColor, colorWhite.toVector3())` |
| Mutate a `color*` vector | `color.copyWith(r: ..., g: ..., b: ...)`, then `toVector3()` |
| Assign fields of `TextureProperties` | Named constructor arguments or `properties.copyWith(...)` |
| `properties.setFilterNearest()` | Use the returned `properties.withFilterNearest()` value |
| `properties.setMipmapLinear()` | Use the returned `properties.withMipmapLinear()` value |
| Assign blend/stencil setting fields | Create a variant with `copyWith(...)` and replace the material control |
| `emptyMaterial` | A new `Material(name)` or a pass's independent material |
| `unitNode(program)` | `FullscreenPass(program).node`, with an owner retained for disposal |
| `shadowMap.visualize()` | `ShadowMapVisualizer(shadowMap).draw()`, retaining the visualizer for reuse |
| `shadowMap.setVisualizationViewPort(x, y, w, h)` | `visualizer.setViewport(x, y, w, h)` |
| `Stats`, `StatsFps` | `StatsPanel`, `FpsPanel` (old names remain aliases) |
| `Utils.*` particle/star helpers | Top-level functions in `example/shared/particles.dart` |
| `demoVertexShader`, `demoFragmentShader` | `example/shared/shaders.dart` |

`Color` and its palette are usable through `core.dart` on the Dart VM. Each
`toVector3()` returns an independent mutable vector; sharing that resulting vector
explicitly still shares its mutations. Settings and their presets are immutable,
including non-preset instances. Replace a control through
`material.forceUniform(cBlendEquation, preset.copyWith(...))`. A texture retains
the immutable properties passed at construction; choose the variant before
creating the texture.

All `shape*` factories return caller-owned GPU meshes and keep existing call
signatures. `shapeCube` now forwards `computeNormals`; `shapeWedge` also exposes
that option, `shapeTorusKnot` exposes `wrap`, `computeUVs` and `inside`, and
`shapeQuad` accepts fractional sizes. Programs requiring omitted normals or UVs
must be changed accordingly. Dispose each created mesh after its last consumer.

`FullscreenPass` creates and owns its quad. Its default material disables depth
testing and depth writes; a supplied material is borrowed unchanged. Its
uniforms and textures remain borrowed. The supplied program is borrowed unless
`ownsProgram: true` is set, which also transfers failure cleanup responsibility.
The pass draws into the active framebuffer and viewport. Alternatively, add its
`node` to a batch; remove every use before disposing the owner. The deprecated
`unitNode` creates independent meshes and materials, with mesh cleanup left to
the caller.

`ShadowMap` creates no visualization resources. It owns its compute program,
framebuffer and attachments; casters and their resources remain borrowed.
`ShadowMapVisualizer` creates its own program, mesh and sampler on first draw.
It samples depth without mutating comparison settings, and does not clear the
screen. Dispose the visualizer before the map. `getMapTexture()` returns a
borrowed texture and `getMapSize()` returns an independent vector.

`LightVisualizer` and `BoneVisualizer` allocate their owned line meshes only
when `mesh` is first read. Updates before that read do not allocate GPU assets.
Programs, materials, lights and animations are borrowed. Old light mesh factory
functions remain available and return caller-owned meshes. Panels own a styled
wrapper inside their borrowed root; their DOM structure includes this wrapper.
`dispose()` removes only that wrapper and preserves the root's styles and other
children. `FpsPanel` uses the actual elapsed sample time in milliseconds.

Legacy `RenderPhaseResizeAware` and `PerspectiveResizeAware` now belong to browser
integration. Call `dispose()` to stop their resize subscription. Their borrowed
resources and projection reads remain usable, while `resolutionChange()` after
disposal throws `StateError`. Prefer `CanvasViewport` for new code.

Particle examples pass an explicit `math.Random` to `makeStarMesh` and
`makeParticles`; the old global `Utils.rand` and unused `Utils.id` are removed.
Demo materials borrow their generated texture; example code must release that
texture and its mesh separately when finished.

## Cameras and transforms

### Mathematical imports on the VM

Use these entry points for command-line tools and VM tests. `core.dart` exports
`Transform`, `Color` and the palette. `camera.dart` exports the camera and
projection types. Both are also available through the browser aggregate.

```dart
import 'package:chronosgl/core.dart';
import 'package:chronosgl/camera.dart';
```

Use `chronosgl.dart` or the focused browser modules for rendering and input.
[Standalone VM example](test/support/math_imports.dart)

### Transform component

`Transform.matrix` maps local coordinates to parent coordinates. TRS
composition is `translation * rotation * scale`. Use these operations to
migrate object poses from `Spatial`.

| Previous operation | `Transform` equivalent |
| --- | --- |
| `setPos`, `setPosFromVec`, `getPos` | `setPosition`, `setPositionFromVector`, `position` |
| Move along an object's forward, right or up direction | `translateLocal(0, 0, -distance)`, `translateLocal(distance, 0, 0)` or `translateLocal(0, distance, 0)` |
| Rotate around a local axis | `rotateLocal(axis, angleRadians)` |
| Rotate around a parent-space axis | `rotateParent(axis, angleRadians)` |
| Edit `spatial.transform` directly | Use component setters, or edit a matrix snapshot and pass it to `setMatrix` |

`translate` uses parent-space axes. `lookAt(target, upHint: ...)` points local
-Z toward a target in parent space and preserves position and scale.
`setMatrix` copies an affine matrix with its shear or zero scale intact.
Component operations that require a TRS decomposition throw `StateError` for
such matrices. To use a `Transform` with an existing scene node, call
`pose.copyMatrixInto(node.transform)` after edits and before drawing.

### Camera pose and view matrix

Both mathematical cameras store a world-space position and normalized
orientation. `lookAt` points local -Z toward a world-space target and preserves
the eye position. Moving the camera later preserves the orientation until the
next rotation or `lookAt` call.

```dart
import 'package:chronosgl/camera.dart';
import 'package:vector_math/vector_math.dart' as vm;

final camera = PerspectiveCamera(near: 0.1, far: 1000, aspectRatio: 16 / 9)
  ..setPosition(0, 0, 10);
camera.lookAt(vm.Vector3.zero()); // World position remains (0, 0, 10).
```

For an eye position `eye` and orientation `R`, the world matrix is
`T(eye) * R` and its inverse maps a world point to `R^-1 * (point - eye)`.
Read `worldPosition` for the eye and `viewProjectionMatrix` for
`projectionMatrix * viewMatrix`. Invalid pose edits preserve both components.
A view calculation can throw `StateError` for Float32 overflow while leaving
the pose readable and editable.

### Projection parameters

Perspective cameras and projections take named `fovYRadians`, `aspectRatio`,
`near` and `far` values. `fovYRadians` is the full vertical angle and defaults
to `50 * pi / 180`. `aspectRatio` is width divided by height and defaults to
`1`. All parameters must be finite, with `0 < fovYRadians < pi`,
`aspectRatio > 0` and `0 < near < far`. Legacy `Perspective.updateFov` takes
degrees. Convert those values to radians when migrating.

Orthographic cameras and projections require all six bounds, with
`left < right`, `bottom < top` and `near < far`. Near and far may be zero
or negative.

To change one parameter, pass the others from the camera's getters.

```dart
camera.setProjection(
  fovYRadians: camera.fovYRadians,
  aspectRatio: 4 / 3,
  near: camera.near,
  far: camera.far,
);
```

Invalid ranges and nonfinite or singular Float32 projection matrices throw
`ArgumentError` and preserve the existing projection and camera pose.

### Reusable projections

`PerspectiveProjection` and `OrthographicProjection` are immutable
view-to-clip values. Share them through `PerspectiveCamera.fromProjection` or
`OrthographicCamera.fromProjection`. A camera's `projection` getter returns
the immutable value. `setProjection` replaces it on that camera only.

For custom shadows, compose `projection.matrix..multiply(lightViewMatrix)`
and pass the result to `ShadowMap.compute`. Directional and spot lights
use these projection classes internally. Invalid shadow bounds, field of view
or clipping distances throw `ArgumentError` from
`extractShadowProjViewMatrix()`.

### Matrix access and updates

Camera, transform and projection getters return independent snapshots,
including their typed storage. Setters take effect on the next read. To
commit an edit to a transform snapshot, use `transform.setMatrix(editedMatrix)`.
Legacy `Spatial.transform` remains writable.

Reuse caller-owned storage with `copyWorldMatrixInto(out)`,
`copyViewMatrixInto(out)`, `copyProjectionMatrixInto(out)` and
`copyViewProjectionMatrixInto(out)`. A failed camera calculation leaves
the destination unchanged. Transforms and projections provide
`copyMatrixInto(out)` with the same ownership convention.

### Preserved camera position

`Spatial.lookAt(target, [up])` now preserves position and stores a local-to-parent
pose, or camera-to-world pose for an unparented camera. `getViewMatrix(out)`
computes its inverse into separate storage. `getPos()` and `getEyePosition()`
therefore return `(0, 0, 10)` after `setPos(0, 0, 10)` and `lookAt(Vector3.zero())`.
Repeated aiming and subsequent movement use the preserved position.

Both `Perspective` and `Orthographic` supply world-space `uEyePosition` alongside
`uPerspectiveViewMatrix = P * V`. Custom `Spatial` subclasses can still override
`getViewMatrix` and `getEyePosition`. Update legacy call sites that depend on
the previous behavior.

- Read the view through `getViewMatrix(out)`. When importing a precomputed
  view matrix, invert it before copying into `transform`.
- Direction getters and movement now use pose columns. `lookUp/Down`,
  `lookLeft/Right`, and `rollLeft/Right` rotate around local X, Y, and Z;
  up/left rotations use positive angles. Orbit roll preserves its target.
- A node's `lookAt` takes its target and up in parent space and preserves its
  local position. The legacy operation discards scale and shear. Use
  `Transform.lookAt` to preserve TRS scale.
- Invalid `lookAt` arguments throw `ArgumentError` before changing the pose.
  A singular or nonfinite view inverse throws `StateError` without changing the
  output. Passing any output that overlaps the pose's typed storage throws
  `ArgumentError`.

Copy legacy scratch vectors if you need to keep their values. The legacy
camera view API assumes an unparented camera. [Camera position regression tests](test/camera_position_reproduction_test.dart)

### Camera uniforms

Import `package:chronosgl/chronosgl.dart` in browser rendering code and wrap
either mathematical camera in `CameraUniforms(camera, [name])`:

```dart
final camera = PerspectiveCamera(near: 0.1, far: 1000)
  ..setPosition(0, 0, 10);
camera.lookAt(vm.Vector3.zero());
final uniforms = CameraUniforms(camera);
program.draw(mesh, [uniforms, material, transforms]);
// The same adapter can be passed to RenderBatch('objects', program, [uniforms]).
```

The adapter borrows the camera and reads its current pose and projection on
every draw. `getUniforms()` returns a fresh map with
independent `uPerspectiveViewMatrix = P * V` and world-space `uEyePosition`
snapshots. The matrix name also applies to orthographic cameras. Supply object
transforms separately as before. Camera values override inherited uniform
setters; additional uniforms retain existing `UniformGroup` semantics.

`render.dart` also exports `CameraUniforms` for browser code using focused
imports. [Camera uniform tests](test/camera_uniforms_webgl_test.dart)

## API naming changes

Functions, methods, fields, parameters, variables, and named constructors now
use lowerCamelCase. Import prefixes use lowercase names. Classes and typedefs
retain UpperCamelCase. These are source-breaking API changes; update references
in consuming projects. The previous names have been removed.

## Functions, methods, and constructors

| Previous name | Current name |
| --- | --- |
| `LogInfo` | `logInfo` |
| `CubeGeometry` | `cubeGeometry` |
| `GeometryBuilderToMeshData` | `uploadGeometry` (`geometryBuilderToMeshData` is retained) |
| `ImportGeometryFromWavefront` | `importGeometryFromWavefront` |
| `LoadJson` | `loadJson` |
| `GeometryBuilder.AddVertices` | `GeometryBuilder.addVertices` |
| `GeometryBuilder.GenerateFaceIndices` | `GeometryBuilder.generateFaceIndices` |
| `UniformGroup.SetUniform` | `UniformGroup.setUniform` |
| `UniformGroup.GetUniforms` | `UniformGroup.getUniforms` |
| `RenderProgram.Draw` | `RenderProgram.draw` |
| `RenderPhase.Draw` | `RenderPass.draw` (`RenderPhase` is an alias) |
| `Node.UpdateModelMatrix` | `Node.updateModelMatrix` |
| `Node.Container` | `GroupNode` (`Node.container` is retained) |
| `Material.Transparent` | `Material.transparent` |
| `Material.Empty` | `Material.empty` |
| `Framebuffer.Screen` | `Framebuffer.screen` |
| `Framebuffer.Effect` | `Framebuffer.effect` |
| `Framebuffer.Default` | `Framebuffer.defaultFramebuffer` |
| `TypedTextureMutable.UpdateContent` | `TypedTextureMutable.updateContent` |
| `TextureProperties.SetFilterNearest` | `TextureProperties.withFilterNearest()` (returns a new value) |
| `Utils.MakeStarMesh` | Example `makeStarMesh(..., random: random)` in `example/shared/particles.dart` |
| `Keyboard.AfterFrameCleanup` | `Keyboard.afterFrameCleanup` |

Leading underscores on private declarations remain in place, for example
`_JsonDouble` becomes `_jsonDouble`. Parameters such as `num_points` become
`numPoints`; update named arguments as well as references in function bodies.
Named constructors retain their class name, as in `Material.transparent`.

`Framebuffer.Default` uses `defaultFramebuffer` because `default` is a Dart
keyword. The game example's `Sprite.Break` is now `Sprite.brake`, since `break`
is also a keyword.

## Variables and import prefixes

| Previous name | Current name |
| --- | --- |
| `ColorWhite` | `colorWhite` |
| `BlendEquationMix` | `blendEquationMix` |
| `TexturePropertiesFramebuffer` | `texturePropertiesFramebuffer` |
| `ColorFunctions` | `colorFunctions` |
| `RIGHTX`, `UPY`, `POSZ` | Use transform direction and position getters in place of internal storage indices |
| `VM` | `vm` |
| `Math`, `MATH` | `math` |
| `DATA` | `data` |

Replace `dart:html` and `dart:web_gl` imports with
`import 'package:web/web.dart' as web;`. For example, `HTML.CanvasElement`
becomes `web.HTMLCanvasElement`. The `web` prefix also avoids a naming conflict
with ChronosGL's `Node`. Import `dart:js_interop` for callback and promise
conversions instead of using the old `dart:js` or `dart:js_util` APIs.

## Constants

Constants now use lowerCamelCase throughout the library, examples, and tests.

| Previous name | Current name |
| --- | --- |
| `GL_ARRAY_BUFFER` | `glArrayBuffer` |
| `GL_COLOR_BUFFER_BIT` | `glColorBufferBit` |
| `GL_CLEAR_ALL` | `glClearAll` |
| `GL_RGBA8` | `glRgba8` |
| `GL_TEXTURE_2D` | `glTexture2D` |
| `GL_UNSIGNED_SHORT_5_6_5` | `glUnsignedShort565` |
| `GL_UNMASKED_RENDERER_WEBGL` | `glUnmaskedRendererWebgl` |
| `VarTypeFloat` | `varTypeFloat` |
| `VarTypeSampler2D` | `varTypeSampler2D` |
| `StdVertexBody` | `stdVertexBody` |
| `StdLibShader` | `stdLibShader` |
| `PackedRGBALib` | `packedRgbaLib` |
| `PerlinNoiseFunctions` | `perlinNoiseFunctions` |
| `SimplexNoiseHelpers` | `simplexNoiseHelpers` |
| `ShadowMapShaderLib` | `shadowMapShaderLib` |
| `NO_WEBGL_MESSAGE` | Supply your own fallback message in application code |
| `Keyboard.PAGEUP` | `Keyboard.pageUp` |
| `Keyboard.PAGEDOWN` | `Keyboard.pageDown` |
| `Keyboard.SPACE` | `Keyboard.space` |
| `Keyboard.A` … `Keyboard.Z` | `Keyboard.a` … `Keyboard.z` |
| `Keyboard.F1` … `Keyboard.F12` | `Keyboard.f1` … `Keyboard.f12` |
| `Mouse.LEFT` | `Mouse.left` |
| `Mouse.MIDDLE` | `Mouse.middle` |
| `Mouse.RIGHT` | `Mouse.right` |

The `GL_*` constants use a `gl` prefix followed by capitalized words. Acronyms
become words, such as `RGBA` → `Rgba`; dimensional suffixes retain `2D` and `3D`.
Numeric components are joined, as in `GL_UNSIGNED_SHORT_5_6_5` above.
The MIDI example also uses names such as `midiNoteOn` instead of `MIDI_NOTE_ON`.
Private constants retain their leading underscore, for example
`_SAMPLE_RATE_MS` → `_sampleRateMs`.

The naming changes preserve WebGL numeric values and canonical GLSL attribute
and uniform strings. Diagnostic strings such as `"GL_RGBA"` still use the
standard WebGL spelling.

## Core WebGL bindings

The core wrapper now uses `package:web` and `dart:js_interop` instead of
`dart:web_gl`. The `GlBuffer`, `GlTexture`, `GlProgram`, and other `Gl*` aliases
refer to the corresponding `package:web` WebGL types. Buffer, texture, uniform,
and pixel APIs still accept Dart typed data, including views with byte offsets.

Create a context from a typed `package:web` canvas.

```dart
import 'package:chronosgl/chronosgl.dart';
import 'package:web/web.dart' as web;

final canvas = web.HTMLCanvasElement()
  ..width = 640
  ..height = 480;
final cgl = ChronosGL.fromCanvas(canvas);
```

`getParameter` returns Dart scalars and lists, preserving opaque WebGL handles.
`getExtension` returns a nullable `JSObject`; use a `package:web` extension type
to access extension methods:

```dart
final extension = cgl.getExtension('WEBGL_lose_context');
if (extension != null) {
  (extension as web.WEBGL_lose_context).loseContext();
}
```

See Dart's [package:web migration guide](https://dart.dev/interop/js-interop/package-web)
for the browser API naming and interop differences.

The core interop tests also run with Wasm:

```sh
dart test -p golden_chrome -c dart2wasm test/core_web_interop_test.dart
```

## Camera controls and canvas sizing

Pass the same mathematical camera to `OrbitControls.forCamera`,
`CanvasViewport.forCanvas` and `CameraUniforms`. These components are
exported by `package:chronosgl/chronosgl.dart`.

```dart
final controls = OrbitControls.forCamera(camera: camera, eventTarget: canvas);
final viewport = CanvasViewport.forCanvas(
  cgl: cgl,
  canvas: canvas,
  camera: camera,
  renderPass: pass,
);

// In requestAnimationFrame, use zero for the first delta.
controls.update(deltaSeconds);
if (viewport.update()) pass.draw();
```

Calculate `deltaSeconds` by dividing the difference between consecutive
animation frame timestamps by 1000. Scale automatic orbit motion by elapsed
seconds as well.

Keyboard events come from the explicit target. Set `canvas.tabIndex = 0` so
a primary click can focus the canvas, or call `canvas.focus()`.
`disable()` detaches listeners and clears held keys and pending deltas.
`enable()` attaches fresh listeners. Call `await controls.dispose()` at
teardown. Drag sensitivity is in radians per CSS pixel. Wheel input is
normalized from pixel, line and page modes. Apply elapsed time to keyboard
motion and consume accumulated drag and wheel deltas once per update.

Replace `PerspectiveResizeAware` and `RenderPhaseResizeAware` with one
`CanvasViewport.forCanvas`. Give the canvas an explicit CSS size. The viewport
observes element size and pixel density. Use `pixelRatio:` to override the
device pixel ratio. It uses actual drawing-buffer dimensions and preserves
explicit orthographic bounds. `setViewport` accepts physical pixel coordinates
with a bottom-left origin. Manage offscreen attachment sizes separately. Call
`viewport.dispose()` to disconnect the observers.

While the canvas is hidden or zero-sized, `update()` returns false and keeps
the last valid projection. `RenderPass.draw()` skips empty viewports.
Legacy orbit and resize classes retain their previous behavior. Migrate each
camera and its screen pass together. [Orbit camera example](example/orbit_camera/orbit_camera.dart)
· [Torus-knot camera example](example/torusknot_camera/torusknot_camera.dart)

## Web and miscellaneous helpers

The web helpers and miscellaneous helpers now use `package:web` and
`dart:js_interop`. The deprecated `Keyboard(null)` and `Mouse(null)`
constructors continue to listen on the document. Existing SDK DOM elements
remain accepted by legacy adapters in JavaScript builds.
[Legacy DOM compatibility](#legacy-dom-compatibility)

Helpers that create elements now return the corresponding `package:web` types:

| Helper | Return type |
| --- | --- |
| `loadImage` | `Future<web.HTMLImageElement>` |
| `loadCubeImages` | `List<Future<web.HTMLImageElement>>` |
| `loadVideo` | `Future<web.HTMLVideoElement>` |
| `makeVideoElementFromCamera` | `Future<web.HTMLVideoElement?>` |
| `makeSolidColorCanvas`, example `createParticleCanvas` | `web.HTMLCanvasElement` |

Update explicitly typed callbacks and variables to these types, or let Dart
infer the callback parameter type. Use the matching named `ImageTexture`
constructor for images, canvas elements and video. Pass cube images to
`CubeTexture.fromImages` in the order `nx`, `px`, `ny`, `py`, `nz`, `pz`.

`loadRaw` and `loadJson` now report HTTP and network failures through their
returned futures. Invalid JSON also completes with an error. Failed image and
video loads complete with an error instead of leaving the future pending.
Video helpers still wait for `playing` before returning. Camera capture uses
`navigator.mediaDevices.getUserMedia`, returns a muted inline video, and keeps
the nullable failure result. A stream is stopped if video initialization fails.

The helper tests import the public package entry point and can run with either
JavaScript or Wasm:

```sh
dart test -p golden_chrome test/webhelper_interop_test.dart
dart test -p golden_chrome -c dart2wasm test/webhelper_interop_test.dart
```

## Examples and browser callbacks

The examples use `package:web` and `dart:js_interop`. Convert Dart callbacks
with `.toJS` and browser promises with `.toDart`. Cache a JavaScript callback
when reusing it, as in an animation loop:

```dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void main() {
  late final JSFunction onFrame;
  void animate(double timeMs) {
    // Update and draw the scene.
    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;
  web.window.requestAnimationFrame(onFrame);
}
```

See [example/simple/simple.dart](example/simple/simple.dart) for a complete
scene. Camera examples request camera access, and the MIDI example connects
after the user selects **Connect MIDI**.

## Validate the migration

Analyze your application after changing imports and names. Build and exercise
each browser target you ship. Check camera pose and lighting after `lookAt`,
resize or hide and restore a canvas, and confirm that leaving a scene releases
its input, media and GPU resources. If your application still uses legacy SDK
DOM objects, exercise that path in a JavaScript build.

For engine changes, select the affected suites. The CI workflow covers
analysis, VM and browser tests, golden regression detection and the release
gallery build. JavaScript and Wasm render against the same reference images.
[Targeted tests](README.md#tests-and-rendering-goldens)
· [CI workflow](.github/workflows/tests.yml)
· [Golden test guide](test/goldens/README.md)
