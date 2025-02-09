# Generate SVG that shows the current package version, build status, and the latest version
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET
from xml.etree.ElementTree import ElementTree, Element

from typing import List, Dict

TEMPLATE_FILE = Path(__file__).parent.joinpath("packaging-status-template.svg")
PACKAGES_DIR = Path(__file__).parent.parent.joinpath("packages")

HEADER_HEIGHT = 45
PACKAGE_HEIGHT = 20
ALL_PACKAGE_STATUS = {}

BACKGROUND_X_BASELINE = 236
BACKGROUND_X_OFFSET = 80
BACKGROUND_Y_BASELINE = 25
BACKGROUND_WIDTH = 80
BACKGROUND_HEIGHT = 20

TEXT_X_BASELINE = 231
TEXT_Y_BASELINE = 36
TEXT_X_OFFSETS = [45, 80, 80]

STATUS_KEYS = ["package_name", "current_version", "build_status", "latest_version"]

def find_packages():
    packages = [x.name for x in PACKAGES_DIR.iterdir() if x.is_dir()]
    return packages

def get_package_status(package: str) -> Dict[str, str]:
    return {
        "package_name": package,
        "current_version": "9.3.0",
        "build_status": "succeeded",
        "latest_version": "9.5.0",
    }

def load_svg(svg_file: Path):
    tree = ET.parse(svg_file)
    return tree

def update_svg_header(svg: ElementTree, packages: List[str]):
    root = svg.getroot()
    height = HEADER_HEIGHT + PACKAGE_HEIGHT * (len(packages) - 1)
    root.set('height', str(height))

def find_first_g_element(root: Element) -> Element | None:
    """Finds and returns the first <g> element in the SVG."""
    namespace = {'svg': 'http://www.w3.org/2000/svg'}  # Define namespace
    return root.find('.//svg:g', namespace)  # Finds the first <g> element

def add_package_name_version(g: Element, y_offset: int, status: Dict[str, str]):
    def _add_text_element(x_offset, y_offset, text_anchor, fill, fill_opacity, text):
        text_element = ET.Element('text', {
            'x': str(x_offset),
            'y': str(y_offset),
            'text-anchor': text_anchor,
            'dominant-baseline': 'central',
            'fill': fill,
            'fill-opacity': str(fill_opacity),
        })
        text_element.text = text
        g.append(text_element)
        text_element_2 = ET.Element('text', {
            'x': str(x_offset),
            'y': str(y_offset - 1),
            'text-anchor': text_anchor,
            'dominant-baseline': 'central',
        })
        text_element_2.text = text
        g.append(text_element_2)
    for offset, key in enumerate(STATUS_KEYS):
        x_offset = TEXT_X_BASELINE + sum(TEXT_X_OFFSETS[:offset])
        text_anchor = 'end' if offset == 0 else 'middle'
        fill = '#010101'
        fill_opacity = 0.3
        text = status[key]
        _add_text_element(x_offset, y_offset, text_anchor, fill, fill_opacity, text)

def add_package_background(g: Element, y_offset: int, status: Dict[str, str]):
    def _add_element_rect(x, y, width, height, fill):
        rect = ET.Element('rect', {
            'x': str(x),
            'y': str(y),
            'width': str(width),
            'height': str(height),
            'fill': fill,
        })
        g.append(rect)
    for id, _column in enumerate(STATUS_KEYS[1:]):
        x = BACKGROUND_X_BASELINE + id * BACKGROUND_X_OFFSET
        y = y_offset
        if id == 0:
            current_version = status["current_version"]
            latest_version = status["latest_version"]
            fill = "#e05d44" if not current_version == latest_version else "#4c1"
        elif id == 1:
            build_status = status["build_status"]
            fill = "#e05d44" if not build_status == "succeeded" else "#4c1"
        else:
            fill = "#4c1"
        _add_element_rect(x, y, BACKGROUND_WIDTH, BACKGROUND_HEIGHT, fill)
        _add_element_rect(x, y, "100%", BACKGROUND_HEIGHT, fill="url(#grad)")

def add_g_element(first_g: Element) -> Element:
    child_g = ET.Element('g', {
        'fill': '#fff',
        'font-family': 'DejaVu Sans,Verdana,Geneva,sans-serif',
        'font-size': '11',
    })
    first_g.append(child_g)
    return child_g

def save_svg(tree: ElementTree, output_path: str) -> None:
    """Saves the modified SVG file in human-readable format with indentation."""
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    # tree.write(output_path, encoding='utf-8', xml_declaration=True)
    import xml.dom.minidom as minidom
    xml_str = ET.tostring(tree.getroot(), encoding='utf-8')
    parsed_xml = minidom.parseString(xml_str)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(parsed_xml.toprettyxml(indent="    "))  # Indent with 4 spaces

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, help="Output file path.")
    args = parser.parse_args()
    svg_tree = load_svg(TEMPLATE_FILE)
    packages = find_packages()
    # update the header
    update_svg_header(svg_tree, packages)
    first_g = find_first_g_element(svg_tree.getroot())
    for offset, package in enumerate(packages):
        y_offset = BACKGROUND_Y_BASELINE + offset * BACKGROUND_HEIGHT
        status = get_package_status(package)
        ALL_PACKAGE_STATUS[package] = status
        add_package_background(first_g, y_offset, status)
    for offset, package in enumerate(packages):
        y_offset = TEXT_Y_BASELINE + offset * PACKAGE_HEIGHT
        child_g = add_g_element(first_g)
        status = ALL_PACKAGE_STATUS[package]
        add_package_name_version(
            child_g,
            y_offset,
            status,
        )
    save_svg(svg_tree, args.output)
