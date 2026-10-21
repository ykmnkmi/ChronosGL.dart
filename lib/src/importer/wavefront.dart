part of 'lib.dart';

// https://en.wikipedia.org/wiki/Wavefront_.obj_file

GeometryBuilder importGeometryFromWavefront(String text) {
  GeometryBuilder gb = GeometryBuilder();
  gb.enableAttribute(aTexUV);
  gb.enableAttribute(aNormal);

  // This is a map which associates a range of indices with a name
  // The name comes from the 'g' tag (of the form "g NAME"). Indices
  // are part of one group until another 'g' tag is seen. If any indices
  // come before a 'g' tag, it is given the group name "_unnamed"
  // 'group' is an object whose property names are the group name and
  // whose value is a 2 element array with [<first index>, <num indices>]
  Map<String, int> groups = {};

  final RegExp lineEnd = RegExp(r"\s*\n");
  final RegExp sep = RegExp(r"\s+");

  final List<vm.Vector3> vertices = [];
  final List<vm.Vector3> normals = [];
  final List<vm.Vector2> uvs = [];

  final DateTime start = DateTime.now();

  final List<vm.Vector3> faceVertices = [];
  final List<vm.Vector3> faceNormal = [];
  final List<vm.Vector2> faceUvs = [];

  final List<String> lines = text.split(lineEnd);

  for (String line in lines) {
    // ignore comments
    if (line.isEmpty || line[0] == "#") continue;
    List<String> array = line.split(sep);
    assert(array.isNotEmpty);
    assert(array.last.isNotEmpty);

    //print("### ${array}");

    if (array[0] == "g") {
      groups[array[1]] = vertices.length;
    } else if (array[0] == "v") {
      vertices.add(
        vm.Vector3(
          double.parse(array[1]),
          double.parse(array[2]),
          double.parse(array[3]),
        ),
      );
    } else if (array[0] == "vt") {
      uvs.add(vm.Vector2(double.parse(array[1]), double.parse(array[2])));
    } else if (array[0] == "vn") {
      normals.add(
        vm.Vector3(
          double.parse(array[1]),
          double.parse(array[2]),
          double.parse(array[3]),
        ),
      );
    } else if (array[0] == "f") {
      // face
      if (array.length != 4 && array.length != 5) {
        print("*** Error: face '$line' not handled");
        continue;
      }

      faceVertices.clear();
      faceNormal.clear();
      faceUvs.clear();

      for (int i = 1; i < array.length; ++i) {
        // add a new entry to the map and arrays
        List<String> f = array[i].split("/");
        assert(f.isNotEmpty);
        while (f.length < 3) {
          f.add("");
        }

        // TODO: support negative indices
        final int vtx = int.parse(f[0]) - 1;
        final int tex = f[1] == "" ? -1 : int.parse(f[1]) - 1;
        final int nor = f[2] == "" ? -1 : int.parse(f[2]) - 1;

        if (vtx < vertices.length) {
          faceVertices.add(vertices[vtx]);
        } else {
          faceVertices.add(vm.Vector3.zero());
        }

        if (uvs.isEmpty) {
          faceUvs.add(vm.Vector2.zero());
        } else if (tex != -1 && tex < uvs.length) {
          faceUvs.add(uvs[tex]);
        } else {
          logWarn("problem uv $i $tex");
          faceUvs.add(vm.Vector2.zero());
        }
        if (normals.isEmpty) {
          faceNormal.add(vm.Vector3.zero());
        } else if (nor != -1 && nor < normals.length) {
          faceNormal.add(normals[nor]);
        } else {
          logWarn("problem normals $i $nor");
          faceNormal.add(vm.Vector3.zero());
        }
      }
      if (array.length == 4) {
        gb.addVerticesFace3TakeOwnership(faceVertices);
      } else {
        gb.addVerticesFace4TakeOwnership(faceVertices);
      }
      gb.addAttributesVector3(aNormal, faceNormal);
      gb.addAttributesVector2(aTexUV, faceUvs);
    }
  }
  final Duration delta = DateTime.now().difference(start);
  logInfo("Wavefront loaded in ($delta) $gb");
  return gb;
}
