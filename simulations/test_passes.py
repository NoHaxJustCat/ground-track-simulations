import numpy as np

from Ground_track_utilities import find_passes, elevation_deg

# synthetic elevation: 40*sin, above 20 deg for 1/3 of each 600 s period -> 200 s passes
t = np.arange(0, 3000, 7.0)
el = 40 * np.sin(2 * np.pi * t / 600)
s, e = find_passes(t, el, 20.0)
assert len(s) == 5 and np.allclose(e - s, 200, atol=3), (s, e)

# truncated passes at window edges are dropped
s, e = find_passes(t[10:], el[10:], 20.0)  # starts mid-pass
assert len(s) == 4

# satellite 500 km along the local vertical of a point at 52N 4.4E (WGS84) -> 90 deg
lat, lon = np.deg2rad(52.0), np.deg2rad(4.4)
up = np.array([np.cos(lat) * np.cos(lon), np.cos(lat) * np.sin(lon), np.sin(lat)])
n = 6378137.0 / np.sqrt(1 - 6.69437999014e-3 * np.sin(lat) ** 2)
ground = n * up * [1, 1, 1 - 6.69437999014e-3]
assert abs(elevation_deg(np.array([ground + 5e5 * up]), 52.0, 4.4)[0] - 90) < 1e-6
assert abs(elevation_deg(np.array([ground + 5e5 * np.cross(up, [0, 0, 1])]), 52.0, 4.4)[0]) < 1e-6
print("ok")
