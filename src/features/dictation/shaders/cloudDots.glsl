#version 300 es
// Adapted from Darlingfxx02/no-tipe, Prototypes/no-tipe-island-variants.html.
precision highp float;
uniform vec2 uResolution;
uniform float uTime;
uniform vec4 uMouse;
uniform float uDotsResolved;
uniform float uEffectScale;
uniform vec2 uAnchor;
uniform float uRotation;
uniform float uRingRadius;
uniform float uDotRadius;
uniform float uPairOffset;
uniform float uPairSmoothness;
uniform float uSmoothness;
uniform float uProgress0;
uniform float uProgress1;
uniform float uProgress2;
uniform float uProgress3;
uniform float uProgress4;
uniform float uProgress5;
uniform float uScaleDuration;
uniform float uScaleStagger;
uniform float uScaleMin;
uniform float uScaleMax;
uniform float uGlowIntensity;
uniform float uFalloffPower;
uniform float uGlowFadeStart;
uniform float uGlowFadeEnd;
uniform float uDotsAberration;
uniform float uCenterCore;
uniform float uDotsScale;
uniform float uAppear;
uniform float uGather;
uniform float uCharge;
uniform float uFlash;
uniform vec3 uParticleTint;
uniform float uParticleNeutral;
uniform float uSuccess;
uniform float uError;
uniform float uCopied;
out vec4 outColor;

float saturate(float value) { return clamp(value, 0.0, 1.0); }
vec3 spectrumTri(float t) {
  return clamp(vec3(abs(t - 3.0) - 1.0, 2.0 - abs(t - 2.0), 2.0 - abs(t - 4.0)), 0.0, 1.0);
}
float progressAt(int index) {
  if (index == 0) return uProgress0;
  if (index == 1) return uProgress1;
  if (index == 2) return uProgress2;
  if (index == 3) return uProgress3;
  if (index == 4) return uProgress4;
  return uProgress5;
}
vec2 checkPoint(int index) {
  if (index == 0) return vec2(-0.48, -0.03);
  if (index == 1) return vec2(-0.295, 0.155);
  if (index == 2) return vec2(-0.11, 0.34);
  if (index == 3) return vec2(0.11, 0.10);
  if (index == 4) return vec2(0.33, -0.14);
  return vec2(0.55, -0.38);
}
float segmentDistance(vec2 p, vec2 a, vec2 b) {
  vec2 ab = b - a;
  float t = clamp(dot(p-a, ab) / max(dot(ab, ab), 0.00001), 0.0, 1.0);
  return length(p - a - ab*t);
}
float checkScale() {
  return mix(0.68, 1.0, smoothstep(0.25, 1.0, uSuccess));
}
vec2 scaledCheckPoint(int index) {
  vec2 errorPoint = index < 4 ? vec2(0.0, -0.42 + float(index) * 0.17) : vec2(0.0, 0.38);
  return mix(checkPoint(index), errorPoint, uError) * checkScale();
}
vec2 copyPoint(int index, bool front) {
  vec2 point = index == 0 ? vec2(-0.23, -0.23) : index == 1 ? vec2(0.0, -0.29) :
    index == 2 ? vec2(0.23, -0.23) : index == 3 ? vec2(0.23, 0.23) :
    index == 4 ? vec2(0.0, 0.29) : vec2(-0.23, 0.23);
  return (point + (front ? vec2(0.15) : vec2(-0.17))) * checkScale();
}
float copyBox(vec2 p, vec2 center) {
  vec2 q = abs(p - center) - vec2(0.23);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.065;
}
float copyDistance(vec2 p) {
  float front = copyBox(p, vec2(0.15));
  float back = copyBox(p, vec2(-0.17));
  // The rear sheet stops cleanly before the front sheet, leaving a readable gap.
  return min(abs(front) - 0.052, max(abs(back) - 0.052, -front + 0.085));
}
float dotsField(
  vec2 P, vec2 aberOff, vec2 centersA[6], vec2 centersB[6],
  vec2 dirs[6], float radii[6], bool psOn, bool smOn,
  float pairSmooth, float smoothness, float pairK, float smK
) {
  float field = 1.0e9;
  for (int j = 0; j < 6; j += 1) {
    vec2 ofs = aberOff * dirs[j];
    float lenA = length(P + ofs - centersA[j]);
    float lenB = length(P + ofs - centersB[j]);
    float dA = lenA - radii[j];
    float dB = lenB - radii[j];
    float dPair = min(dA, dB);
    if (psOn) {
      float h = max(pairSmooth - abs(lenA - lenB), 0.0) / pairSmooth;
      dPair = min(dA, dB) - h * h * pairK;
    }
    if (smOn) {
      float h2 = max(smoothness - abs(field - dPair), 0.0) / smoothness;
      field = min(field, dPair) - h2 * h2 * smK;
    } else {
      field = min(field, dPair);
    }
  }
  // The same particles form the two strokes; their gaps close near the end.
  vec2 checkP = P + aberOff * (1.0 - uSuccess);
  vec2 a = scaledCheckPoint(0);
  vec2 b = scaledCheckPoint(2);
  vec2 c = scaledCheckPoint(5);
  float check = min(segmentDistance(checkP, a, b),
                    segmentDistance(checkP, b, c)) - 0.062 * checkScale();
  float exclamation = min(segmentDistance(checkP, vec2(0.0, -0.42), vec2(0.0, 0.09)) - 0.065,
                          length(checkP - vec2(0.0, 0.38)) - 0.08);
  check = mix(check, copyDistance(checkP / checkScale()) * checkScale(), smoothstep(0.0, 1.0, uCopied));
  check = mix(check, exclamation, smoothstep(0.25, 1.0, uError));
  return mix(field, check, smoothstep(0.50, 0.82, uSuccess));
}

void main() {
  vec2 gid = vec2(gl_FragCoord.x, uResolution.y - gl_FragCoord.y);
  float mn = min(uResolution.x, uResolution.y);
  float halfMn = mn * 0.5;
  vec2 anchorC = uAnchor - 0.5;
  float aspect2 = uResolution.x / halfMn;
  vec2 anchorShift = vec2(aspect2, 2.0) * anchorC;
  float pr = max(uDotsScale * uEffectScale, 0.001);
  float drive = mod(uTime, 62.831848) * uRotation;
  float scaleDur = max(uScaleDuration, 0.001);
  float appear = saturate(uAppear) * saturate(uDotsResolved);
  float ringAmp = appear * uRingRadius;
  float pairAmp = appear * uPairOffset;
  float assembly = smoothstep(0.0, 0.65, uSuccess);
  vec2 centersA[6];
  vec2 centersB[6];
  vec2 dirs[6];
  float radii[6];

  for (int i = 0; i < 6; i += 1) {
    float fi = float(i);
    float angle = fi * 1.0471976 + drive;
    float ca = cos(angle);
    float sa = sin(angle);
    vec2 perp = vec2(-sa, ca);
    float fr = fract((fi * uScaleStagger + uTime) / scaleDur);
    float tri = 1.0 - abs(fr * 2.0 - 1.0);
    float x = saturate(tri);
    for (int k = 0; k < 8; k += 1) {
      float omx = 1.0 - x;
      float a3 = omx * 3.0;
      float c126 = (omx * 0.42) * a3;
      float x2 = x * x;
      float deriv = (x2 * 1.26) + (x * 0.96) * omx + c126;
      if (abs(deriv) < 0.000001) break;
      float num = ((x2 * 0.58) * a3 - tri) + (c126 + x2) * x;
      x = saturate(x - num / deriv);
    }
    float ss = x * x * (3.0 - 2.0 * x);
    float amp = mix(uScaleMin, uScaleMax, ss);
    amp = mix(amp, 0.45, uGather) * (1.0 - 0.18 * saturate(uCharge));
    vec2 dir = vec2(ca, sa);
    vec2 base = (ringAmp * dir) * (1.0 - 2.0 * progressAt(i));
    base = mix(base, dir * 0.008, uGather);
    // Keep the live orbit while assembling a front-facing check, then scale it up.
    vec2 point = mix(base, scaledCheckPoint(i), assembly);
    float ph2 = pairAmp * amp * (1.0 - uGather) * (1.0 - assembly);
    centersA[i] = point - ph2 * perp;
    centersB[i] = point + ph2 * perp;
    // Each orbiting pair becomes one point on each sheet. Both outlines assemble
    // together from the live orbit, without first passing through a checkmark.
    centersA[i] = mix(centersA[i], mix(base - ph2 * perp, copyPoint(i, false), assembly), uCopied);
    centersB[i] = mix(centersB[i], mix(base + ph2 * perp, copyPoint(i, true), assembly), uCopied);
    dirs[i] = dir;
    radii[i] = mix(amp * uDotRadius, 0.062 * checkScale(), assembly);
  }

  vec2 uvPix = (gid + 0.5 - 0.5 * uResolution) / halfMn;
  vec2 P = (uvPix - anchorShift) / pr;
  bool psOn = uPairSmoothness > 0.0001;
  bool smOn = uSmoothness > 0.0001;
  float fadeRange = max(uGlowFadeEnd - uGlowFadeStart, 0.0001);
  float aberStep = uDotsAberration * 0.0909090936;
  float glowIntensity = uGlowIntensity * mix(1.0, 0.65, uCopied * smoothstep(0.4, 0.85, uSuccess));
  vec3 colAcc = vec3(0.0);
  vec3 wSum = vec3(0.0);
  for (int i = 0; i < 12; i += 1) {
    float ti = float(i) * 0.363636374;
    vec3 hue = spectrumTri(ti);
    vec2 aberOff = vec2(-(aberStep * float(i)));
    float field = dotsField(P, aberOff, centersA, centersB, dirs, radii,
      psOn, smOn, uPairSmoothness, uSmoothness,
      uPairSmoothness * 0.25, uSmoothness * 0.25);
    float fm = max(field, 0.0);
    float glow = saturate(glowIntensity / pow(fm + 0.0001, uFalloffPower));
    float fadeT = clamp((fm - uGlowFadeStart) / fadeRange, 0.0, 1.0);
    float fade = 1.0 - fadeT * fadeT * (3.0 - 2.0 * fadeT);
    colAcc += hue * (fade * glow);
    wSum += hue;
  }
  float cfield = dotsField(P, vec2(0.0), centersA, centersB, dirs, radii,
    psOn, smOn, uPairSmoothness, uSmoothness,
    uPairSmoothness * 0.25, uSmoothness * 0.25);
  vec3 col = colAcc / max(wSum, vec3(0.0001));
  float cfm = max(cfield, 0.0);
  float cglow = saturate(glowIntensity / pow(cfm + 0.0001, uFalloffPower));
  float cfadeT = clamp((cfm - uGlowFadeStart) / fadeRange, 0.0, 1.0);
  float cfade = 1.0 - cfadeT * cfadeT * (3.0 - 2.0 * cfadeT);
  vec2 mouseUv = uMouse.xy / max(uResolution, vec2(1.0));
  float mouseBoost = 1.0 + uMouse.z * 0.35 + uMouse.w * 0.2 +
    smoothstep(0.0, 0.16, 1.0 - distance(mouseUv, vec2(0.5))) * 0.05;
  col = (col + (cglow * uCenterCore) * cfade) * appear * mouseBoost;
  col *= mix(1.0, 0.85, saturate(uGather)) *
    (1.0 + 0.35 * saturate(uCharge) + 1.2 * uFlash);
  // Indigo/lavender palette from Figma accent #5E6AD2; preserve particle energy and motion.
  float particleEnergy = max(max(col.r, col.g), col.b);
  vec3 particleTint = mix(mix(uParticleTint, vec3(0.85), uParticleNeutral), vec3(0.92, 0.92, 1.0),
    smoothstep(0.04, 0.90, particleEnergy));
  // Green is reserved for the completed check, without a white completion flash.
  vec3 successTint = mix(vec3(0.22, 0.84, 0.48), vec3(0.98, 0.30, 0.34), uError);
  particleTint = mix(particleTint, successTint, smoothstep(0.10, 0.90, uSuccess));
  col = particleTint * particleEnergy;
  float m = max(max(col.r, col.g), col.b);
  col *= (m > 1.0) ? (1.0 / m) : 1.0;
  float alpha = saturate(max(max(col.r, col.g), col.b));
  outColor = vec4(col, alpha);
}

