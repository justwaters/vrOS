// AR camera-passthrough shaders (vertexShaderPassthroughFOV,
// fragmentShaderPassthrough) live in Shaders.metal, paired in the same file
// as every other vertex/fragment pair in this project -- both need the
// Uniforms/VertexOut structs declared there, and Metal doesn't share struct
// definitions across .metal files without a common header, so keeping the
// pair in one file avoids a duplicate-type risk. This file is kept as an
// empty placeholder rather than removed from the Xcode project (see
// CLAUDE.md: new/removed source files need careful direct .pbxproj edits).
