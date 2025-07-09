// What is the input of the fragment shader?
$input v_normal, v_position

// How to make bgfx shader effective?
#include <bgfx_shader.sh>

// Seems like uniform in the vertex shader is not defined in the shader level,
// but u_color is. Looks like they can be defined at the zig level.
uniform vec4 u_color;

// How to define the behavior of the shader?
void main(){
    gl_FragColor = u_color; // instead of "color" in OpenGL
}