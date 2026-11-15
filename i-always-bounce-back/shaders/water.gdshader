// CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
// 3D MODELS: SKETCHFAB
// BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

shader_type spatial;

uniform vec3 shallow_color : source_color = vec3(0.25, 0.82, 0.8);
uniform vec3 deep_color : source_color = vec3(0.04, 0.3, 0.56);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float ripple_scale = 0.035;
uniform float ripple_speed = 0.02;
uniform float depth_fade = 9.0;
uniform float foam_width = 0.7;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	scene.xyz /= scene.w;
	float thickness = max(VERTEX.z - scene.z, 0.0);

	vec2 uv = world_pos.xz * ripple_scale;
	vec3 n1 = texture(ripple_normal, uv + TIME * ripple_speed * vec2(1.0, 0.6)).rgb;
	vec3 n2 = texture(ripple_normal, uv * 1.7 - TIME * ripple_speed * vec2(0.7, 1.0)).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;

	float deep = clamp(thickness / depth_fade, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, deep);
	float foam_noise = texture(ripple_normal, uv * 3.0 + TIME * 0.03).r;
	float foam = 1.0 - smoothstep(0.0, foam_width * (0.6 + foam_noise), thickness);
	col = mix(col, foam_color, foam * 0.85);

	ALBEDO = col;
	ALPHA = clamp(0.55 + deep * 0.4 + foam, 0.0, 0.96);
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
