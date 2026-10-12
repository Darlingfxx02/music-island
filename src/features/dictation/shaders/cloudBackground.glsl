#version 300 es
// Adapted from Darlingfxx02/no-tipe, Prototypes/no-tipe-island-variants.html.
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uBackground;
uniform vec2 uTextureSize;
uniform vec2 uCanvasSize;
uniform vec2 uMaterialOrigin;
uniform vec2 uMaterialSize;
uniform vec2 uFaceOrigin;
uniform vec2 uFaceSize;
uniform float uFaceShade;
uniform float uBackgroundReady;
uniform float uNeutralBackground;
uniform vec3 uThemeTint;
uniform float uLightIntensity;
uniform float uWaveVisibility;
uniform float uCompletionTint;
uniform float uError;
out vec4 outColor;
vec2 coverUv(vec2 canvasUv) {
  vec2 pixel = canvasUv * uCanvasSize;
  float cover = max(uCanvasSize.x / uTextureSize.x, uCanvasSize.y / uTextureSize.y);
  vec2 fitted = uTextureSize * cover;
  vec2 offset = (fitted - uCanvasSize) * 0.5;
  return clamp((pixel + offset) / fitted, vec2(0.0), vec2(1.0));
}
vec3 materialTheme(vec3 color) {
  const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
  float brightness = dot(color, luma);
  vec3 themed = uThemeTint * brightness / max(dot(uThemeTint, luma), 0.01);
  // Preserve Type's original energy and color profile; themes add a small tint.
  return mix(mix(color, themed, 0.16), vec3(brightness), uNeutralBackground);
}
// Fixed curved sources: the slider changes radiance, never source position,
// gradient width or a moving cutoff. Both energy curves are smooth at 100%.
vec2 materialLightField(vec2 uv) {
  float intensity = clamp(uLightIntensity, 0.0, 2.0);
  float directEnergy = intensity * (0.60 + intensity * (0.30 + 0.10 * intensity));
  float diffuseEnergy = 1.25 * intensity * intensity / (1.0 + 0.25 * intensity);
  float x = (uv.x - 0.5) * 2.0;
  // The lower source bends up at the shoulders; its broad Gaussian tails
  // merge with side reflections instead of making a horizontal band.
  float arc = 0.94 - 0.22 * x * x;
  vec2 lowerDelta = vec2(x * 0.82, (uv.y - arc) * 2.15);
  float lowerPool = exp(-2.0 * dot(lowerDelta, lowerDelta));
  vec2 sideDelta = vec2((abs(x) - 0.92) * 3.2, (uv.y - 0.62) * 1.65);
  float sideBounce = exp(-2.0 * dot(sideDelta, sideDelta));
  vec2 fillDelta = (uv - vec2(0.5, 0.62)) * vec2(1.45, 1.35);
  float diffusePool = exp(-2.0 * dot(fillDelta, fillDelta));
  vec2 returnDelta = vec2(x * 1.15, (uv.y - 0.22) * 2.0);
  float upperReturn = exp(-2.0 * dot(returnDelta, returnDelta));
  return vec2(directEnergy * (0.78 * lowerPool + 0.22 * sideBounce),
    diffuseEnergy * (0.16 * diffusePool + 0.06 * upperReturn));
}
float materialLightEnergy(vec2 irradiance) { return irradiance.x + irradiance.y; }
float materialGlossGain(float irradiance) {
  // Soft compression keeps the grazing highlight smooth at high exposure.
  return 1.0 + 0.45 * irradiance / (1.0 + 0.35 * irradiance);
}
vec2 materialCoordinates(vec2 pixel) {
  vec2 origin = uFaceSize.y > 0.0 ? uFaceOrigin : uMaterialOrigin;
  vec2 size = uFaceSize.y > 0.0 ? uFaceSize : uMaterialSize;
  return (pixel - origin) / max(size, vec2(1.0));
}
float materialLight(vec2 pixel) {
  return materialLightEnergy(materialLightField(materialCoordinates(pixel)));
}
vec3 completionHue(vec3 color) {
  color = materialTheme(color);
  if (uNeutralBackground > 0.5) return color;
  const vec3 luminance = vec3(0.2126, 0.7152, 0.0722);
  vec3 green = mix(vec3(0.36, 0.58, 0.43), vec3(0.66, 0.30, 0.32), uError);
  green *= dot(color, luminance) / dot(green, luminance);
  return mix(color, green, uCompletionTint);
}
vec3 materialEmission(vec2 irradiance) {
  return 0.65 * (completionHue(vec3(0.02, 0.035, 0.055)) * irradiance.x
    + completionHue(vec3(0.016, 0.023, 0.030)) * irradiance.y);
}
float faceAttenuation(vec2 pixel) {
  if (uFaceSize.x <= 0.0) return 1.0;
  vec2 uv = (pixel - uFaceOrigin - uFaceSize * 0.5) / (uFaceSize * 1.18) + 0.5;
  float t = max(uv.y - 0.25, 0.0);
  float vertical = exp(-8.0 * t * t);
  float sides = smoothstep(0.0, 0.14, min(uv.x, 1.0 - uv.x));
  return 1.0 - uFaceShade * vertical * sides;
}
vec3 fallbackBackground(vec2 uv) {
  float attenuation = faceAttenuation(uv * uCanvasSize);
  if (uMaterialSize.x > 0.0) uv = (uv * uCanvasSize - uMaterialOrigin) / uMaterialSize;
  float vignette = 1.0 - smoothstep(0.12, 0.95, distance(uv, vec2(0.5)));
  vec3 top = completionHue(vec3(0.015, 0.018, 0.022));
  vec3 bottom = vec3(0.0, 0.0, 0.0);
  vec3 tint = mix(bottom, top, 1.0 - uv.y);
  vec2 irradiance = materialLightField(materialCoordinates(uv * uMaterialSize + uMaterialOrigin));
  return (tint + completionHue(vec3(0.02, 0.035, 0.055)) * vignette + materialEmission(irradiance)) * attenuation;
}
void main() {
  vec2 pixel = vec2(gl_FragCoord.x, uResolution.y - gl_FragCoord.y);
  vec2 uv = pixel / uCanvasSize;
  vec3 image = texture(uBackground, coverUv(uv)).rgb;
  vec3 background = mix(fallbackBackground(uv), image, clamp(uBackgroundReady, 0.0, 1.0));
  outColor = vec4(background, 1.0);
}

