$input v_position, v_normal

#include <bgfx_shader.sh>

uniform vec4 u_color;

void main(){
    // After studying the lighting chapter in learn OpenGL, its seems that lighting doesn't exist
    // in shader which it doesn't have a function named createLightSource, but a series of matrix
    // multiplication over a texture, manipulating the brightness.
    // Source: https://learnopengl.com/Lighting/Basic-Lighting

    // I will copy the lighting shader from zig-bgfx and to learn how lighting really works
    // on the shader level.

    // Because if we have applied non-uniform scaling, It seems that it will distort the 
    // normal vector of the incoming fragment, result in a wrong reflection calculation 
    // Source: https://learnopengl.com/Lighting/Basic-Lighting
    vec3 normal = normalize(v_normal);

    // The following is the simple and classic case of Diffuse and ambient lighting.
    // Ambient lighting is simple because it just globally applied a constant light
    // strength over the model, while diffuse lighting uses the concept of finding 
    // the vector distance between the light source and the view (which can be a camera
    // or a default view point), and find the magnitude of the strength of light at the
    // view point by doing a dot product. With both of the lighting, we can combine 
    // both of them for the final lighting effect.

    // define the location of the light source
    vec3 light_pos = vec3(20.0, 20.0, -20.0);         

    // getting the light direction by subtracting the light source and view point location                
    vec3 light_direction = normalize(light_pos - v_position);   
    // Bright! A white light; If there'd be any glory in war 
    vec3 light_color = vec3(1.0, 1.0, 1.0);                           

    vec3 ambient = 0.2 * light_color;

    // this calculates the perception of light from view point given the light source.
    vec3 diffuse = max(dot(normal, light_direction), 0.0) * light_color; 

    // It uses a uniform instead of texture since the original example has a function to change color to the cube given a key press.
    vec3 color = u_color.xyz * 0.9;
    
    // finalize all the lighting and return all the color and lighting information to the color output
    // if we work on texture, change that with the texture() function instead of using color 
    gl_FragColor.xyz = (ambient + diffuse) * color;    

    // alpha channel         
    gl_FragColor.w = 1.0;                                       
}