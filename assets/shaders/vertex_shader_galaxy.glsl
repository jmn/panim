#version 330 core
layout(location = 0) in vec3 aPos; // Vertex position

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec2 uv;

void main() {
    uv = aPos.xy; // Pass the XY coordinates to the fragment shader
    gl_Position = projection * view * model * vec4(aPos, 1.0);
}

