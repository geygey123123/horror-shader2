#version 120

// Analog Horror Shader - Vertex Shader (final.vsh)
// Passes texture coordinates and handles basic vertex transformation

varying vec2 texcoord;
varying vec4 position;

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform vec2 aspectRatio;

void main() {
    // Standard vertex transformation
    gl_Position = ftransform();
    
    // Calculate texture coordinates for post-processing
    // Map from [-1, 1] to [0, 1]
    texcoord = gl_MultiTexCoord0.st;
    
    // Pass position for potential use in fragment shader
    position = gl_Vertex;
}
