part of 'lib.dart';

final ShaderObject texturedVertexShader = ShaderObject("Textured")
  ..addAttributeVars([aPosition, aTexUV])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..addVaryingVars([vTexUV])
  ..setBody([stdVertexShaderWithTextureForwardString]);

final ShaderObject texturedFragmentShader = ShaderObject("TexturedF")
  ..addVaryingVars([vTexUV])
  ..addUniformVars([uColor, uTexture])
  ..setBodyWithMain([
    "$oFragColor = texture($uTexture, $vTexUV) + vec4( $uColor, 0.0 );",
  ]);

final ShaderObject solidColorVertexShader = ShaderObject("SolidColor")
  ..addAttributeVars([aPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..setBodyWithMain([stdVertexBody]);

final ShaderObject solidColorFragmentShader = ShaderObject("SolidColorF")
  ..addUniformVars([uColor])
  ..setBodyWithMain(["$oFragColor = vec4( $uColor, 1.0 );"]);

// this shader works well for cube shapes,
// for other shapes it might be better to use the normals attribute
// to sample the cube texture
final ShaderObject cubeMapVertexShader = ShaderObject("CubeMap")
  ..addAttributeVars([aPosition])
  ..addVaryingVars([vPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..setBodyWithMain([stdVertexBody, "$vPosition = normalize($aPosition);"]);

final ShaderObject cubeMapFragmentShader = ShaderObject("CubeMapF")
  ..addVaryingVars([vPosition])
  ..addUniformVars([uCubeTexture])
  ..setBodyWithMain(["$oFragColor = texture( $uCubeTexture, $vPosition );"]);

final ShaderObject pointSpritesVertexShader = ShaderObject("PointSpritesV")
  ..addAttributeVars([aPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uPointSize])
  ..setBodyWithMain([
    stdVertexBody,
    "gl_PointSize = $uPointSize/gl_Position.z;",
  ]);

final ShaderObject pointSpritesFragmentShader = ShaderObject("PointSpritesF")
  ..addUniformVars([uTexture])
  ..setBodyWithMain(["$oFragColor = texture( $uTexture,  gl_PointCoord);"]);

final ShaderObject demoVertexShader = ShaderObject("FixedVertexColorV")
  ..addAttributeVars([aPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..addVaryingVars([vColor])
  ..setBodyWithMain(
    [stdVertexBody, "$vColor = ColorFromPosition($aPosition);"],
    prolog: [stdLibShader],
  );

final ShaderObject demoFragmentShader = ShaderObject("FixedVertexColorF")
  ..addVaryingVars([vColor])
  ..setBodyWithMain(["$oFragColor = vec4( $vColor, 1.0 );"]);

final ShaderObject multiColorVertexShader =
    ShaderObject("MultiColorVertexColorV")
      ..addAttributeVars([aPosition, aColor])
      ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..addVaryingVars([vColor])
      ..setBodyWithMain(
        [stdVertexBody, "$vColor = $aColor;"],
        prolog: [stdLibShader],
      );

final ShaderObject multiColorFragmentShader =
    ShaderObject("MultiColorVertexColorF")
      ..addVaryingVars([vColor])
      ..setBodyWithMain(["$oFragColor = vec4( $vColor, 1.0 );"]);
