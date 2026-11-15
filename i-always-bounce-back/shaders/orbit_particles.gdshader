// CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
// 3D MODELS: SKETCHFAB
// BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

shader_type particles;

uniform float radius_min = 0.6;
uniform float radius_max = 1.7;
uniform float orbit_speed = 2.0;
uniform float inward_pull = 0.18;
uniform float wobble = 0.25;
uniform float size_min = 0.05;
uniform float size_max = 0.14;
uniform float spin = 1.5;
uniform float brightness = 1.0;
uniform vec4 tint : source_color = vec4(1.0);

float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0) {
		s = 305420679;
	}
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0) {
		s += 2147483647;
	}
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

vec3 random_direction(inout uint seed) {
	float z = rand_from_seed(seed) * 2.0 - 1.0;
	float phi = rand_from_seed(seed) * 6.28318530718;
	float r = sqrt(max(1.0 - z * z, 0.0));
	return vec3(r * cos(phi), z, r * sin(phi));
}

vec3 rotate_around(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void start() {
	uint seed = hash(NUMBER + uint(1) + RANDOM_SEED);
	if (rand_from_seed(seed) > AMOUNT_RATIO) {
		ACTIVE = false;
	}
	vec3 direction = random_direction(seed);
	float shell = pow(rand_from_seed(seed), 0.3333);
	float radius = mix(radius_min, radius_max, shell);
	vec3 other = random_direction(seed);
	vec3 axis = cross(direction, other);
	if (length(axis) < 0.001) {
		axis = cross(direction, vec3(0.0, 1.0, 0.0));
	}
	axis = normalize(axis);
	float speed_scale = mix(0.45, 1.6, rand_from_seed(seed));
	if (rand_from_seed(seed) > 0.5) {
		speed_scale = -speed_scale;
	}
	float size = mix(size_min, size_max, rand_from_seed(seed));
	USERDATA1 = vec4(axis, speed_scale);
	CUSTOM = vec4(rand_from_seed(seed) * 6.28318530718, 0.0, size, rand_from_seed(seed));
	TRANSFORM = mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0), vec4(direction * radius, 1.0));
	VELOCITY = vec3(0.0);
	COLOR = vec4(tint.rgb, 0.0);
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	float age = clamp(CUSTOM.y, 0.0, 1.0);
	vec3 axis = USERDATA1.xyz;
	float speed_scale = USERDATA1.w;
	vec3 position = TRANSFORM[3].xyz;
	position = rotate_around(position, axis, orbit_speed * speed_scale * DELTA);
	float radius = length(position);
	float breathe = sin(TIME * 2.0 + CUSTOM.w * 6.28318530718) * wobble * DELTA;
	float new_radius = max(radius * (1.0 - inward_pull * DELTA) + breathe, 0.05);
	position = normalize(position) * new_radius;
	CUSTOM.x += spin * speed_scale * DELTA;
	float fade = smoothstep(0.0, 0.18, age) * (1.0 - smoothstep(0.72, 1.0, age));
	float size = CUSTOM.z * mix(0.6, 1.0, fade);
	TRANSFORM = mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0), vec4(position, 1.0));
	VELOCITY = vec3(0.0);
	COLOR = vec4(tint.rgb * brightness, tint.a * fade);
}
