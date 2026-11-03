"""Ideal angular coverage, not a detector performance or calibration model."""
from dataclasses import dataclass
from math import atan2, degrees, hypot, radians, tan, cos, sin

MODES = ('App only', 'App + privacy', 'App + fisheye',
         'App + fisheye + privacy', 'App + radar', 'App + radar + privacy')


@dataclass
class Config:
    camera_deg: float = 75.0
    privacy_deg: float = 60.0
    readable_deg: float = 160.0
    fisheye_deg: float = 120.0
    fisheye_nominal_deg: float = 180.0
    radar_deg: float = 120.0
    radar_vertical_deg: float = 70.0
    distance: float = 0.40
    orientation_deg: float = 0.0
    radar_x: float = -0.6
    radar_y: float = -0.2
    radar_orientation_deg: float = 0.0
    range_m: float = 2.0
    body_radius: float = 0.10
    optical_occlusion: bool = False
    radar_occlusion: bool = False

    def __post_init__(self):
        for name in ('camera_deg', 'privacy_deg', 'readable_deg', 'fisheye_deg',
                     'fisheye_nominal_deg', 'radar_deg', 'radar_vertical_deg'):
            if not 0 < getattr(self, name) <= 360:
                raise ValueError(f'{name} must be in (0, 360]')
        if self.distance <= 0 or self.range_m <= 0 or self.body_radius < 0:
            raise ValueError('Distances/range must be positive; radius nonnegative')


def width(distance, total_deg):
    """Plane intersection width; finite only for total angles below 180 degrees."""
    if distance < 0 or not 0 < total_deg < 180:
        raise ValueError('Plane width requires d >= 0 and 0 < angle < 180')
    return 2 * distance * tan(radians(total_deg / 2))


def sector(point, origin, heading, angle, radius):
    dx, dy = point[0] - origin[0], point[1] - origin[1]
    bearing = degrees(atan2(dx, dy))
    delta = (bearing - heading + 180) % 360 - 180
    return hypot(dx, dy) <= radius + 1e-12 and abs(delta) <= angle / 2 + 1e-12


def occluded(point, origin, blockers, radius):
    dx, dy = point[0] - origin[0], point[1] - origin[1]
    norm = dx * dx + dy * dy
    if norm == 0:
        return False
    for bx, by in blockers:
        t = ((bx - origin[0]) * dx + (by - origin[1]) * dy) / norm
        if 0 < t < 1 and hypot(bx - origin[0] - t * dx,
                              by - origin[1] - t * dy) <= radius:
            return True
    return False


def user_position(c):
    return (c.distance * sin(radians(c.orientation_deg)),
            c.distance * cos(radians(c.orientation_deg)))


def evaluate(c, mode, observers):
    """Return observer flags plus instantaneous threat (no authentication model).

    The designated user is not an optical threat. Radar counts all targets and
    makes no identity claim. Readability ignores bodies conservatively.
    """
    if mode not in range(6):
        raise ValueError('mode must be 0..5')
    people = [user_position(c)] + list(observers)
    radar = (c.radar_x, c.radar_y)
    radar_seen = []
    optical_seen = []
    for i, p in enumerate(people):
        blockers = people[:i] + people[i + 1:]
        optical_seen.append(sector(p, (0, 0), c.orientation_deg,
                                  c.fisheye_deg if mode in (2, 3) else c.camera_deg,
                                  c.range_m) and not (c.optical_occlusion and
                                  occluded(p, (0, 0), blockers, c.body_radius)))
        radar_seen.append(sector(p, radar, c.radar_orientation_deg, c.radar_deg,
                                 c.range_m) and not (c.radar_occlusion and
                                 occluded(p, radar, blockers, c.body_radius)))
    radar_threat = mode in (4, 5) and sum(radar_seen) > 1
    rows = []
    for i, p in enumerate(observers, 1):
        readable = sector(p, (0, 0), c.orientation_deg,
                          c.privacy_deg if mode % 2 else c.readable_deg, c.range_m)
        detected = optical_seen[i] or (mode in (4, 5) and radar_seen[i])
        rows.append(dict(readable=readable, optical=optical_seen[i],
                         radar=radar_seen[i] if mode in (4, 5) else False,
                         detected=detected, readable_but_undetected=readable and not detected))
    threat = any(optical_seen[1:]) or radar_threat
    for row in rows:
        row['breach'] = row['readable'] and not threat
    return rows, threat, sum(radar_seen) if mode in (4, 5) else 0
