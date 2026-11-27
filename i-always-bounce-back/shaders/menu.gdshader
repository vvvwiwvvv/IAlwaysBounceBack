shader_type canvas_item;
uniform float opa = 1.0;
void fragment() {
    COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.1, 1.8, length((UV - vec2(0.5)) * 2.0)) * 0.7 *opa);
}