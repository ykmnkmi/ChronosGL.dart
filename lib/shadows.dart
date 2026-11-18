/// Shadow map generation without diagnostic rendering.
///
/// Shadow maps own their compute assets and borrow caster resources. Import
/// `debug.dart` separately when shadow visualization is needed.
library;

export 'src/shadows/shadow_map.dart'
    show
        shadowMapShaderLib,
        shadowVertexShaderDepth,
        shadowFragmentShaderDepth,
        ShadowMap;
