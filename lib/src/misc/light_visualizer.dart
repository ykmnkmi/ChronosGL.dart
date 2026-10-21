part of 'lib.dart';

MeshData emptyLightVisualizer(RenderProgram prog, String name) {
  MeshData md = prog.makeMeshData(name, glLines);
  md.addVertices(Float32List(3));
  md.addFaces([0, 0]);
  return md;
}

void updateDirectionalLightVisualizer(
  MeshData md,
  double dim,
  double delta,
  vm.Vector3 dir,
) {
  if (dir.y == 0.0) {
    return;
  }
  final double d = dim * 0.5;
  final double end = delta * (d / delta).floor();
  final double start = -end;
  final vm.Vector3 dir2y = dir * d / dir.y;
  List<vm.Vector3> points = [];
  for (double x = start; x <= end; x += delta) {
    for (double z = start; z <= end; z += delta) {
      // we have an intersection  point with xz plane, now get the
      // intersection with the top and bottom face of the cube
      points.add(vm.Vector3(x, 0.0, z)..add(dir2y));
      points.add(vm.Vector3(x, 0.0, z)..sub(dir2y));
    }
  }
  for (int i = 0; i < 8; ++i) {
    int x = ((i & 1) == 1) ? 1 : -1;
    int y = ((i & 2) == 2) ? 1 : -1;
    int z = ((i & 4) == 4) ? 1 : -1;
    if (x > 0) {
      points.add(vm.Vector3(x * d, y * d, z * d));
      points.add(vm.Vector3(-x * d, y * d, z * d));
    }
    if (y > 0) {
      points.add(vm.Vector3(x * d, y * d, z * d));
      points.add(vm.Vector3(x * d, -y * d, z * d));
    }
    if (z > 0) {
      points.add(vm.Vector3(x * d, y * d, z * d));
      points.add(vm.Vector3(x * d, y * d, -z * d));
    }
  }

  md.changeVertexData(flattenVector3List(points));
  List<int> faces = List.generate(points.length, (index) => index);
  md.changeFaces(faces);
}

vm.Vector3 getOrthogonalVector3(vm.Vector3 dir) {
  if (dir.x != 0.0) {
    if (dir.y != 0.0) return vm.Vector3(-dir.y, dir.x, 0.0);
    if (dir.z != 0.0) return vm.Vector3(-dir.z, 0.0, dir.x);
    return vm.Vector3(0.0, 1.0, 1.0);
  } else {
    if (dir.y == 0.0) return vm.Vector3(1.0, 1.0, 0.0);
    if (dir.z == 0.0) return vm.Vector3(1.0, 0.0, 1.0);
    return vm.Vector3(0.0, -dir.z, dir.y);
  }
}

void updateSpotLightVisualizer(
  MeshData md,
  vm.Vector3 pos,
  vm.Vector3 dir,
  double range,
  double angle,
) {
  final int kSpines = 8;
  vm.Vector3 center = pos + dir.normalized() * range;
  List<vm.Vector3> points = [pos, center];
  vm.Vector3 ortho = getOrthogonalVector3(dir)
    ..normalize()
    ..scale(math.tan(angle) * range);
  for (int i = 0; i < kSpines; i++) {
    vm.Vector3 p = ortho.clone()
      ..applyAxisAngle(dir, i * 2.0 * math.pi / kSpines)
      ..add(center);
    points.add(p);
  }
  List<int> faces = [];
  for (int i = 1; i < points.length; ++i) {
    faces.add(0);
    faces.add(i);
  }

  // funnel
  for (int i = 3; i < points.length; ++i) {
    faces.add(i - 1);
    faces.add(i);
  }
  faces.add(points.length - 1);
  faces.add(2);

  // cross
  for (int i = 2; i < points.length; ++i) {
    if (i % 2 == 0) {
      faces.add(1);
      faces.add(i);
    }
  }
  md.changeVertexData(flattenVector3List(points));
  md.changeFaces(faces);
}

void updatePointLightVisualizer2(MeshData md, vm.Vector3 pos, double range) {
  List<vm.Vector3> points = [];
  List<int> faces = [];
  // Rays from center
  for (vm.Vector3 v in icosahedronVertexList) {
    faces.add(points.length);
    faces.add(icosahedronVertexList.length);
    points.add(pos + (v * range));
  }
  points.add(pos);

  // Faces
  for (Face3 f in icosahedronFaceList) {
    faces.add(f.a);
    faces.add(f.b);
    faces.add(f.b);
    faces.add(f.c);
    faces.add(f.c);
    faces.add(f.a);
  }

  md.addVertices(flattenVector3List(points));
  md.changeFaces(faces);
}

void updatePointLightVisualizer(MeshData md, vm.Vector3 pos, double range) {
  List<vm.Vector3> points = [];
  List<int> faces = [];
  // Rays from center
  for (vm.Vector3 v in icosahedronVertexList) {
    faces.add(points.length);
    faces.add(icosahedronVertexList.length);
    points.add(pos + (v * range));
  }
  points.add(pos);
  md.changeVertexData(flattenVector3List(points));
  md.changeFaces(faces);
}

void updateLightVisualizer(MeshData md, Light light) {
  if (light is DirectionalLight) {
    DirectionalLight dl = light;
    updateDirectionalLightVisualizer(md, dl.dim, dl.dim / 4, dl.dir);
  } else if (light is SpotLight) {
    SpotLight sl = light;
    updateSpotLightVisualizer(md, sl.pos, sl.dir, sl.range, sl.angle);
  } else if (light is PointLight) {
    PointLight pl = light;
    updatePointLightVisualizer(md, pl.pos, pl.range);
  } else {
    assert(false, "unknown light: ${light.runtimeType}");
  }
}

MeshData lightVisualizer(RenderProgram prog, Light light) {
  MeshData md = emptyLightVisualizer(prog, "dirLightViz");
  updateLightVisualizer(md, light);
  return md;
}
