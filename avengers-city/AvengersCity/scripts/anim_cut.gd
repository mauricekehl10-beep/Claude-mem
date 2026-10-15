extends RefCounted
# Schneidet einen Ausschnitt aus einem Mixamo-Clip.


# Schneidet [von, bis] aus einem Clip. Start- und Endpose werden genau berechnet.
# "halten" Sekunden lang bleibt danach die Endpose stehen (der Clip endet also nicht gleich).
static func cut(an: Animation, from: float, to: float, hold: float) -> Animation:
	var out := Animation.new()
	out.length = to - from + hold
	for t in range(an.get_track_count()):
		var type := an.track_get_type(t)
		var nt := out.add_track(type)
		out.track_set_path(nt, an.track_get_path(t))
		out.track_set_interpolation_type(nt, an.track_get_interpolation_type(t))
		var times := [from]
		for k in range(an.track_get_key_count(t)):
			var kt := an.track_get_key_time(t, k)
			if kt > from + 0.001 and kt < to - 0.001:
				times.append(kt)
		times.append(to)
		var last = null
		for kt in times:
			if type == Animation.TYPE_POSITION_3D:
				last = an.position_track_interpolate(t, kt)
			elif type == Animation.TYPE_ROTATION_3D:
				last = an.rotation_track_interpolate(t, kt)
			else:
				last = an.scale_track_interpolate(t, kt)
			out.track_insert_key(nt, kt - from, last)
		if hold > 0.0:
			out.track_insert_key(nt, out.length, last)
	return out
