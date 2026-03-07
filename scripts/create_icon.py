"""
Generate kb_guardian/icon.ico without any external dependencies.
Produces a 32x32 BGRA ICO: steel-blue background with a white "K" glyph.
"""
import struct
from pathlib import Path


def _make_32x32_pixels() -> list[tuple[int, int, int, int]]:
    W = H = 32
    BG = (180, 120, 46, 255)   # BGRA for RGB(46, 120, 180) steel-blue
    FG = (255, 255, 255, 255)  # white

    px = [BG] * (W * H)

    def dot(r: int, c: int) -> None:
        if 0 <= r < H and 0 <= c < W:
            px[r * W + c] = FG

    # Vertical bar of "K"  (cols 8-10, rows 5-26)
    for r in range(5, 27):
        for c in range(8, 11):
            dot(r, c)

    # Upper arm of "K" (diagonal from row 5 to 15, leaning right)
    for i in range(11):
        r = 5 + i
        c = 11 + i
        for dc in range(2):
            dot(r, c + dc)

    # Lower arm of "K" (diagonal from row 16 to 26, leaning right)
    for i in range(11):
        r = 16 + i
        c = 21 - i
        for dc in range(2):
            dot(r, c + dc)

    return px


def _encode_ico(pixels: list[tuple[int, int, int, int]]) -> bytes:
    W = H = 32

    # Pixel data is bottom-up in BMP
    rows_bgra: list[int] = []
    for row in range(H - 1, -1, -1):
        for col in range(W):
            rows_bgra.extend(pixels[row * W + col])
    pixel_data = bytes(rows_bgra)

    # AND mask: all 0 (fully opaque), padded to 4-byte row boundary
    row_stride = (W + 31) // 32 * 4
    and_mask = bytes(row_stride * H)

    # BITMAPINFOHEADER (40 bytes)
    bih = struct.pack(
        "<IIIHHIIIIII",
        40,       # biSize
        W,        # biWidth
        H * 2,    # biHeight (XOR + AND stacked)
        1,        # biPlanes
        32,       # biBitCount
        0, 0, 0, 0, 0, 0,
    )

    image_data = bih + pixel_data + and_mask

    # ICONDIR (6 bytes)
    icondir = struct.pack("<HHH", 0, 1, 1)

    # ICONDIRENTRY (16 bytes)
    offset = 6 + 16
    entry = struct.pack(
        "<BBBBHHII",
        W, H,
        0, 0,          # bColorCount, bReserved
        1,             # wPlanes
        32,            # wBitCount
        len(image_data),
        offset,
    )

    return icondir + entry + image_data


def main() -> None:
    pixels = _make_32x32_pixels()
    ico_bytes = _encode_ico(pixels)
    out = Path(__file__).resolve().parents[1] / "kb_guardian" / "icon.ico"
    out.write_bytes(ico_bytes)
    print(f"icon.ico written → {out}")


if __name__ == "__main__":
    main()
