#version 330 core
layout(location = 0) in vec3 aPos; // Vertex position

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform vec3 cameraPos;

out vec3 fragPos;

void main() {
    fragPos = aPos; // Pass the position to the fragment shader
    gl_Position = projection * view * model * vec4(aPos, 1.0); // Apply the transformation
}

