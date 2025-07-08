$input v_position, v_normal

#include <bgfx_shader>

uniform vec4 u_color;

void main(){
    // After studying the lighting chapter in learn OpenGL, its seems that lighting doesn't exist
    // in shader which it doesn't have a function named createLightSource, but a series of matrix
    // multiplication over a texture, manipulating the brightness.
    // Source: https://learnopengl.com/Lighting/Basic-Lighting

    // I will copy the lighting shader from zig-bgfx and to learn how lighting really works
    // on the shader level.
}