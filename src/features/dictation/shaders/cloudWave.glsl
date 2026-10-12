#version 300 es
// Adapted from Darlingfxx02/no-tipe, Prototypes/no-tipe-island-variants.html.
precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform vec4 uMouse;
uniform float uResolved;
uniform float uLayerOpacity;
uniform float uUnresolvedScale;
uniform float uEffectScale;
uniform vec2 uAnchor;
uniform float uAmplitude;
uniform float uFreq;
uniform float uAberrationFreq;
uniform float uWavePhase;
uniform float uWaveSpeed;
uniform float uWaveScale;
uniform float uAberration;
uniform float uThickness;
uniform float uIntensity;
uniform float uFalloff;
uniform float uEdgeMask;
uniform float uEdgeMaskInset;
uniform float uBandFill;
uniform float uBandFillThickness;
uniform float uSoftness;
uniform float uLow;
uniform float uMid;
uniform float uHigh;
uniform float uLowAmplitude;
uniform float uLowIntensity;
uniform float uBrightnessLow;
uniform float uAudioBrightnessResponse;
uniform float uMidAberration;
uniform float uMidAberrationAmplitude;
uniform float uMidBandFill;
uniform float uMidSoftness;
uniform float uHighAberration;
uniform float uHighAberrationAmplitude;
uniform float uWhiteClip;
uniform vec3 uWaveColor0;
uniform vec3 uWaveColor1;
uniform vec3 uWaveColor2;
uniform vec3 uWaveHighlightColor0;
uniform vec3 uWaveHighlightColor1;
uniform vec3 uWaveHighlightColor2;
uniform float uWaveCount;
uniform float uChromatic;
uniform float uWaveBrightness;
out vec4 outColor;

float saturate(float value) { return clamp(value, 0.0, 1.0); }
vec3 wavePaletteColor(int index) {
  int paletteIndex = index % 3;
  if (paletteIndex == 0) return uWaveColor0;
  if (paletteIndex == 1) return uWaveColor1;
  return uWaveColor2;
}
vec3 waveHighlightColor(int index) {
  int paletteIndex = index % 3;
  if (paletteIndex == 0) return uWaveHighlightColor0;
  if (paletteIndex == 1) return uWaveHighlightColor1;
  return uWaveHighlightColor2;
}
float smoothUnit(float value) { return value * value * (3.0 - 2.0 * value); }

void main() {
  vec2 gid = vec2(gl_FragCoord.x, uResolution.y - gl_FragCoord.y);
  float tw = mod(uWavePhase, 62.831848) * uWaveSpeed;
  float lo = saturate(uLow);
  float md = saturate(uMid);
  float hi = saturate(uHigh);
  float res = saturate(uResolved);
  float c52 = uThickness * 0.01;
  float brightnessLow = saturate(uBrightnessLow);
  float c55 = (brightnessLow * uLowIntensity * uAudioBrightnessResponse + uIntensity) * 0.01;
  float c58 = max(0.0, md * uMidSoftness + uSoftness);
  float c61 = (md * uMidBandFill + uBandFill) * 0.0001;
  float c64 = (uLowAmplitude * 0.01) * lo + uAmplitude;
  float c68 = c64 + md * uMidAberrationAmplitude + hi * uHighAberrationAmplitude;
  float c72 = (md * uMidAberration + uAberration) + hi * uHighAberration;
  float c73 = c72 * res;
  float c76 = lo * 14.0;
  float c75 = md * 10.0 + 4.0;
  float n77 = mix(0.1, c52, res);
  float n78 = mix(0.1, c55, res);
  float n80 = (res * 0.01) * c58;
  float n81 = mix(c75, 1.0, res);
  float omr = 1.0 - res;

  vec2 uv = (gid + 0.5) * 2.0 / uResolution - 1.0;
  float aspect = uResolution.x / uResolution.y;
  uv.x *= aspect;
  vec2 q = uv - vec2(aspect, 1.0) * (uAnchor * 2.0 - 1.0);
  float ws = max(uWaveScale * uEffectScale, 0.01);
  vec2 p = q / ws;
  float base = mix(0.14, uUnresolvedScale, res);
  float r = length(p);
  float edge = max(r - base, 0.0);
  float aC = max(aspect, 1.0);
  float px = p.x / aC;
  float cw = min(abs(px * 0.9), 1.0);
  float cw2 = pow(cos(cw * 1.5707964), 2.0);
  float eps = 0.0001;
  float atArg = atan(px * eps) * aC / eps;
  float waveBase = (cw2 * res * c68) * sin(atArg * uFreq + tw);
  float negBase = -c73;
  float atArg2 = atArg * uAberrationFreq + tw;
  float py = p.y;
  float n80sq = n80 * n80;
  float bft = max(uBandFillThickness, 0.0001);
  float n139 = (c61 * res) * n78;
  float env68 = cw2 * c68;
  vec2 mouseUv = uMouse.xy / max(uResolution, vec2(1.0));
  float mouseLift = uMouse.z * 0.035 * exp(-pow((mouseUv.x * 2.0 - 1.0) * 2.4, 2.0));

  vec3 colAcc = vec3(0.0);
  vec3 highlightAcc = vec3(0.0);
  vec3 spectralAcc = vec3(0.0);
  float achromaticCore = 0.0;
  float baseWeightSum = 0.0;
  float highlightWeightSum = 0.0;
  float waveCount = clamp(floor(uWaveCount + 0.5), 1.0, 8.0);
  for (int i = 0; i < 8; i += 1) {
    float fi = float(i);
    if (fi >= waveCount) continue;
    float t13 = (waveCount > 1.0) ? fi / (waveCount - 1.0) : 0.5;
    // Geometry and opacity may resolve from 0 to 1, but the palette must not.
    // Mixing from white here caused the visible pastel flash after an answer.
    vec3 hue = wavePaletteColor(i);
    vec3 highlightHue = waveHighlightColor(i);
    baseWeightSum += max(max(hue.r, hue.g), hue.b);
    highlightWeightSum += max(max(highlightHue.r, highlightHue.g), highlightHue.b);
    float ph = atArg2 + mix(negBase, c73, t13);
    float w2 = env68 * sin(ph) + mouseLift;
    // Split the same physical wave into RGB sampling positions. The shared
    // overlap remains white; only the displaced contours carry colour.
    float split = (0.026 + 0.020 * lo) * cw2;
    vec3 spectralDistance = abs(vec3(py - w2) + vec3(-split, 0.0, split));
    vec3 spectralEnergy = vec3(n78) / (sqrt(spectralDistance * spectralDistance + vec3(n80sq)) + vec3(n77));
    spectralAcc += pow(spectralEnergy, vec3(1.5));
    achromaticCore += exp(-pow((py - w2) / 0.024, 2.0));
    float dist = mix(edge, abs(py - w2), res);
    float rad = sqrt(dist * dist + n80sq) + n77;
    float k = dist * 0.02;
    float soft = mix(1.0 / (k * k + 1.0), 1.0, res);
    float glowL = (soft * n78) / rad;
    float band = max(0.0, max(py - max(waveBase, w2), min(waveBase, w2) - py));
    float fill = n139 / (band + bft);
    float layerEnergy = n81 * (fill + glowL);
    colAcc += hue * layerEnergy;
    highlightAcc += highlightHue * layerEnergy;
  }
  vec3 col = colAcc / max(baseWeightSum, 0.0001);
  vec3 highlightCol = highlightAcc / max(highlightWeightSum, 0.0001);
  float tail = omr * (c76 + 4.0);
  float dC = mix(edge, abs(py - waveBase), res);
  float radC = dC + n77;
  float kC = dC * 0.02;
  float softC = mix(1.0 / (kC * kC + 1.0), 1.0, res);
  float cg = (n78 * 0.5 * (softC + tail)) / radC;
  vec3 cgl = pow(vec3(cg) + col, vec3(1.5));
  float glowEnergy = max(max(cgl.r, cgl.g), cgl.b);
  float iceWhiteMix = smoothstep(0.35, 0.95, saturate(glowEnergy));
  float paletteEnergy = max(max(col.r, col.g), col.b);
  vec3 paletteColor = col / max(paletteEnergy, 0.0001);
  paletteColor = mix(uWaveColor0, paletteColor, step(0.0001, paletteEnergy));
  float highlightEnergy = max(max(highlightCol.r, highlightCol.g), highlightCol.b);
  vec3 highlightColor = highlightCol / max(highlightEnergy, 0.0001);
  highlightColor = mix(
    uWaveHighlightColor0,
    highlightColor,
    step(0.0001, highlightEnergy)
  );
  cgl = mix(paletteColor, highlightColor, iceWhiteMix) * glowEnergy;
  vec3 spectrum = spectralAcc / waveCount;
  float whiteCore = min(min(spectrum.r, spectrum.g), spectrum.b);
  spectrum = (vec3(whiteCore) + (spectrum - vec3(whiteCore)) * 2.3) * 7.0;
  spectrum = mix(spectrum, vec3(max(max(spectrum.r, spectrum.g), spectrum.b)), saturate(achromaticCore));
  cgl = mix(cgl, spectrum, uChromatic);
  float ndcY = gid.y * 2.0 / uResolution.y - 1.0;
  float emC = max(clamp(uEdgeMask, 0.0, 1.0), 0.0001);
  float emMask = clamp((abs(ndcY) - 1.0 + clamp(uEdgeMaskInset, 0.0, 1.0)) / (-emC), 0.0, 1.0);
  emMask = smoothUnit(emMask);
  float fall = exp(-pow(px * uFalloff, 2.0));
  col = cgl * mix(1.0, emMask * fall, res) * res * saturate(uLayerOpacity);
  // Keep the original energy response; the UI maps its new 100% to 4.0.
  // Extra energy passes through the soft limit without clipping crests white.
  float brightness = clamp(uWaveBrightness, 0.0, 4.0);
  col *= max(1.0, brightness);
  // Soft-limit energy before the RGBA8 target. Per-channel clipping turned
  // overlapping wave crests into a razor-thin, pure-white stripe.
  float peak = max(max(col.r, col.g), col.b);
  float mappedPeak = min(peak, 0.55) + 0.29 * (1.0 - exp(-max(peak - 0.55, 0.0) / 0.29));
  col *= mappedPeak / max(peak, 0.0001);
  col *= min(brightness, 1.0);
  float alpha = saturate(max(max(col.r, col.g), col.b) * 1.15);
  outColor = vec4(col, alpha);
}

