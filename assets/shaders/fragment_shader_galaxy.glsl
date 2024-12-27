#version 330 core
out vec4 FragColor;

in vec3 fragPos;

uniform float time;
uniform vec3 cameraPos;

void main() {
    // Simple effect based on the camera position and time
    float distance = length(fragPos - cameraPos); // Distance from the camera
    float intensity = sin(distance * 0.1 + time) * 0.5 + 0.5; // Time-based animation for the galaxy effect
    
    // Color based on the intensity
    vec3 color = vec3(0.1, 0.1, 1.0) * intensity; // Deep blue for the galaxy
    FragColor = vec4(color, 1.0); // Final color output
}

