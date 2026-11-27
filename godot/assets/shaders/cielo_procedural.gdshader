shader_type sky;

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float day_factor : hint_range(0.0, 1.0) = 1.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.25;
uniform float cloud_darkness : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;
uniform float star_visibility : hint_range(0.0, 1.0) = 0.0;

uniform vec3 sky_top_color : source_color = vec3(0.12, 0.37, 0.66);
uniform vec3 sky_horizon_color : source_color = vec3(0.62, 0.83, 0.96);
uniform vec3 ground_color : source_color = vec3(0.10, 0.12, 0.15);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.80);
uniform vec3 moon_color : source_color = vec3(0.79, 0.85, 0.95);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise2(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	vec3 col = mix(sky_horizon_color, sky_top_color, pow(clamp(y, 0.0, 1.0), 0.55));
	if (y < 0.0) {
		col = mix(sky_horizon_color, ground_color, clamp(-y * 3.0, 0.0, 1.0));
	}

	// Disco solar y halo
	vec3 sdir = normalize(sun_direction);
	float sun_dot = max(dot(dir, sdir), 0.0);
	float sun_disk = smoothstep(0.9985, 0.9994, sun_dot);
	float sun_halo = pow(sun_dot, 16.0) * 0.35;
	col += sun_color * (sun_disk * 2.2 + sun_halo) * day_factor * (1.0 - cloud_darkness * 0.75);

	// Disco lunar en direccion opuesta al sol
	vec3 mdir = -sdir;
	float moon_dot = max(dot(dir, mdir), 0.0);
	float moon_disk = smoothstep(0.9990, 0.9996, moon_dot);
	float moon_halo = pow(moon_dot, 32.0) * 0.12;
	col += moon_color * (moon_disk * 1.1 + moon_halo) * star_visibility * (1.0 - cloud_darkness * 0.8);

	// Estrellas nocturnas procedurales
	if (y > 0.02 && star_visibility > 0.01) {
		vec2 star_uv = dir.xz / (y + 0.35) * 90.0;
		vec2 star_id = floor(star_uv);
		vec2 star_f = fract(star_uv) - 0.5;
		float rnd = hash21(star_id);
		if (rnd > 0.965) {
			float d = length(star_f);
			float star = smoothstep(0.22, 0.02, d) * (0.6 + 0.4 * sin(time_offset * 2.5 + rnd * 40.0));
			col += vec3(0.85, 0.90, 1.0) * star * star_visibility * clamp(y * 4.0, 0.0, 1.0);
		}
	}

	// Nubes FBM animadas
	if (y > 0.01 && cloud_coverage > 0.01) {
		vec2 uv_nube = dir.xz / max(y, 0.08) * 0.65 + vec2(time_offset * 0.018, time_offset * 0.008);
		float n = fbm(uv_nube);
		float umbral = mix(0.85, 0.22, cloud_coverage);
		float densidad = smoothstep(umbral, umbral + 0.25, n) * clamp(y * 5.0, 0.0, 1.0);
		vec3 nube_dia = mix(vec3(0.95, 0.97, 1.0), vec3(0.38, 0.42, 0.48), cloud_darkness);
		vec3 nube_noche = mix(vec3(0.10, 0.14, 0.22), vec3(0.06, 0.08, 0.12), cloud_darkness);
		vec3 nube_col = mix(nube_noche, nube_dia, day_factor);
		col = mix(col, nube_col, densidad * 0.88);
	}

	COLOR = col;
}
