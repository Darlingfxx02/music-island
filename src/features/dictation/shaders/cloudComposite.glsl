#version 300 es
// Adapted from Darlingfxx02/no-tipe, Prototypes/no-tipe-island-variants.html.
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uEffectTexture;
uniform vec2 uCanvasSize;
uniform vec2 uEffectOrigin;
uniform vec2 uEffectSize;
uniform float uContainer;
uniform float uContainerBlack;
uniform float uContainerFade;
uniform float uContainerGauss;
uniform vec3 uContainerTint;
uniform float uAnger;
out vec4 outColor;
void main() {
  vec2 pixel = vec2(gl_FragCoord.x, uResolution.y - gl_FragCoord.y);
  vec2 effectUv = (pixel - uEffectOrigin) / uEffectSize;
  vec2 inRect = step(vec2(0.0), effectUv) * step(effectUv, vec2(1.0));
  if (inRect.x * inRect.y < 0.5) discard;
  vec4 effect = texture(uEffectTexture, vec2(effectUv.x, 1.0 - effectUv.y));
  float gy = clamp(effectUv.y, 0.0, 1.0);
  float t = clamp((gy - uContainerBlack) / max(uContainerFade, 0.001), 0.0, 1.0);
  float vfade = (gy <= uContainerBlack) ? 1.0 : exp(-uContainerGauss * t * t);
  float edgeLR = smoothstep(0.0, 0.14, min(effectUv.x, 1.0 - effectUv.x));
  float containerA = clamp(uContainer, 0.0, 1.0) * vfade * edgeLR;
  vec3 containerColor = mix(vec3(0.0), uContainerTint,
    clamp(uAnger, 0.0, 1.0) * vfade);
  float invEffectA = 1.0 - effect.a;
  vec3 outRGB = effect.rgb + containerColor * containerA * invEffectA;
  float outA = effect.a + containerA * invEffectA;
  outColor = vec4(outRGB, outA);
}

