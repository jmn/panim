#version 330 core

in vec3 fragNormal;  // Normal vector
in vec4 fragPosition; // Fragment position in world space

uniform float time; // Time variable passed from the main program
out vec4 FragColor; // Final color output

void main() {
    // Generate a color based on the time and position
    float red = 0.5 + 0.5 * sin(time + fragPosition.x);  // Create a dynamic red channel
    float green = 0.5 + 0.5 * sin(time + fragPosition.y);  // Create a dynamic green channel
    float blue = 0.5 + 0.5 * sin(time + fragPosition.z);  // Create a dynamic blue channel

    // Combine the channels to form the final color
    FragColor = vec4(red, green, blue, 1.0);  // Full opacity
}

