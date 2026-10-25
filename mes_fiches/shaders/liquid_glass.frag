#version 460 core

#include <flutter/runtime_effect.glsl>

// Verre liquide : réfraction sur les bords (effet lentille), léger grossissement,
// aberration chromatique et reflet. Utilisé comme filtre d'arrière-plan.

uniform vec2 uSize;       // taille de la texture (fournie par le moteur)
uniform vec4 uRect;       // x, y, largeur, hauteur de la barre (pixels physiques)
uniform float uRadius;    // rayon des coins (px)
uniform float uBevel;     // largeur de la zone qui réfracte (px)
uniform float uStrength;  // déplacement maximal (px)
uniform float uDark;      // 1.0 en mode sombre
uniform float uBlur;      // rayon du flou (px)

uniform sampler2D uTexture;

out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 sampleAt(vec2 px) {
  vec2 uv = clamp(px, vec2(0.5), uSize - 0.5) / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;  // texture inversée verticalement sous OpenGL ES
#endif
  return texture(uTexture, uv).rgb;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 hs = uRect.zw * 0.5;
  vec2 p = frag - (uRect.xy + hs);
  float d = sdRoundRect(p, hs, uRadius);

  if (d > 0.0) {
    fragColor = vec4(sampleAt(frag), 1.0);
    return;
  }

  // Normale du bord (gradient de la distance signée).
  vec2 e = vec2(1.0, 0.0);
  vec2 n = normalize(vec2(
      sdRoundRect(p + e.xy, hs, uRadius) - sdRoundRect(p - e.xy, hs, uRadius),
      sdRoundRect(p + e.yx, hs, uRadius) - sdRoundRect(p - e.yx, hs, uRadius)) + 1e-5);

  // 0 sur le bord → 1 à l'intérieur ; la courbure est forte près du bord.
  float depth = clamp(-d / uBevel, 0.0, 1.0);
  float bend = pow(1.0 - depth, 2.5);

  // Grossissement léger au centre + réfraction vers l'intérieur sur les bords.
  vec2 base = (uRect.xy + hs) + p * 0.94;
  vec2 offset = -n * bend * uStrength;

  // Aberration chromatique : chaque canal est réfracté un peu différemment.
  float r = sampleAt(base + offset * 1.12).r;
  float g = sampleAt(base + offset).g;
  float b = sampleAt(base + offset * 0.88).b;
  vec3 col = vec3(r, g, b);

  // Flou : deux anneaux de 8 échantillons autour du point réfracté.
  vec2 c = base + offset;
  vec3 soft = vec3(0.0);
  for (int i = 0; i < 8; i++) {
    float a = float(i) * 0.785398;  // 45°
    vec2 dir = vec2(cos(a), sin(a));
    soft += sampleAt(c + dir * uBlur * 0.5) * 0.6;
    soft += sampleAt(c + dir * uBlur) * 0.4;
  }
  soft /= 8.0;
  col = mix(col, soft, 0.75);

  // Reflet : bord haut-gauche lumineux, bord bas plus sombre.
  float light = dot(n, normalize(vec2(-0.4, -1.0)));
  col += vec3(1.0) * bend * max(light, 0.0) * mix(0.35, 0.22, uDark);
  col -= vec3(1.0) * bend * max(-light, 0.0) * mix(0.06, 0.10, uDark);

  // Fine teinte pour garder le texte des onglets lisible.
  vec3 tint = mix(vec3(1.0), vec3(0.08, 0.06, 0.14), uDark);
  col = mix(col, tint, mix(0.18, 0.28, uDark));

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
