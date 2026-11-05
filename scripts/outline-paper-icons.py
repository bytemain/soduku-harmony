#!/usr/bin/env python3
"""Convert source SVG strokes to filled contours for ArkUI Image.fillColor.

Run with Python packages skia-python and fonttools. These are authoring tools,
not application dependencies. Source vectors stay under assets/brand.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

import skia
from fontTools.pens.basePen import BasePen
from fontTools.svgLib.path import parse_path


class SkiaPen(BasePen):
    def __init__(self):
        super().__init__(None)
        self.path = skia.Path()

    def _moveTo(self, point):
        self.path.moveTo(*point)

    def _lineTo(self, point):
        self.path.lineTo(*point)

    def _curveToOne(self, a, b, c):
        self.path.cubicTo(*a, *b, *c)

    def _qCurveToOne(self, a, b):
        self.path.quadTo(*a, *b)

    def _closePath(self):
        self.path.close()

    def _endPath(self):
        pass


def shape_path(element):
    kind = element.tag.rsplit('}', 1)[-1]
    if kind == 'path':
        pen = SkiaPen()
        parse_path(element.attrib['d'], pen)
        return pen.path
    path = skia.Path()
    if kind == 'circle':
        path.addCircle(float(element.get('cx', 0)), float(element.get('cy', 0)),
                       float(element.attrib['r']))
    elif kind == 'rect':
        rect = skia.Rect.MakeXYWH(float(element.get('x', 0)), float(element.get('y', 0)),
                                 float(element.attrib['width']), float(element.attrib['height']))
        rx = float(element.get('rx', 0))
        ry = float(element.get('ry', rx))
        path.addRoundRect(rect, rx, ry)
    else:
        raise ValueError(f'Unsupported source shape: {kind}')
    return path


def outline_svg(source):
    root = ET.fromstring(source)
    stream = skia.DynamicMemoryWStream()
    canvas = skia.SVGCanvas.Make(skia.Rect.MakeWH(24, 24), stream)
    fill_paint = skia.Paint(Color=skia.ColorBLACK, Style=skia.Paint.kFill_Style)
    for element in root:
        path = shape_path(element)
        fill = element.get('fill', root.get('fill', '#000'))
        if fill != 'none':
            canvas.drawPath(path, fill_paint)
        stroke = element.get('stroke', root.get('stroke', 'none'))
        if stroke != 'none':
            width = float(element.get('stroke-width', root.get('stroke-width', 1)))
            stroke_paint = skia.Paint(Style=skia.Paint.kStroke_Style, StrokeWidth=width,
                                     StrokeCap=skia.Paint.kRound_Cap,
                                     StrokeJoin=skia.Paint.kRound_Join)
            outline = skia.Path()
            if not stroke_paint.getFillPath(path, outline, resScale=4):
                raise ValueError('A filled outline could not be generated')
            canvas.drawPath(outline, fill_paint)
    del canvas
    output = bytes(stream.detachAsData())
    parsed = ET.fromstring(output)
    for element in parsed.iter():
        if element.get('stroke') not in (None, 'none') or element.get('fill') == 'none':
            raise ValueError('Runtime asset must contain only filled outlines')
    return output


def main():
    repo = Path(__file__).resolve().parents[1]
    source_dir = repo / 'assets/brand/paper-icons-source'
    output_dir = repo / 'entry/src/main/resources/base/media'
    sources = sorted(source_dir.glob('paper_*.svg'))
    for source in sources:
        output = outline_svg(source.read_bytes())
        (output_dir / source.name).write_bytes(output)
    print(f'Outlined {len(sources)} SVG icons; no runtime strokes remain.')


if __name__ == '__main__':
    main()
