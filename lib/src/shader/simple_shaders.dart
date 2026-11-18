part of 'lib.dart';

final ShaderObject texturedVertexShader = ShaderObject.vertex("Textured")
  ..addAttributeVars([aPosition, aTexUV])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..addVaryingVars([vTexUV])
  ..setBody([stdVertexShaderWithTextureForwardString]);

final ShaderObject texturedFragmentShader = ShaderObject.fragment("TexturedF")
  ..addVaryingVars([vTexUV])
  ..addUniformVars([uColor, uTexture])
  ..setBodyWithMain([
    "$oFragColor = texture($uTexture, $vTexUV) + vec4( $uColor, 0.0 );",
  ]);

final ShaderObject solidColorVertexShader = ShaderObject.vertex("SolidColor")
  ..addAttributeVars([aPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..setBodyWithMain([stdVertexBody]);

final ShaderObject solidColorFragmentShader =
    ShaderObject.fragment("SolidColorF")
      ..addUniformVars([uColor])
      ..setBodyWithMain(["$oFragColor = vec4( $uColor, 1.0 );"]);

// this shader works well for cube shapes,
// for other shapes it might be better to use the normals attribute
// to sample the cube texture
final ShaderObject cubeMapVertexShader = ShaderObject.vertex("CubeMap")
  ..addAttributeVars([aPosition])
  ..addVaryingVars([vPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..setBodyWithMain([stdVertexBody, "$vPosition = normalize($aPosition);"]);

final ShaderObject cubeMapFragmentShader = ShaderObject.fragment("CubeMapF")
  ..addVaryingVars([vPosition])
  ..addUniformVars([uCubeTexture])
  ..setBodyWithMain(["$oFragColor = texture( $uCubeTexture, $vPosition );"]);

final ShaderObject pointSpritesVertexShader =
    ShaderObject.vertex("PointSpritesV")
      ..addAttributeVars([aPosition])
      ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uPointSize])
      ..setBodyWithMain([
        stdVertexBody,
        "gl_PointSize = $uPointSize/gl_Position.z;",
      ]);

final ShaderObject pointSpritesFragmentShader =
    ShaderObject.fragment("PointSpritesF")
      ..addUniformVars([uTexture])
      ..setBodyWithMain(["$oFragColor = texture( $uTexture,  gl_PointCoord);"]);

final ShaderObject multiColorVertexShader =
    ShaderObject.vertex("MultiColorVertexColorV")
      ..addAttributeVars([aPosition, aColor])
      ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..addVaryingVars([vColor])
      ..setBodyWithMain(
        [stdVertexBody, "$vColor = $aColor;"],
        prolog: [stdLibShader],
      );

final ShaderObject multiColorFragmentShader =
    ShaderObject.fragment("MultiColorVertexColorF")
      ..addVaryingVars([vColor])
      ..setBodyWithMain(["$oFragColor = vec4( $vColor, 1.0 );"]);
