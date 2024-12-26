#version 330 core

layout(location = 0) in vec3 position;  // Position of the vertex
layout(location = 1) in vec3 normal;    // Normal for lighting calculations

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 fragNormal;  // Pass the normal to the fragment shader
out vec4 fragPosition; // Pass the position to the fragment shader

void main() {
    fragNormal = normal;
    fragPosition = model * vec4(position, 1.0);  // Apply the model matrix to the position
    gl_Position = projection * view * fragPosition;  // Apply view and projection matrices
}


