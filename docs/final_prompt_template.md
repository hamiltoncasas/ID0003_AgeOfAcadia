================================================================================
PROMPT TEMPLATE — AGE OF ACADIA SPRITES
================================================================================
Instrucciones: Reemplazar [UNIT_TYPE], [ANIM_DESC], [GRID_LAYOUT] segun corresponda.

=== PROMPT BASE DEL PERSONAJE (usar siempre igual) ===

Pixel art game sprite de [UNIT_TYPE] medieval varon,
civilizacion ACADIA.

Edad: aproximadamente 30-35 anos.
Estatura: 1.75m proporcion realista.
Complexion: cuerpo robusto y trabajado, hombros anchos,
brazos musculosos, cintura delgada.

Cabeza: forma ovalada, mandibula cuadrada pero suave.
Ojos: color marron oscuro, mirada atenta al frente.
Nariz: mediana, recta, proporcionada.
Boca: pequena, entrecerrada, expresion neutra concentrada.
Barba: barba corta y bien cuidada de 3-5mm, color castano oscuro.
Pelo: color castano claro, corto, peinado sencillo despeinado natural.

Tunica principal: azul real (#2E5BFF) de manga larga,
tejido lona gruesa, ligeramente desgastada,
pliegues naturales en codos y cintura,
borde inferior hasta media pierna.

Ribetes: color blanco (#FFFFFF) en bordes de mangas,
cuello redondo y dobladillo inferior, costura visible de 2px.

Cinturon: cuero marron oscuro (#4A2C1A) de 4px,
hebilla metalica acero gris al centro.

Pantalones: gris acero (#708090) visibles bajo la tunica.

Botas: cuero marron (#5C3A1E) media altura, suela oscura,
cordones de cuero visibles, punta redondeada.

Estilo: pixel art RTS estilo Age of Empires 2,
paleta limitada consistente, sombreado suave 3-4 niveles,
iluminacion desde esquina superior izquierda,
silueta limpia y facil de distinguir.
Sin sombra artificial, sin texto, sin logo, sin marca de agua.
Un solo personaje, sin duplicados, sin fondos ni decoraciones.

=== ANIMACION (reemplazar segun movimiento) ===

[ANIM_DESC]

=== COMPOSICION DEL SPRITESHEET ===

[GRID_LAYOUT]

Cada frame 512x512 pixeles cada uno.
Mismo personaje exacto en todos los frames.
Fondo completamente transparente PNG RGBA canal alfa.
1024x1024 pixeles total.
================================================================================

=== EJEMPLO RUN (4 FRAMES) ===

ANIMACION:
Corriendo hacia adelante, vista frontal, 4 frames del ciclo de carrera.

GRILLA (2x2):
TOP LEFT - Frame 1: pierna izquierda extendida hacia adelante tocando suelo,
pierna derecha extendida hacia atras despegando, brazos balanceandose naturalmente.

TOP RIGHT - Frame 2: piernas pasando una a la otra en medio del paso,
cuerpo en el punto mas bajo del ciclo, ambos pies brevemente en el aire.

BOTTOM LEFT - Frame 3: pierna derecha extendida hacia adelante tocando suelo,
pierna izquierda extendida hacia atras despegando, opuesto al frame 1.

BOTTOM RIGHT - Frame 4: piernas pasando nuevamente lado opuesto,
cuerpo elevandose del punto mas bajo, brazos en medio del balanceo opuesto.

=== PARAMETROS TECNICOS ===

Modelo: black-forest-labs/FLUX.1-schnell
Steps: 4
Seed: 256 (consistencia entre generaciones)
Resolucion spritesheet: 1024x1024
Resolucion frame individual: 256x256 (downscale NEAREST)
Formato: PNG RGBA con canal alfa
Post-procesado: correccion de fondo por color + limpieza de islas
