/// Browser-facing GPU rendering, materials, textures, framebuffers, and lights.
///
/// Mathematical cameras stay in `camera.dart`; adapt them with `CameraUniforms`.
/// Resources passed to render objects are borrowed unless ownership is explicit.
library;

export 'mesh.dart';
export 'src/core/lib.dart'
    show
        NamedEntity,
        UniformGroup,
        CameraUniforms,
        TheStencilFunction,
        stencilFunctionNone,
        stencilFunctionAlways,
        TheStencilOp,
        TheBlendEquation,
        blendEquationNone,
        blendEquationStandard,
        blendEquationMix,
        blendEquationAdd,
        Material,
        TextureProperties,
        texturePropertiesFramebuffer,
        texturePropertiesFramebufferWrapped,
        texturePropertiesVideo,
        texturePropertiesShadowMap,
        texturePropertiesMipmap,
        Texture,
        TypedTexture,
        TypedTextureMutable,
        ImageTexture,
        CubeTexture,
        FramebufferFormat,
        Framebuffer,
        Light,
        PointLight,
        DirectionalLight,
        SpotLight,
        Illumination,
        Orthographic,
        Perspective,
        DrawStats,
        RenderProgram,
        UniformKeys,
        Spatial,
        gLogLevel,
        logInfo,
        logDebug,
        logError,
        logWarn,
        flattenVector3List,
        flattenVector2List,
        flattenVector4List,
        flattenUvec4List,
        flattenMatrix4List;
export 'src/scene/lib.dart' show FullscreenPass, unitNode;
