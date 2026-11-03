import math
import unittest
from simulation.geometry import Config, evaluate, occluded, sector, user_position, width


class GeometryTests(unittest.TestCase):
    def test_width(self):
        self.assertAlmostEqual(width(.4, 75), .6138615903831683)
        self.assertAlmostEqual(width(.4, 60), .8 / math.sqrt(3))
        for angle in (180, 200, 360, 0):
            with self.assertRaises(ValueError):
                width(.4, angle)

    def test_sector_boundaries_and_orientation(self):
        self.assertTrue(sector((1, 1), (0, 0), 0, 90, 2))
        self.assertFalse(sector((1.01, 1), (0, 0), 0, 90, 2))
        self.assertTrue(sector((1, 0), (0, 0), 90, 20, 2))
        self.assertFalse(sector((0, 3), (0, 0), 0, 180, 2))
        self.assertTrue(sector((1, -.1), (0, 0), 0, 200, 2))

    def test_six_modes(self):
        c = Config(optical_occlusion=False)
        # Bearing 50 deg: beyond normal camera, inside effective fisheye.
        p = (.6, .5)
        for mode in range(6):
            with self.subTest(mode=mode):
                rows, threat, count = evaluate(c, mode, [p])
                self.assertEqual(rows[0]['readable'], mode % 2 == 0)
                self.assertEqual(rows[0]['optical'], mode in (2, 3))
                self.assertEqual(threat, mode >= 2)
                self.assertEqual(rows[0]['readable_but_undetected'], mode == 0)
                self.assertEqual(count, 2 if mode >= 4 else 0)

    def test_body_occlusion_all_modes(self):
        for mode in range(6):
            rows, threat, _ = evaluate(Config(optical_occlusion=True), mode, [(0, .8)])
            self.assertFalse(rows[0]['optical'])
            self.assertTrue(rows[0]['readable'])
            self.assertEqual(threat, mode >= 4)
            self.assertEqual(rows[0]['readable_but_undetected'], mode < 4)

    def test_radar_has_no_identity(self):
        c = Config(radar_x=0, radar_y=.6, optical_occlusion=True)
        rows, threat, targets = evaluate(c, 4, [(0, .8)])
        self.assertEqual(targets, 1)
        self.assertTrue(rows[0]['radar'])
        self.assertFalse(threat)
        self.assertFalse(rows[0]['readable_but_undetected'])
        self.assertTrue(rows[0]['breach'])

    def test_ideal_privacy_subset_and_endpoint(self):
        c = Config(optical_occlusion=False)
        for angle in range(-30, 31):
            p = (.8 * math.sin(math.radians(angle)), .8 * math.cos(math.radians(angle)))
            row = evaluate(c, 1, [p])[0][0]
            self.assertTrue(row['readable'])
            self.assertFalse(row['readable_but_undetected'])
        self.assertFalse(occluded((0, .4), (0, 0), [(0, .4)], .1))
        self.assertTrue(evaluate(Config(optical_occlusion=True), 1, [(0, .8)])[0][0]['breach'])

    def test_visible_center_observers_are_detected_by_default(self):
        for mode in range(6):
            with self.subTest(mode=mode):
                rows, threat, _ = evaluate(Config(), mode, [(0, .8), (.04, 1.2), (-.05, .7)])
                self.assertTrue(all(row['optical'] for row in rows))
                self.assertFalse(any(row['readable_but_undetected'] for row in rows))
                self.assertTrue(threat)

    def test_radar_occlusion_switch(self):
        c = Config(radar_x=0, radar_y=0, radar_occlusion=True, optical_occlusion=True)
        rows, threat, targets = evaluate(c, 4, [(0, .8)])
        self.assertEqual(targets, 1)
        self.assertTrue(rows[0]['readable_but_undetected'])
        self.assertFalse(threat)

    def test_occlusion_segment(self):
        self.assertTrue(occluded((0, 1), (0, 0), [(0, .5)], .1))
        self.assertFalse(occluded((0, 1), (0, 0), [(0, 2)], .1))
        self.assertFalse(occluded((0, 1), (0, 0), [(.2, .5)], .1))

    def test_orientation_and_empty_scene(self):
        c = Config(orientation_deg=90)
        self.assertAlmostEqual(user_position(c)[0], .4)
        self.assertAlmostEqual(user_position(c)[1], 0)
        for mode in range(6):
            self.assertFalse(evaluate(c, mode, [])[1])
        self.assertTrue(evaluate(Config(optical_occlusion=False), 0, [(.1, .5)])[1])

    def test_invalid_config(self):
        with self.assertRaises(ValueError):
            Config(camera_deg=0)
        with self.assertRaises(ValueError):
            Config(distance=-1)


if __name__ == '__main__':
    unittest.main()
