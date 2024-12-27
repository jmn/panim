#version 330 core
in vec3 fragColor;
out vec4 color;

uniform float time;
uniform float testValue;  // New test uniform

void main() {
    float r = sin(time) * 0.5 + 0.5;
    float green = 0.5 + 0.5 * cos(testValue);
    color = vec4(r, g, 0.0, 1.0); // Animating color based on time
}

