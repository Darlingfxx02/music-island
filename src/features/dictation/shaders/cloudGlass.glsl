#version 300 es
// Adapted from Darlingfxx02/no-tipe, Prototypes/no-tipe-island-variants.html.
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uSceneTexture;
uniform sampler2D uBackground;
uniform vec2 uTextureSize;
uniform vec2 uPanelSize;
uniform vec2 uCanvasSize;
uniform vec2 uMaterialOrigin;
uniform vec2 uMaterialSize;
uniform vec2 uFaceOrigin;
uniform vec2 uFaceSize;
uniform float uFaceShade;
uniform vec2 uPanelOrigin;
uniform float uMarginPx;
uniform float uCornerRadius;
uniform float uHeight;
uniform float uCurvature;
uniform float uRefractAmount;
uniform float uAngle;
uniform float uGradRadialMix;
uniform float uKeyAngle;
uniform float uFillAngle;
uniform float uHlHeight;
uniform float uHlCut;
uniform float uHlNorm;
uniform float uHlAmount;
uniform float uHlCurv;
uniform float uBackgroundReady;
uniform float uTransparentOutside;
// Canvas-space centers and half-sizes; all lobes join the same distance field.
uniform vec4 uLobe0;
uniform vec4 uLobe1;
uniform vec4 uLobe2;
uniform vec3 uLobeProgress;
uniform vec4 uControl0;
uniform vec4 uControl1;
uniform float uControlProgress;
uniform float uMergeRadius;
uniform float uPixelScale;
uniform float uRimStrength;
uniform float uRimWidth;
uniform float uRimTime;
uniform float uVoiceImpact;
uniform float uVoicePhase;
uniform float uNeutralBackground;
uniform vec3 uThemeTint;
uniform float uLightIntensity;
uniform float uWaveVisibility;
uniform float uCompletionTint;
uniform float uError;
uniform float uTranslationActive;
out vec4 outColor;

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec2 rotate2d(vec2 v, float a) {
  float c = cos(a);
  float s = sin(a);
  return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}
vec2 coverUv(vec2 canvasUv) {
  vec2 pixel = canvasUv * uCanvasSize;
  float cover = max(uCanvasSize.x / uTextureSize.x, uCanvasSize.y / uTextureSize.y);
  vec2 fitted = uTextureSize * cover;
  vec2 offset = (fitted - uCanvasSize) * 0.5;
  return clamp((pixel + offset) / fitted, vec2(0.0), vec2(1.0));
}
vec3 successHue(vec3 color) {
  const vec3 luminance = vec3(0.2126, 0.7152, 0.0722);
  vec3 green = vec3(0.36, 0.58, 0.43);
  return green * (dot(color, luminance) / dot(green, luminance));
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
  vec3 red = vec3(0.66, 0.30, 0.32);
  red *= dot(color, vec3(0.2126, 0.7152, 0.0722)) / dot(red, vec3(0.2126, 0.7152, 0.0722));
  return mix(color, mix(successHue(color), red, uError), uCompletionTint);
}
// Recreate the actual compact Ready scene, including its black container pass.
// p uses local surface coordinates, so the 90x63 reference scales to a 36px orb.
vec3 materialTheme(vec3 color);
vec3 compactOrbMaterial(vec2 p, float green) {
  vec2 uv = p * vec2(90.0 / 130.0, 63.0 / 103.0) + 0.5;
  float vignette = 1.0 - smoothstep(0.12, 0.95, distance(uv, vec2(0.5)));
  vec3 top = materialTheme(vec3(0.015, 0.018, 0.022));
  vec3 tint = materialTheme(vec3(0.02, 0.035, 0.055));
  vec3 face = mix(top, successHue(top), green) * (1.0 - uv.y);
  face += mix(tint, successHue(tint), green) * vignette;
  vec2 effectUv = p / 1.18 + 0.5;
  float gy = clamp(effectUv.y, 0.0, 1.0);
  float t = clamp(gy - 0.25, 0.0, 1.0);
  float vfade = gy <= 0.25 ? 1.0 : exp(-8.0 * t * t);
  float edgeLR = smoothstep(0.0, 0.14, min(effectUv.x, 1.0 - effectUv.x));
  vec2 irradiance = materialLightField(p + 0.5);
  vec3 diffuseTint = materialTheme(vec3(0.016, 0.023, 0.030));
  face += 0.65 * (mix(tint, successHue(tint), green) * irradiance.x
    + mix(diffuseTint, successHue(diffuseTint), green) * irradiance.y);
  return face * (1.0 - 0.9 * vfade * edgeLR);
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
  vec2 irradiance = materialLightField(materialCoordinates(uv * uMaterialSize + uMaterialOrigin));
  return (mix(bottom, top, 1.0 - uv.y) + completionHue(vec3(0.02, 0.035, 0.055)) * vignette + materialEmission(irradiance)) * attenuation;
}
vec3 sampleBackground(vec2 canvasUv) {
  vec3 image = texture(uBackground, coverUv(canvasUv)).rgb;
  return mix(fallbackBackground(canvasUv), image, clamp(uBackgroundReady, 0.0, 1.0));
}
vec3 sampleScene(vec2 canvasUv) {
  return texture(uSceneTexture, vec2(canvasUv.x, 1.0 - canvasUv.y)).rgb;
}
float supercircleDistance(vec2 p, vec2 b, float n, vec2 param) {
  const float c = 1.528665;
  float an = abs(n);
  float ac = an * c;
  float m10 = mix(ac, an, max(param.x, param.y));
  vec2 v14 = (p - b) + vec2(m10);
  vec2 q = abs(max(vec2(0.0), (p - b) / max(ac, 0.0001) + vec2(1.0)));
  float l = length(q);
  float qmax = max(q.x, q.y);
  float qmin = min(q.x, q.y);
  float ratio = (qmax == 0.0) ? 0.0 : saturate(qmin / qmax);
  float poly = ((((-0.926054 * ratio + 3.15601) * ratio - 3.64122) * ratio + 1.26803) * ratio + 0.268531);
  float dCorner = (l + 1.0) - 1.0 / (1.0 - ratio * ratio * saturate(l) * poly);
  float dFar = length(max(vec2(0.0), q * c - vec2(0.528665))) * 0.654166 + 0.345834;
  float d57 = mix(dCorner, dFar, param.x);
  float d58 = mix(dCorner, dFar, param.y);
  float s = (q.y > q.x) ? 1.0 : -1.0;
  float t65 = saturate((0.5 - s) + s * ratio);
  float dist = mix(d57, d58, t65) - 1.0;
  float emin = min(max(v14.x, v14.y), 0.0);
  return emin + ac * dist;
}
vec2 cornerParam(vec2 halfSize, float r) {
  if (r < 0.0001) return vec2(0.0);
  return clamp((vec2(1.528665) - halfSize / r) / 0.528665, vec2(0.0), vec2(1.0));
}
float shapeDistance(vec2 p, vec2 halfSize, float cornerRadius) {
  float r = min(cornerRadius, min(halfSize.x, halfSize.y));
  if (r < 0.5) {
    vec2 dd = abs(p) - halfSize;
    return length(max(dd, vec2(0.0))) + min(max(dd.x, dd.y), 0.0);
  }
  return supercircleDistance(abs(p), halfSize, r, cornerParam(halfSize, r));
}
vec2 shapeGradient(vec2 p, vec2 halfSize, float cornerRadius, float radialMix) {
  float r = min(cornerRadius, min(halfSize.x, halfSize.y));
  vec2 param = cornerParam(halfSize, r);
  float ac = mix(r * 1.528665, r, max(param.x, param.y));
  vec2 pf = abs(p);
  vec2 v = max(vec2(0.0), (pf - halfSize) + vec2(ac));
  vec2 g = (v.x + v.y > 0.00001)
    ? normalize(v)
    : ((pf.x - halfSize.x > pf.y - halfSize.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
  vec2 cornerGrad = g * sign(p);
  vec2 centerRadial = normalize(vec2(p.x, halfSize.x * p.y / max(halfSize.y, 0.001)) + vec2(0.00001));
  return normalize(mix(cornerGrad, centerRadial, radialMix));
}
float refractionProfile(float t, float curvature) {
  float flatProfile = 1.0 - 0.2929 * (t < 1.0 ? 1.0 : 0.0);
  float circular = sqrt(max(1.0 - (1.0 - t) * (1.0 - t), 0.0));
  return mix(flatProfile, circular, curvature);
}
vec2 refractedUv(vec2 baseUv, float d, vec2 grad, float opticalScale) {
  float t = clamp(-d / max(uHeight * opticalScale, 0.001), 0.0, 1.0);
  float mag = 1.0 - refractionProfile(t, uCurvature);
  vec2 dir = rotate2d(grad, uAngle);
  return baseUv + (uRefractAmount * opticalScale * mag * dir) / uCanvasSize;
}
float highlightLobe(float dist, float aa, vec2 n, float h, vec2 dir, float cut, float curv) {
  if (dist < -5.0) return 0.0;
  float t = saturate(dist / max(h, 0.001));
  float profile = mix(t < 1.0 ? 1.0 : 0.0, 1.0 - t, curv);
  float band = saturate(dist / aa + 0.5) * saturate((h - dist) / aa + 0.5) * profile;
  float angular = saturate((dot(dir, n) - cut) / max(1.0 - cut, 0.001));
  return band * angular;
}
float highlightBand(float d, vec2 grad, float aa, float opticalScale) {
  float glen = max(length(grad), 0.0001);
  float dist = -d / glen;
  vec2 n = grad / glen;
  aa = max(aa, 0.0001);
  vec2 kdir = vec2(cos(uKeyAngle), sin(uKeyAngle));
  vec2 fdir = vec2(cos(uFillAngle), sin(uFillAngle));
  float key = highlightLobe(dist, aa, n, uHlHeight * opticalScale, kdir, uHlCut, uHlCurv);
  float fill = highlightLobe(dist, aa, n, uHlHeight * opticalScale, fdir, uHlCut, uHlCurv);
  float keyN = key / (1.0 + (1.0 - key) * uHlNorm);
  float fillN = fill / (1.0 + (1.0 - fill) * uHlNorm);
  return keyN + fillN;
}
// Analytic rounded-box distance + normal, in physical pixels.
vec3 lobeField(vec2 pixel, vec4 lobe, float radius) {
  float r = min(radius, min(lobe.z, lobe.w));
  vec2 p = pixel - lobe.xy;
  vec2 q = abs(p) - lobe.zw + r;
  vec2 outside = max(q, vec2(0.0));
  float len = length(outside);
  vec2 n = len > 0.0001 ? outside / len
    : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
  return vec3(len + min(max(q.x, q.y), 0.0) - r, n * sign(p));
}
// The gradient of smooth-union is the same weighted sum of both normals.
// This bends BOTH surfaces at contact and removes the internal seam entirely.
vec3 joinFields(vec3 a, vec3 b, float radius) {
  float h = clamp(0.5 + 0.5 * (b.x - a.x) / radius, 0.0, 1.0);
  vec3 field = mix(b, a, h);
  field.x -= radius * h * (1.0 - h);
  return field;
}
vec3 islandField(vec2 pixel) {
  vec2 halfSize = uPanelSize * 0.5 - vec2(uMarginPx);
  vec2 p = pixel - uPanelOrigin - uPanelSize * 0.5;
  vec3 field = vec3(shapeDistance(p, halfSize, uCornerRadius),
    shapeGradient(p, halfSize, uCornerRadius, uGradRadialMix));
  vec4 lobes[3] = vec4[3](uLobe0, uLobe1, uLobe2);
  vec3 satellites = vec3(100000.0, 0.0, 1.0);
  for (int i = 0; i < 3; i++) {
    if (uLobeProgress[i] > 0.001) {
      float radius = i == 0 ? min(lobes[i].z, lobes[i].w) : 16.0 * uPixelScale;
      satellites = joinFields(satellites, lobeField(pixel, lobes[i], radius), 8.0 * uPixelScale);
    }
  }
  field = joinFields(field, satellites, max(uMergeRadius, 0.01));
  if (uControlProgress > 0.001) {
    field = joinFields(field, lobeField(pixel, uControl0, uControl0.z), 10.0 * uPixelScale);
    field = joinFields(field, lobeField(pixel, uControl1, uControl1.z), 10.0 * uPixelScale);
  }
  return field;
}
// Speech light belongs only to the detached side controls beside the wave.
// Translation lobes retain their own quiet material, even near the shell.
float reflectedVoice(vec2 pixel, vec2 surfaceNormal) {
  if (uControlProgress <= 0.001) return 0.0;
  float controlDistance = min(lobeField(pixel, uControl0, uControl0.z).x,
                              lobeField(pixel, uControl1, uControl1.z).x);
  float controlMask = (1.0 - smoothstep(0.0, 3.0 * uPixelScale, controlDistance))
    * smoothstep(0.15, 0.75, uControlProgress);
  vec2 center = uPanelOrigin + uPanelSize * 0.5;
  vec2 halfSize = uPanelSize * 0.5 - vec2(uMarginPx);
  vec2 local = pixel - center;
  float distanceToBody = shapeDistance(local, halfSize, uCornerRadius);
  vec2 bodyNormal = normalize(shapeGradient(local, halfSize, uCornerRadius, uGradRadialMix) + vec2(0.00001));
  float facing = pow(max(dot(surfaceNormal, -bodyNormal), 0.0), 1.6);
  float gap = max(distanceToBody, 0.0) / max(uPixelScale, 0.001);
  vec2 contact = pixel - bodyNormal * max(distanceToBody, 0.0);
  vec2 waveCenter = center + vec2(0.0, halfSize.y - 31.5 * uPixelScale);
  float travel = length(contact - waveCenter) / max(uPixelScale, 0.001);
  float carrier = 0.82 + 0.18 * cos(uVoicePhase * 0.5 - travel * 0.035);
  return uVoiceImpact * controlMask * facing * exp(-gap / 48.0) * carrier;
}
vec4 glassFragment(vec2 pixel) {
  vec3 field = islandField(pixel);
  float d = field.x;
  vec2 grad = field.yz;
  float panelHighlightDist = -d / max(length(grad), 0.0001);
  float panelHighlightAa = max(fwidth(panelHighlightDist), 0.0001);
  float edgeAa = max(fwidth(d), 1.0);
  // Derivatives precede all varying exits. No rectangular clip: upper lobes
  // and their necks belong to the panel, including outside its original bounds.
  float alpha = 1.0 - smoothstep(-edgeAa, edgeAa, d);
  if (alpha <= 0.001) return vec4(0.0);
  float orbDistance = lobeField(pixel, uLobe0, min(uLobe0.z, uLobe0.w)).x;
  float orbSurface = (1.0 - smoothstep(0.0, 3.0 * uPixelScale, orbDistance))
    * smoothstep(0.6, 0.95, uLobeProgress.x);
  float orbMask = orbSurface * uTranslationActive;
  // Bevel depth, refraction and highlight width scale from Ready's 63px height.
  float orbScale = clamp(min(uLobe0.z, uLobe0.w) * 2.0 / (63.0 * uPixelScale), 0.3, 1.0);
  float opticalScale = mix(1.0, orbScale, orbSurface);
  vec2 baseUv = pixel / uCanvasSize;
  vec2 rUv = clamp(refractedUv(baseUv, d, grad, opticalScale), vec2(0.0), vec2(1.0));
  vec3 col = sampleScene(rUv);
  vec2 orbPoint = (rUv * uCanvasSize - uLobe0.xy) / max(uLobe0.zw * 2.0, vec2(1.0));
  col = mix(col, compactOrbMaterial(orbPoint, 1.0), orbMask);
  vec4 controls[2] = vec4[2](uControl0, uControl1);
  for (int i = 0; i < 2; i++) {
    float distanceToControl = lobeField(pixel, controls[i], controls[i].z).x;
    float mask = (1.0 - smoothstep(-2.0 * uPixelScale, 6.0 * uPixelScale, distanceToControl))
      * smoothstep(0.15, 0.75, uControlProgress);
    vec2 controlPoint = (rUv * uCanvasSize - controls[i].xy) / max(controls[i].zw * 2.0, vec2(1.0));
    col = mix(col, compactOrbMaterial(controlPoint, 0.0), mask);
  }
  float light = materialLight(pixel);
  col += completionHue(vec3(highlightBand(d, grad, panelHighlightAa, opticalScale) * uHlAmount)) * materialGlossGain(light);
  // A constant-pixel bevel follows the signed-distance contour at every size.
  // It lights the entire perimeter independently of the wave at the bottom.
  float rimDepth = max(-d, 0.0);
  float rimWidth = max(uRimWidth * opticalScale, 0.1);
  vec2 rimNormal = normalize(grad + vec2(0.00001));
  float rimAngle = atan(rimNormal.y, rimNormal.x);
  float rimTravel = pow(0.5 + 0.5 * cos(rimAngle - uRimTime * 0.38), 5.0);
  float rimKey = pow(abs(dot(rimNormal, normalize(vec2(-0.6, -0.8)))), 2.0);
  float rimCore = exp(-rimDepth / (rimWidth * 0.16));
  float rimBevel = exp(-pow((rimDepth - rimWidth * 0.42) / (rimWidth * 0.28), 2.0));
  float rimBloom = exp(-rimDepth / rimWidth);
  vec3 rimTint = mix(vec3(0.64, 0.70, 0.86), vec3(0.82, 0.84, 1.0), rimKey * 0.65 + rimTravel * 0.25);
  rimTint = completionHue(rimTint);
  rimTint = mix(rimTint, successHue(rimTint), orbMask);
  col += rimTint * uRimStrength * materialGlossGain(light) *
    (rimCore * (0.14 + 0.25 * rimKey + 0.14 * rimTravel) + rimBevel * 0.085 + rimBloom * 0.045);
  float voiceLight = reflectedVoice(pixel, rimNormal);
  float voiceBevel = exp(-rimDepth / (rimWidth * 0.75));
  float voiceBloom = exp(-rimDepth / (rimWidth * 2.4));
  col += rimTint * voiceLight * (0.26 * rimCore + 0.16 * voiceBevel + 0.08 * voiceBloom) * uWaveVisibility;
  return vec4(col, alpha);
}
void main() {
  vec2 pixel = vec2(gl_FragCoord.x, uResolution.y - gl_FragCoord.y);
  vec2 canvasUv = pixel / uCanvasSize;
  vec3 background = sampleBackground(canvasUv);
  vec4 glass = glassFragment(pixel);
  float a = saturate(glass.a);
  vec3 glassRgb = clamp(glass.rgb, 0.0, 1.25);
  vec4 framed = vec4(mix(background, glassRgb, a), 1.0);
  vec4 floating = vec4(glassRgb * a, a);
  outColor = mix(framed, floating, clamp(uTransparentOutside, 0.0, 1.0));
}

