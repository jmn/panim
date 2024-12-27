#version 330 core
out vec4 fragColor;

in vec2 uv;

uniform float iTime;       // Time since the start
uniform vec2 iResolution;  // Screen resolution

void main() {
    vec2 fragCoord = uv * iResolution; // Convert UV to pixel coordinates
    vec2 normalizedUV = fragCoord / iResolution.xy;
    normalizedUV = normalizedUV * 2.0 - 1.0; // Normalize to [-1, 1]
    normalizedUV.x *= iResolution.x / iResolution.y;

    // Time-driven variables
    float time = iTime * 0.42;

    // Parameters for the galaxy
    float galaxyRadius = 1.5; // Size of the galaxy
    float spinFactor = 2.5;   // How tightly the stars swirl
    float dustIntensity = 0.002; // Intensity of the dust

    // Convert UV coordinates to polar
    float r = length(normalizedUV);
    float theta = atan(normalizedUV.y, normalizedUV.x);

    // Add swirling motion
    theta += spinFactor * r - time;

    // Convert back to Cartesian
    vec2 rotatedUV = vec2(cos(theta), sin(theta)) * r;

    // Generate star density
    float starField = smoothstep(0.0, galaxyRadius, r) * smoothstep(0.98, 1.0, fract(100.0 * rotatedUV.x * rotatedUV.y));

    // Dust clouds using noise
    float dust = fract(sin(dot(rotatedUV * 10.0, vec2(12.9898, 78.233))) * 43758.5453) * dustIntensity;

    // Combine stars and dust
    vec3 color = mix(vec3(0.0, 0.0, 0.1), vec3(0.5, 0.7, 1.0), starField);
    color += vec3(1.0, 0.5, 0.3) * dust;

    // Add a glow effect around the galaxy core
    float glow = exp(-pow(r * 3.0, 2.0));
    color += vec3(1.0, 0.8, 0.6) * glow;

    // Add subtle pulsating effect
    color *= 1.0 + 0.1 * sin(iTime * 3.0);

    // Final color output
    fragColor = vec4(color, 1.0);
}

