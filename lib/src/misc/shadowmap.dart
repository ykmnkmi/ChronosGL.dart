part of 'lib.dart';

// Code for dealing with ShadowMaps

// Efficient Shadow Volume Rendering
// http://http.developer.nvidia.com/GPUGems/gpugems_ch09.html

// Cinematic Lighting
// http://http.developer.nvidia.com/GPUGems/gpugems_ch10.html

// Shadow Map Antialiasing
// http://http.developer.nvidia.com/GPUGems/gpugems_ch11.html

// Omnidirectional Shadow Mapping
// http://http.developer.nvidia.com/GPUGems/gpugems_ch12.html

// Generating Soft Shadows Using Occlusion Interval Maps
// http://http.developer.nvidia.com/GPUGems/gpugems_ch13.html

// Perspective Shadow Maps: Care and Feeding
// http://http.developer.nvidia.com/GPUGems/gpugems_ch14.html

// http://www.geeks3d.com/20091216/geexlab-how-to-visualize-the-depth-buffer-in-glsl/
// https://www.gamedev.net/resources/_/technical/graphics-programming-and-theory/3d-basics-r673
// http://stackoverflow.com/questions/21318471/rendering-orthographic-shadowmap-to-screen
// http://stackoverflow.com/questions/21318471/rendering-orthographic-shadowmap-to-screen
const String shadowMapShaderLib = """

float GetShadow(vec3 depth, sampler2DShadow shadowMap, float bias1, float bias2) {
    depth.z = depth.z - bias1;
    return texture(shadowMap, depth);
    //return 1.0 - smoothstep(bias1, bias2, depth.z - d);
}
""";

/*
float perspectiveDepthToViewZ(float z, float near, float far) {
    return near * far / ((far - near) * z - far);
}

float viewZToOrthographicDepth(float z, float near, float far) {
    return (z + near) / (near - far);
}

float orthographicDepthToViewZ(float d, float near, float far) {
    return d * (near - far) - near;
}

float viewZToPerspectiveDepth(float z, float near, float far) {
    return ((near + z) * far) / ((far - near) * z);
}

float LinearizeDepth(float z, float near, float far) {
 return (2.0 * near) / (far + near - z * (far - near));
}
*/
final ShaderObject shadowVertexShaderDepth = ShaderObject("ShadowMapV")
  ..addAttributeVars([aPosition])
  ..addUniformVars([uLightPerspectiveViewMatrix, uModelMatrix])
  ..setBody([
    """
void main() {
    gl_Position = $uLightPerspectiveViewMatrix * $uModelMatrix *
                  vec4($aPosition, 1.0);
}
    """,
  ]);

final ShaderObject shadowFragmentShaderDepth =
    // What we care about here is the internal update of the depth buffer
    ShaderObject("ShadowMapF")..setBodyWithMain(["$oFragColor.r = 1.0;"]);

final ShaderObject visualizeShadowmapVertexShaderLinearDepth16 =
    ShaderObject("copyV")
      ..addAttributeVars([aPosition, aTexUV])
      ..addVaryingVars([vTexUV])
      ..setBody([nullVertexShaderWithTextureForwardString]);

final ShaderObject visualizeShadowmapFragmentShaderLinearDepth16 =
    ShaderObject("copyF")
      ..addVaryingVars([vTexUV])
      ..addUniformVars([
        uTexture,
        // uCutOff,
        uCameraFar, uCameraNear,
      ])
      ..setBody([
        """
void main() {     
   float d = texture($uTexture,  $vTexUV).x;
   float near = $uCameraNear;
   float far = $uCameraFar;
   float gray = (2.0 * near) / (far + near - d * (far - near));
   $oFragColor.rgb = vec3(gray);
   // $oFragColor.rgb = vec3(d >= $uCutOff ? d : 0.0);
   // $oFragColor.rgb = vec3(d);
}
""",
      ]);

class ShadowMap {
  // Other options for format:  glDepthComponent32f
  ShadowMap(
    this._cgl,
    int w,
    int h,
    double near,
    double far, {
    int format = glDepthComponent24,
  }) {
    _mapSize = vm.Vector2(w + 0.0, h + 0.0);
    // We do not really need a proper frame buffer texture as we are only
    // concerned about updated the depth buffer.
    // TODO: is there a way to disable the framebuffer writes altogether?
    Texture dummy = TypedTexture(
      _cgl,
      "frame::color",
      w,
      h,
      glRgba8,
      texturePropertiesFramebuffer,
    );
    _depthTexture = TypedTexture(
      _cgl,
      "frame::depth",
      w,
      h,
      format,
      texturePropertiesShadowMap,
    );
    _shadowBuffer = Framebuffer(_cgl, dummy, _depthTexture);
    _phaseCompute = RenderPhase("compute-shadow", _cgl, _shadowBuffer)
      ..viewPortW = w
      ..viewPortH = h;

    _uniforms
      ..setUniform(uTexture, getMapTexture())
      // for visualization only:
      ..setUniform(uCutOff, 0.0)
      ..setUniform(uCameraNear, near)
      ..setUniform(uCameraFar, far);

    _programCompute = Scene(
      "shadowCompute",
      RenderProgram(
        "shadowCompute",
        _cgl,
        shadowVertexShaderDepth,
        shadowFragmentShaderDepth,
      ),
      [_uniforms],
    );
    _phaseCompute.add(_programCompute);

    // We do not clear the color buffer for visualization, so Visualize
    // should be called as the last thing touching the framebuffer.
    _phaseVisualize = RenderPhase("visualize-shadow", _cgl)
      ..clearColorBuffer = false;

    _programVisualize = Scene(
      "shadowVisualize",
      RenderProgram(
        "shadowVisualize",
        _cgl,
        visualizeShadowmapVertexShaderLinearDepth16,
        visualizeShadowmapFragmentShaderLinearDepth16,
      ),
      [_uniforms],
    );

    _programVisualize.add(unitNode(_programVisualize.program));
    _phaseVisualize.add(_programVisualize);
  }

  final ChronosGL _cgl;
  late Texture _depthTexture;
  late RenderPhase _phaseCompute;
  late Framebuffer _shadowBuffer;
  late Scene _programCompute;

  late RenderPhase _phaseVisualize;
  final UniformGroup _uniforms = UniformGroup("uniforms");

  late Scene _programVisualize;

  late vm.Vector2 _mapSize;

  void setVisualizationViewPort(int x, int y, int w, int h) {
    _phaseVisualize
      ..viewPortX = x
      ..viewPortY = y
      ..viewPortW = w
      ..viewPortH = h;
  }

  void addShadowCaster(Node node) {
    _programCompute.add(node);
  }

  void clearShadowCasters() {
    _programCompute.removeAll();
  }

  // TODO: this should take a Illumination instance as an argument eventually
  void compute(vm.Matrix4 lightMatrix) {
    _uniforms.forceUniform(uLightPerspectiveViewMatrix, lightMatrix);
    _phaseCompute.draw();
  }

  void visualize() {
    // Total hack! TextureSamplers could make this nicer
    _cgl.bindTexture(glTexture2D, _depthTexture.getTexture());
    _cgl.texParameteri(glTexture2D, glTextureCompareMode, glNone);
    // Should we have chosen glNearest when we set up the texture?
    _cgl.texParameteri(glTexture2D, glTextureMagFilter, glNearest);
    _cgl.texParameteri(glTexture2D, glTextureMinFilter, glNearest);
    _cgl.bindTexture(glTexture2D, null);
    _phaseVisualize.draw([]);

    _cgl.bindTexture(glTexture2D, _depthTexture.getTexture());
    _cgl.texParameteri(
      glTexture2D,
      glTextureCompareMode,
      glCompareRefToTexture,
    );
    _cgl.texParameteri(glTexture2D, glTextureMagFilter, glLinear);
    _cgl.texParameteri(glTexture2D, glTextureMinFilter, glLinear);
    _cgl.bindTexture(glTexture2D, null);
  }

  vm.Vector2 getMapSize() => _mapSize;

  Texture getMapTexture() => _depthTexture;
}
