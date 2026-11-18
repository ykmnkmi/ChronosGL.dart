/// Browser input, camera controls, viewport integration, and asset loading.
///
/// Prefer typed package:web constructors (`forTarget`, `forCamera`, `forCanvas`).
/// Deprecated Object-based constructors retain JavaScript legacy DOM support only.
library;

export 'src/webhelper/lib.dart'
    show
        CanvasViewport,
        loadRaw,
        loadJson,
        loadImage,
        loadVideo,
        loadCubeImages,
        Keyboard,
        Mouse,
        OrbitCamera,
        OrbitControls,
        RenderPhaseResizeAware,
        PerspectiveResizeAware,
        makeVideoElementFromCamera,
        makeSolidColorCanvas,
        makeSolidColorTexture,
        makeSolidColorTextureRGB,
        makeSolidColorTextureRGBA;
