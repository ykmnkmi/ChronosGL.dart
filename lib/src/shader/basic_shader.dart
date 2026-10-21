part of 'lib.dart';

//  Gouraud shading - most action happens in vertext shader - cheaper
final ShaderObject lightVertexShaderGourad = ShaderObject("LightGouradV")
  ..addAttributeVars([aPosition, aNormal, aTexUV])
  ..addVaryingVars([vColor])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
  ..addUniformVars([uLightDescs, uLightTypes, uShininess])
  ..addUniformVars([uEyePosition, uTexture])
  ..setBody(
    [
      """
void main() {
    vec4 pos = $uModelMatrix * vec4($aPosition, 1.0);
    gl_Position = $uPerspectiveViewMatrix * pos;
    vec3 normal = $uNormalMatrix * $aNormal;

    ColorComponents acc = CombinedLight(pos.xyz, normal, $uEyePosition,
                  $uLightDescs,
                  $uLightTypes,
                  $uShininess);

     $vColor = acc.diffuse +
                 acc.specular +
                 texture($uTexture, $aTexUV).rgb;
}
        """,
    ],
    prolog: [stdLibShader],
  );

final ShaderObject lightFragmentShaderGourad = ShaderObject("LightGrouradV")
  ..addVaryingVars([vColor])
  ..setBodyWithMain(["$oFragColor = vec4($vColor, 1.0 );"]);

// Phong shader - most action happens in fragment shader - expensive
// Light Matrix m organization:
// m[0].xyz light direction
//
final ShaderObject lightVertexShaderBlinnPhong =
    ShaderObject("LightBlinnPhongV")
      ..addAttributeVars([aPosition, aNormal, aTexUV])
      ..addVaryingVars([vPosition, vNormal, vTexUV])
      ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
      ..setBody([
        """
void main() {
    vec4 pos = $uModelMatrix * vec4($aPosition, 1.0);
    gl_Position = $uPerspectiveViewMatrix * pos;
    $vPosition = pos.xyz;
    $vTexUV = $aTexUV;
    $vNormal = $uNormalMatrix * $aNormal;
}
""",
      ]);
final ShaderObject lightFragmentShaderBlinnPhong =
    ShaderObject("LightBlinnPhongF")
      ..addVaryingVars([vPosition, vNormal, vTexUV])
      ..addUniformVars([uLightDescs, uLightTypes, uShininess])
      ..addUniformVars([uEyePosition, uTexture])
      ..setBodyWithMain(
        [
          """
ColorComponents acc = CombinedLight($vPosition,
                                    $vNormal,
                                    $uEyePosition,
                                    $uLightDescs,
                                    $uLightTypes,
                                    $uShininess);

$oFragColor.rgb = acc.diffuse +
                    acc.specular +
                    texture($uTexture, $vTexUV).rgb;
$oFragColor.a = 1.0;
""",
        ],
        prolog: [stdLibShader],
      );
