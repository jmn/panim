#version 330

in vec3 fragPosition;
in vec3 fragNormal;

uniform float time;

out vec4 fragColor;

void main() {
    // Calculate a "bubbling" effect using sine waves
    float wave = sin(fragPosition.x * 10.0 + time) * cos(fragPosition.z * 10.0 - time) * 0.5;

    // Calculate normal perturbation for metallic reflection
    vec3 perturbedNormal = normalize(fragNormal + wave);

    // Simulate metallic shading
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.5)); // Direction of light
    float diff = max(dot(perturbedNormal, lightDir), 0.0);

    // Base color for metal (bubbling effect through color oscillation)
    vec3 baseColor = vec3(0.8, 0.8, 0.8) + 0.2 * sin(time);

    // Final color output
    fragColor = vec4(baseColor * diff, 1.0);
}

