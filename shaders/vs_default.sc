// Here are the io of the shader
// which they were defined from the varying.def.sc
$input a_position, a_normal
$output v_position, v_normal

// just like OpenGL, we need to state what shader to be used,
// except that bgfx_shader is our only option.
#include <bgfx_shader.sh>

// also work hugely similar to OpenGL that we need a main
// function to render the vertex information

void main(){
    // multiply a uniform projection matrix with our incoming 3D coordination.
    // Seems like shaderc doesn't have operator overloading, so it use the mul() function instead.
    // Otherwise, they works similar to OpenGL once again

    gl_position = mul(u_modelViewProj, vec4(a_position, 1.0));
    v_position = gl_position.xyz // discard the fourth dimension

    // They are normal mapping from a texture, giving some depth to a texture that contains marks,
    // by defusing the light
    // Source: https://learnopengl.com/Advanced-Lighting/Normal-Mapping
    v_normal = mul(u_modelViewProj, vec4(a_normal, 0.0)).xyz;
}