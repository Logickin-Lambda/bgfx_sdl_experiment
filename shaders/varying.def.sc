// These are where all the input and output variables are declared

// TEXTCOORDn is a built-in interface between vertex and fragment shader,
// which can be used for passing data in a per vertex manner.
// Seems like bgfx offers 8 of them (aligns to OpenGL), and defining these variables 
// requires declaring from the largest TEXTCOORD down to the lowest.
// Source: 
// - https://discussions.unity.com/t/what-are-the-texcoords-and-how-can-i-get-them-in-a-computeshader/719191/2
// - https://bkaradzic.github.io/bgfx/tools.html#vertex-shader-attributes
// - https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.1.40.pdf

// This bind the input channel TEXTCOORD1 with v_position 
vec3 v_position : TEXTCOORD1 = vec3(0.0, 0.0, 0.0); 

// Likewise, this pairs the NORMAL input channel with v_normal
vec3 v_normal   : NORMAL     = vec3(0.0, 0.0, 0.0);

// There are variables feed into the vertex shaders,
// a_position as gl_position for example.
vec3 a_position : POSITION;
vec3 a_normal   : NORMAL;


