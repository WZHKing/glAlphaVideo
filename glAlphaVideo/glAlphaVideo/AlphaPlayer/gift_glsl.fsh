precision mediump float;

uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

void main (void) {
    vec4 mask = texture2D(Texture, TextureCoordsVarying);
    vec4 alpha = texture2D(Texture, TextureCoordsVarying + vec2(-0.5, 0.0));
    gl_FragColor = vec4(mask.rgb, alpha.r);
}
