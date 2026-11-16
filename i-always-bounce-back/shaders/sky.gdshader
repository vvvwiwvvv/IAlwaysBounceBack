// CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
// 3D MODELS: SKETCHFAB
// BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

shader_type sky;

uniform vec3 top_color : source_color = vec3(0.18, 0.45, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.86, 1.0);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shadow_color : source_color = vec3(0.62, 0.7, 0.86);
uniform float cloud_cover = 0.48;
uniform float cloud_speed = 0.012;
uniform float sun_glow = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(up, 0.5));
	col = mix(col, horizon_color * 0.75, smoothstep(0.0, -0.35, dir.y));

	float sun = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	vec3 sun_tint = LIGHT0_COLOR * clamp(LIGHT0_ENERGY, 0.0, 1.5);
	col += sun_tint * pow(sun, 24.0) * sun_glow;
	col += sun_tint * pow(sun, 400.0) * 0.6;

	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.12) * 0.55 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float n = fbm(uv);
		float edge = 1.0 - cloud_cover;
		float mask = smoothstep(edge, edge + 0.22, n);
		float lit = smoothstep(edge + 0.05, edge + 0.4, fbm(uv + LIGHT0_DIRECTION.xz * 0.12));
		vec3 cloud = mix(cloud_color, cloud_shadow_color, lit * 0.8);
		cloud += sun_tint * pow(sun, 6.0) * 0.25;
		mask *= smoothstep(0.0, 0.12, dir.y);
		col = mix(col, cloud, mask * 0.92);
	}

	col += sun_tint * smoothstep(0.9993, 0.9997, sun) * 4.0;
	COLOR = col;
}
