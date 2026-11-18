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

## Supported public API (refactoring phase 7)

Import supported modules rather than implementation paths under `src/`:

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
| `scene.dart` | Nodes, batches and passes | Browser |
| `shadows.dart` | Shadow map computation | Browser |
| `web.dart` | Input, controls, viewport, URL loading and browser assets | Browser |
| `debug.dart` | Statistics panels and visualizers | Browser, explicit import |

`chronosgl.dart` combines the supported engine modules. It no longer exports
panels or visualizers: add `import 'package:chronosgl/debug.dart';` where they
are used. `mesh.dart` remains a supported focused import for GPU mesh uploads
and factories. Public exports use explicit name lists; new internal helpers do
not automatically become package API.

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
final vertex = ShaderObject.create(
  name: 'generated vertex',
  stage: ShaderStage.vertex,
)..setBodyWithMain(['gl_Position = vec4(0.0, 0.0, 0.0, 1.0);']);
final fragment = ShaderObject.fragment('solid fragment')
  ..setBodyWithMain(['$oFragColor = vec4(1.0);']);
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

`ShaderObject.vertex(name)` and `.fragment(name)` are convenient explicit
constructors. Attribute-free vertex shaders now work without stage inference.
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
milliseconds. Low-level animation sampling retains the clip's caller-selected
time units: keys, sample time and duration must match. This phase does not
normalize the existing ThreeJS and Assimp importers' time conventions. See
[the units audit](docs/1.3_UNITS_CONVENTIONS.md) for existing importer limitations.

### Errors and collection mutation

Handle `ArgumentError` for invalid inputs, `StateError` for invalid object
state (including disposed use), `UnsupportedError` for unsupported operations,
and `ShaderCompilationException` for shader compilation or program linking.
The shader exception carries the driver message, optional stage and source;
link failures have no stage. Public checks no longer rely on assertions or
throw string values.
Rendering controls and active uniform values are validated before changing
WebGL state, including controls supplied through legacy string setters.
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

See [the public API contract](docs/7.1_PUBLIC_API.md) for the module boundaries
and focused public-import validation.

## Scene graph and geometry (refactoring phase 5)

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

GPU meshes and programs expose immutable `attributeLayout` snapshots. Use
`mesh.isCompatibleWith(program)` before sharing across programs: the WebGL
context, required attribute names, locations, types, widths, and instancing
divisors must agree. Extra mesh bindings are allowed. An incompatible draw
throws `ArgumentError` before changing WebGL state; compatibility does not
replace populating the buffers or keeping resources alive. See the
[scene graph contract](docs/5.1_SCENE_GRAPH.md),
[CPU boundary](docs/5.7_CPU_GEOMETRY.md), and
[GPU layout contract](docs/5.8_MESH_LAYOUT.md).

## Helpers and settings (refactoring phase 6)

The aggregate import still exposes supported browser helpers. Use `mesh.dart`
for GPU mesh factories, `shadows.dart` for shadow computation, and `debug.dart`
for optional panels and visualizers. The former `src/misc/lib.dart` now contains
compatibility exports only. No package module depends on `example/`.

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

## Projection parameters (refactoring step 3.8)

Mathematical perspective cameras and projections use named `fovYRadians`,
`aspectRatio`, `near`, and `far`. The full vertical angle is in radians (default
`50 * pi / 180`); aspect is width / height (default `1`). Near and far are
required. All values must be finite, with `0 < fovYRadians < pi`,
`aspectRatio > 0`, and `0 < near < far`. Orthographic types require all six
ordered bounds and permit zero or negative near/far distances.

The API introduced in steps 3.2–3.3 is unchanged. `setProjection` requires all
named parameters, including unchanged values obtained from getters. Invalid
ranges and nonfinite/singular Float32 matrices throw `ArgumentError` while
preserving the previous projection object, parameters, matrices, and pose.
Legacy `Perspective.updateFov` still takes degrees. See the
[parameter contract and update example](docs/3.8_PROJECTION_PARAMETERS.md).

## Matrix access and updates (refactoring step 3.7)

Mathematical `Camera`, `Transform`, and `Projection` getters return independent
snapshots, including their typed storage. Setters take effect on the next read
without `update()`. Existing snapshots do not refresh automatically. Use camera
setters to edit the pose/projection, and `Transform.setMatrix(editedSnapshot)`
to commit a matrix edit; mutating a getter result only changes that snapshot.

To reuse output storage, cameras now provide `copyWorldMatrixInto(out)`,
`copyViewMatrixInto(out)`, `copyProjectionMatrixInto(out)`, and
`copyViewProjectionMatrixInto(out)`. They never retain the destination;
calculation failures leave it unchanged. The existing `copyMatrixInto(out)`
methods on transforms and projections follow the same ownership convention.

Legacy `Spatial.transform` remains live mutable state. Its `getViewMatrix(out)`
now rejects any output storage overlapping that pose, including a different
`Matrix4` wrapping the same list or buffer. Use a separate matrix for the view.
Legacy scratch vectors and uniform maps remain borrowed working values; copy
them explicitly when retaining them. See [the matrix access contract](docs/3.7_MATRIX_ACCESS.md).

## Transform component (refactoring step 3.1)

`package:chronosgl/core.dart` now exports the browser-independent `Transform`.
It is also available through `chronosgl.dart`. Its matrix always maps local
coordinates to parent coordinates, composed as translation * rotation * scale.
Inputs are copied and getters return snapshots; use setters or `setMatrix`
to change state. `lookAt` preserves position and scale and points local -Z
toward a target in parent space.

For a legacy object node, keep a `Transform` and call
`pose.copyMatrixInto(node.transform)` after changes and before drawing.
Do not copy a view matrix as an object pose. Since step 3.6, legacy
`Spatial.transform` also stores a pose; see the camera-position migration below.
See [the Transform contract and migration table](docs/3.1_TRANSFORM.md), including
explicit movement spaces and preservation of imported shear.

## Camera contract (refactoring step 3.2)

`package:chronosgl/camera.dart` exports the browser-independent `Camera`,
`PerspectiveCamera`, and `OrthographicCamera`; the same types are available
through `chronosgl.dart`. Both cameras own a world-space position and rotation.
`lookAt` preserves position, `viewMatrix` is the inverse world matrix, and
`viewProjectionMatrix` is `projectionMatrix * viewMatrix`. Getters return copies.

```dart
import 'package:chronosgl/camera.dart';
import 'package:vector_math/vector_math.dart' as vm;

final camera = PerspectiveCamera(near: 0.1, far: 1000, aspectRatio: 16 / 9)
  ..setPosition(0, 0, 10);
camera.lookAt(vm.Vector3.zero()); // World position remains (0, 0, 10).
```

Use `fovYRadians` for the full vertical angle; the default is 50 degrees expressed
in radians. Orthographic cameras require all six bounds explicitly and allow
zero or negative `near`. Use `setProjection` with all named parameters to change
the projection atomically. Neither camera observes canvas size or handles input.

These mathematical types are separate from legacy `Perspective(Spatial, ...)`
and `Orthographic(Spatial, ...)`. Use `CameraUniforms(camera)` from
`chronosgl.dart` to pass either new camera to rendering uniform lists. See
[the camera contract](docs/3.2_CAMERAS.md) for parameters and ownership, and
the adapter example below for rendering.

## Reusable projections (refactoring step 3.3)

`camera.dart` and `chronosgl.dart` now export `Projection`,
`PerspectiveProjection`, and `OrthographicProjection`. These immutable values
calculate view-to-clip matrices without a camera, uniforms, DOM, or GPU resources.
`matrix` returns a snapshot; `copyMatrixInto(out)` writes into caller-owned storage.
The parameters and validation match the corresponding cameras.

Existing camera constructors and `setProjection(...)` calls continue to work.
Use `PerspectiveCamera.fromProjection(projection, ...)` or
`OrthographicCamera.fromProjection(projection, ...)` to reuse an existing value.
The camera's `projection` getter returns that immutable value; `setProjection`
replaces it atomically without changing other cameras that share the old value.

For shadows, compose `projection.matrix..multiply(lightViewMatrix)` and pass
the result to `ShadowMap.compute`. Directional and spot lights now use these
projection classes internally, preserving their valid shadow matrices and cone
padding. Invalid shadow bounds, FOV, or clipping distances now throw
`ArgumentError` when `extractShadowProjViewMatrix()` is called. Legacy uniform
adapters and resize helpers keep their APIs. See [the projection contract and
shadow example](docs/3.3_PROJECTIONS.md).

## Camera pose storage (refactoring step 3.4)

The new cameras now store world position and normalized orientation directly.
World and view matrices are derived snapshots; reading them never changes the
pose. No calling-code changes are required. `lookAt` sets orientation once and
does not retain a target: moving afterwards preserves that orientation until
another orientation update.

Invalid pose edits leave both components intact. A view calculation that throws
`StateError` for Float32 overflow also leaves the pose readable and editable.
The legacy camera-position correction is described in step 3.6 below. See
[the pose storage contract](docs/3.4_CAMERA_POSE.md) for details and tests.

## Camera view matrix (refactoring step 3.5)

No calling-code changes are needed: the existing new-camera implementation
already computes `viewMatrix = inverse(worldMatrix)`. For `C = T(eye) * R`,
the view is `R^-1 * T(-eye)`, so a world point becomes `R^-1 * (point - eye)`.
View translation is `-R^-1 * eye`; use `worldPosition` to read the eye position.
Directions (homogeneous `w = 0`) receive only the inverse rotation.

Both camera types use the same calculation, independently of their projections.
The phase adds dedicated inverse-matrix regression coverage without changing
legacy cameras or uniforms. See [the view matrix contract](docs/3.5_VIEW_MATRIX.md).

## Preserved camera position (refactoring step 3.6)

`Spatial.lookAt(target, [up])` now preserves position and stores a local-to-parent
pose, or camera-to-world pose for an unparented camera. `getViewMatrix(out)`
computes its inverse into separate storage. `getPos()` and `getEyePosition()`
therefore return `(0, 0, 10)` after `setPos(0, 0, 10)` and `lookAt(Vector3.zero())`.
Repeated aiming and subsequent movement use the preserved position.

Both `Perspective` and `Orthographic` supply world-space `uEyePosition` alongside
`uPerspectiveViewMatrix = P * V`. Custom `Spatial` subclasses overriding
`getViewMatrix` and `getEyePosition` remain supported. The new mathematical
cameras keep their existing API and use `CameraUniforms` for rendering (3.9).

This corrects legacy behavior and may change existing scenes:

- Read the view through `getViewMatrix(out)`, not `transform`. When importing a
  precomputed view matrix, invert it before copying into `transform`.
- Direction getters and movement now use pose columns. `lookUp/Down`,
  `lookLeft/Right`, and `rollLeft/Right` rotate around local X, Y, and Z;
  up/left rotations use positive angles. Orbit roll preserves its target.
- A node's `lookAt` takes its target and up in parent space and preserves its
  local position. As before, this legacy operation discards scale/shear;
  use `Transform` to retain supported scale.
- Invalid `lookAt` arguments throw `ArgumentError` before changing the pose.
  A singular or nonfinite view inverse throws `StateError` without changing the
  output. Passing `transform` itself as view output throws `ArgumentError`.

Legacy matrices and scratch vectors remain mutable. Use copies when retaining
them; new cameras return snapshots. Camera parenting is not supported by this
legacy view API. See [the correction and regression tests](docs/3.6_CAMERA_POSITION.md).

## Camera uniforms (refactoring step 3.9)

Import `package:chronosgl/chronosgl.dart` in browser rendering code and wrap
either mathematical camera in `CameraUniforms(camera, [name])`:

```dart
final camera = PerspectiveCamera(near: 0.1, far: 1000)
  ..setPosition(0, 0, 10);
camera.lookAt(vm.Vector3.zero());
final uniforms = CameraUniforms(camera);
program.draw(mesh, [uniforms, material, transforms]);
// The same adapter can be passed to Scene('scene', program, [uniforms]).
```

The adapter borrows the camera and reads it on every draw; changing its pose or
projection needs no adapter update. `getUniforms()` returns a fresh map with
independent `uPerspectiveViewMatrix = P * V` and world-space `uEyePosition`
snapshots. The matrix name also applies to orthographic cameras. Supply object
transforms separately as before. Camera values override inherited uniform
setters; additional uniforms retain existing `UniformGroup` semantics.

`CameraUniforms` belongs to rendering and is not exported by `camera.dart` or
`core.dart`. Those mathematical entry points remain usable on the Dart VM.
Existing `Perspective`/`Orthographic` integrations can keep their APIs.
See [the adapter contract and tests](docs/3.9_CAMERA_UNIFORMS.md).

## Mathematical imports on the VM (refactoring step 3.10)

For command-line tools and VM tests, import the mathematical entry points:

```dart
import 'package:chronosgl/core.dart';
import 'package:chronosgl/camera.dart';
```

`core.dart` exports `Transform`; `camera.dart` exports the camera and projection
contracts and both perspective/orthographic implementations. Their transitive
dependencies contain no DOM, WebGL, or rendering adapters. The existing exports
and mathematical behavior are unchanged.

Replace the aggregate `chronosgl.dart` import in mathematical VM code with these
imports. The aggregate remains the browser entry point and includes
`CameraUniforms`, WebGL resources, scenes, and browser helpers. The internal
`src/core/lib.dart` is also browser-dependent; its name does not make it the
public mathematical core. Other CPU modules are separated in later phases.

A standalone kernel compilation and execution check now protects this boundary.
See [the import contract and VM example](docs/3.10_VM_MATH_IMPORTS.md).

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
| `GeometryBuilderToMeshData` | `geometryBuilderToMeshData` |
| `ImportGeometryFromWavefront` | `importGeometryFromWavefront` |
| `LoadJson` | `loadJson` |
| `GeometryBuilder.AddVertices` | `GeometryBuilder.addVertices` |
| `GeometryBuilder.GenerateFaceIndices` | `GeometryBuilder.generateFaceIndices` |
| `UniformGroup.SetUniform` | `UniformGroup.setUniform` |
| `UniformGroup.GetUniforms` | `UniformGroup.getUniforms` |
| `RenderProgram.Draw` | `RenderProgram.draw` |
| `RenderPhase.Draw` | `RenderPhase.draw` |
| `Node.UpdateModelMatrix` | `Node.updateModelMatrix` |
| `Node.Container` | `Node.container` |
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
Named constructors retain their class name, as in `Node.container`.

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
| `RIGHTX`, `UPY`, `POSZ` | `rightX`, `upY`, `posZ` |
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
| `NO_WEBGL_MESSAGE` | `noWebglMessage` |
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

Constant values, GLSL text, attribute/uniform names, and rendering reference
images are unchanged. Diagnostic strings such as `"GL_RGBA"` still use the
standard WebGL spelling. This rename applies to ChronosGL's declarations;
constant names supplied by the Dart SDK or other dependencies are unchanged.

## Core WebGL bindings

The core wrapper now uses `package:web` and `dart:js_interop` instead of
`dart:web_gl`. The `GlBuffer`, `GlTexture`, `GlProgram`, and other `Gl*` aliases
refer to the corresponding `package:web` WebGL types. Buffer, texture, uniform,
and pixel APIs still accept Dart typed data, including views with byte offsets.

`ChronosGL` and image textures accept browser objects from both `package:web`
and the existing SDK browser libraries. For new core callers:

```dart
import 'package:chronosgl/chronosgl.dart';
import 'package:web/web.dart' as web;

final canvas = web.HTMLCanvasElement()
  ..width = 640
  ..height = 480;
final cgl = ChronosGL(canvas);
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

## Camera controls and canvas sizing (refactoring phase 4)

Use `OrbitControls(camera, eventTarget)` with a mathematical `PerspectiveCamera`
or `OrthographicCamera` instead of combining pose and input in `OrbitCamera`.
Both components are exported by `package:chronosgl/chronosgl.dart`. Render with
`CameraUniforms(camera)` and call `controls.update(deltaSeconds)`, converting
RAF timestamp differences to seconds at the application boundary. The first
real callback has a zero delta. Automatic orbit motion in examples must also
scale by elapsed seconds.

Keyboard events now come from the explicit target. For a canvas, set
`canvas.tabIndex = 0` and focus it before typing. Disable detaches listeners and
clears held keys and pending deltas; enable attaches fresh listeners. Dispose
with `await controls.dispose()`. The borrowed camera remains usable afterward.
Drag sensitivity is radians per CSS pixel; wheel input is normalized from
pixel, line and page modes, and neither delta is multiplied by elapsed time.

Replace `PerspectiveResizeAware` and `RenderPhaseResizeAware` with one
`CanvasViewport(cgl, canvas, camera, renderPhase: phase)`. Set the canvas CSS
size explicitly and call `if (viewport.update()) phase.draw()` before drawing.
The component observes element size and pixel density; `pixelRatio:` overrides
device DPR. It uses actual drawing-buffer dimensions and preserves explicit
orthographic bounds. `setViewport` accepts physical pixel coordinates for a
partial screen viewport. Offscreen framebuffer attachments retain their own
size and lifecycle. Call `viewport.dispose()` when finished.

A hidden or zero-size canvas preserves the last valid projection and reports
not ready until restored. `RenderPhase.draw()` skips an empty viewport.
Legacy orbit and resize classes remain available with their previous behavior;
migrate each camera and render phase together. See the
[controls](docs/4.1_ORBIT_CONTROLS.md),
[viewport](docs/4.5_CANVAS_VIEWPORT.md), and
[example trajectory](docs/4.9_EXAMPLE_CONTROLLERS.md) contracts.

## Web and miscellaneous helpers

The web helpers and miscellaneous helpers now use `package:web` and
`dart:js_interop`. No library under `lib/` imports the legacy SDK browser
libraries. Existing DOM elements can still be passed to `Keyboard`, `Mouse`,
`OrbitCamera`, `Stats`, `StatsFps`, `RenderPhaseResizeAware`, and
`PerspectiveResizeAware` while applications migrate. `Keyboard(null)` and
`Mouse(null)` continue to listen on the document.

Helpers that create elements now return the corresponding `package:web` types:

| Helper | Return type |
| --- | --- |
| `loadImage` | `Future<web.HTMLImageElement>` |
| `loadCubeImages` | `List<Future<web.HTMLImageElement>>` |
| `loadVideo` | `Future<web.HTMLVideoElement>` |
| `makeVideoElementFromCamera` | `Future<web.HTMLVideoElement?>` |
| `makeSolidColorCanvas`, example `createParticleCanvas` | `web.HTMLCanvasElement` |

Update explicitly typed callbacks and variables to these types, or let Dart
infer the callback parameter type. `ImageTexture` and `CubeTexture` accept these
elements directly. Cube faces retain the order `nx`, `px`, `ny`, `py`, `nz`, `pz`.

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

From a checkout of this repository, run the VM and JavaScript suites, then the
Wasm browser suites with the same rendering references:

```sh
dart pub get --enforce-lockfile
dart analyze
dart test -P all
dart test -P all -p golden_chrome -c dart2wasm
dart run tool/goldens.dart --self-check
```

The legacy DOM compatibility test intentionally retains SDK browser imports
and runs only with JavaScript. See [the golden test guide](test/goldens/README.md)
for Chrome setup, the reference environment, and failure diagnostics.
