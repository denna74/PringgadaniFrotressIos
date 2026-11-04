import re
import struct
from pathlib import Path


MODEL_ROOT = Path("assets/models")
STAND_TEXTURE = MODEL_ROOT / "gatotkaca_stand_texture_0.png"
STANDARD_SIZE_LIMIT = 512
STAND_SIZE_LIMIT = 1024
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
JPEG_SOF_MARKERS = {
    0xC0,
    0xC1,
    0xC2,
    0xC3,
    0xC5,
    0xC6,
    0xC7,
    0xC9,
    0xCA,
    0xCB,
    0xCD,
    0xCE,
    0xCF,
}


def image_dimensions(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as image:
        header = image.read(24)
        if header.startswith(PNG_SIGNATURE) and len(header) >= 24:
            return struct.unpack(">II", header[16:24])
        if not header.startswith(b"\xff\xd8"):
            return None

        image.seek(2)
        while True:
            marker_start = image.read(1)
            if marker_start != b"\xff":
                return None
            marker_byte = image.read(1)
            while marker_byte == b"\xff":
                marker_byte = image.read(1)
            if not marker_byte:
                return None
            marker = marker_byte[0]
            if marker in {0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
                continue
            length_bytes = image.read(2)
            if len(length_bytes) != 2:
                return None
            segment_length = int.from_bytes(length_bytes, "big")
            if marker in JPEG_SOF_MARKERS:
                dimensions = image.read(5)
                if len(dimensions) == 5:
                    height, width = struct.unpack(">HH", dimensions[1:5])
                    return width, height
                return None
            if segment_length < 2:
                return None
            image.seek(segment_length - 2, 1)
    return None


def configure_import(import_path: Path) -> bool:
    contents = import_path.read_text()
    if 'importer="texture"' not in contents:
        return False

    source_path = import_path.with_suffix("")
    dimensions = image_dimensions(source_path)
    if dimensions is None:
        return False

    size_limit = STAND_SIZE_LIMIT if source_path == STAND_TEXTURE else STANDARD_SIZE_LIMIT
    if max(dimensions) <= size_limit:
        return False

    updated = re.sub(r'"vram_texture":\s*false', '"vram_texture": true', contents, count=1)
    updated = re.sub(r"^compress/mode=\d+$", "compress/mode=2", updated, count=1, flags=re.MULTILINE)
    updated = re.sub(
        r"^process/size_limit=\d+$",
        f"process/size_limit={size_limit}",
        updated,
        count=1,
        flags=re.MULTILINE,
    )
    if updated != contents:
        import_path.write_text(updated)
        return True
    return False


if __name__ == "__main__":
    changed = sum(configure_import(path) for path in MODEL_ROOT.rglob("*.import"))
    print(f"Configured {changed} oversized model texture import(s) for mobile caps.")
