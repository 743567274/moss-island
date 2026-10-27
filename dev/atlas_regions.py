"""Read transparent sheet regions without changing original image pixels."""
from PIL import Image


def crop_regions(path, split, counts=(5, 6)):
    image = Image.open(path)
    mask = image.getchannel('A').point(lambda n: 255 if n > 16 else 0)
    frames = []
    for top, bottom, count in [(0, split, counts[0]), (split, image.height, counts[1])]:
        strip = mask.crop((0, top, image.width, bottom))
        gaps, start = [], None
        for x in range(image.width + 1):
            empty = x < image.width and strip.crop((x, 0, x + 1, strip.height)).getbbox() is None
            if empty and start is None:
                start = x
            elif not empty and start is not None:
                if x - start > 6:
                    gaps.append((start + x) // 2)
                start = None
        edges = [0]
        for i in range(1, count):
            expected = image.width * i / count
            candidates = [x for x in gaps if x > edges[-1] and abs(x - expected) < image.width / count * .45]
            if not candidates:
                raise ValueError(f'No transparent separator: {path}, row {top}, column {i}')
            edges.append(min(candidates, key=lambda x: abs(x - expected)))
        edges.append(image.width)
        for left, right in zip(edges, edges[1:]):
            x0, y0, x1, y1 = mask.crop((left, top, right, bottom)).getbbox()
            x0, y0 = max(left, left + x0 - 2), max(top, top + y0 - 2)
            x1, y1 = min(right, left + x1 + 2), min(bottom, top + y1 + 2)
            frames.append([x0/image.width, y0/image.height, (x1-x0)/image.width, (y1-y0)/image.height])
    return frames
