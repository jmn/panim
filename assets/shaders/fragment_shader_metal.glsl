#version 330

in vec4 fragPosition;
in vec3 fragNormal;

uniform float time;
uniform vec3 lightPos;

out vec4 fragColor;

void main() {
    // Calculate a "bubbling" effect using sine waves
    float wave = sin(fragPosition.x * 10.0 + time) * cos(fragPosition.z * 10.0 - time) * sin(fragPosition.y * 10.0 + time) * 0.5;

    // Calculate normal perturbation for metallic reflection
    vec3 perturbedNormal = normalize(fragNormal + wave);

    // Simulate diffuse lighting
    vec3 lightDir = normalize(lightPos - fragPosition.xyz);
    float diff = max(dot(perturbedNormal, lightDir), 0.0);

    // Simulate specular highlights (Phong model)
    vec3 viewDir = normalize(-fragPosition.xyz);  // Simple view direction assuming camera at origin
    vec3 reflectDir = reflect(-lightDir, perturbedNormal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0); // Specular reflection

    // Base color for metal (bubbling effect through color oscillation)
    vec3 baseColor = vec3(0.8, 0.8, 0.8) + 0.2 * sin(time);

    // Combine diffuse and specular components
    fragColor = vec4(baseColor * diff + spec, 1.0);
}

