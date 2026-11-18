/// Optional statistics panels and light, skeleton, and shadow visualizers.
///
/// Diagnostics must be imported explicitly; the aggregate does not export them.
/// Visualizers own created resources and borrow supplied engine objects.
library;

export 'src/diagnostics/bone_visualizer.dart'
    show bonePosFromSkeleton, bonePosFromAnimatedSkeleton, BoneVisualizer;
export 'src/diagnostics/fps_meter.dart'
    show StatsPanel, FpsPanel, Stats, StatsFps;
export 'src/diagnostics/light_visualizer.dart'
    show
        emptyLightVisualizer,
        updateDirectionalLightVisualizer,
        updateSpotLightVisualizer,
        updatePointLightVisualizer2,
        updatePointLightVisualizer,
        updateLightVisualizer,
        lightVisualizer,
        LightVisualizer;
export 'src/diagnostics/shadow_map_visualizer.dart'
    show
        visualizeShadowmapVertexShaderLinearDepth16,
        visualizeShadowmapFragmentShaderLinearDepth16,
        ShadowMapVisualizer;
