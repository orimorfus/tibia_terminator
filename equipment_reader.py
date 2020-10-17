# /usr/bin/env python3

import PIL.Image  # python-imaging
import PIL.ImageStat  # python-imaging
import Xlib.display  # python-xlib
from functools import reduce

AMULET_SPEC = {
    "empty": [
        "3d3f42",
        "434648",
        "252626",
        "232424",
    ]
}

AMULET_COORDS = [
    # upper pixel
    (1768, 259),
    # lower pixel
    (1768, 272),
    # left pixel
    (1758, 261),
    # right pixel
    (1779, 261)
]

RING_SPEC = {
    "empty": [
        "252625",
        "36393c",
        "2e2e2f",
        "3d4042",
    ]
}

RING_COORDS = [
    # upper pixel
    (1768, 333),
    # lower pixel
    (1768, 338),
    # left pixel
    (1765, 337),
    # right pixel
    (1770, 337)
]


# use this to get the color profile of a given amulet (or empty)
def get_pixel_color(x, y):
    screen = Xlib.display.Display().screen().root
    raw_screen_pixels = screen.get_image(
        x, y, 1, 1, Xlib.X.ZPixmap, 0xffffffff)
    rgb_screen_pixels = PIL.Image.frombytes(
        "RGB", (1, 1), raw_screen_pixels.data, "raw", "BGRX")
    rgb_pixel_color = PIL.ImageStat.Stat(rgb_screen_pixels).mean
    return reduce(lambda a, b: a[1:] + b[2:], map(hex, map(int, rgb_pixel_color)))


def is_amulet(name):
    pixels = map(lambda (x, y): get_pixel_color(x, y), AMULET_COORDS)
    for i in range(0, 3):
        if pixels[i] != AMULET_SPEC[name][i]:
            return False
    return True


def is_amulet_empty():
    return is_amulet('empty')


def is_ring(name):
    pixels = map(lambda (x, y): get_pixel_color(x, y), RING_COORDS)
    for i in range(0, 3):
        if pixels[i] != RING_SPEC[name][i]:
            return False
    return True


def is_ring_empty():
    return is_ring('empty')


if __name__ == '__main__':
    import time
    print("Amulet color spec")
    for (x, y) in AMULET_COORDS:
        print(get_pixel_color(x, y))

    print("Ring color spec")
    for (x, y) in RING_COORDS:
        print(get_pixel_color(x, y))

    for name in AMULET_SPEC:
      start_ms = time.time() * 1000
      is_amulet_ = is_amulet(name)
      end_ms = time.time() * 1000
      print("is_amulet('" + name + "'): " + str(is_amulet_))
      print("Elapsed time: " + str(end_ms - start_ms) + " ms")

    for name in RING_SPEC:
      start_ms = time.time() * 1000
      is_ring_ = is_ring(name)
      end_ms = time.time() * 1000
      print("is_ring('" + name + "'): " + str(is_ring_))
      print("Elapsed time: " + str(end_ms - start_ms) + " ms")

