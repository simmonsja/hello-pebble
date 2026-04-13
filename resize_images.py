from PIL import Image
import os

# Process both images
images = [
    "./blue_pixel/resources/blue_marble_gabbro.png",
    "./blue_pixel/resources/black_marble_gabbro.png",
]

# # Basalt
# SCREEN_SIZE = (144, 168)
# NAME = "basalt"

# Basalt
SCREEN_SIZE = (200, 228)
NAME = "emery"

for img_name in images:
    # Open image
    img = Image.open(img_name)

    # Get the bounding box of the non-transparent area
    bbox = img.getbbox()

    if bbox:
        img_cropped = img.crop(bbox)
        print(f"{img_name}: Original {img.size}, Cropped to {img_cropped.size}")

        # Scale to fit width, maintaining aspect ratio
        target_w = SCREEN_SIZE[0]
        scale = target_w / img_cropped.width
        scaled_h = round(img_cropped.height * scale)
        img_scaled = img_cropped.resize((target_w, scaled_h), Image.Resampling.NEAREST)

        # Pad top and bottom with transparent pixels to reach full height
        canvas = Image.new("RGBA", SCREEN_SIZE, (0, 0, 0, 0))
        top_offset = (SCREEN_SIZE[1] - scaled_h) // 2
        canvas.paste(img_scaled, (0, top_offset))

        # Save with _basalt suffix
        output_name = img_name.replace("_gabbro.png", f"_{NAME}.png")
        canvas.save(output_name)
        print(
            f"Saved {output_name} at size {canvas.size} (globe at {img_scaled.size}, offset y={top_offset})"
        )
    else:
        print(f"Could not find bounding box for {img_name}")
