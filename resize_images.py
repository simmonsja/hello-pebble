from PIL import Image
import os

# Process both images
images = ['./blue_pixel/resources/blue_marble.png', './blue_pixel/resources/black_marble.png']

for img_name in images:
    # Open image
    img = Image.open(img_name)
    
    # Get the bounding box of the non-transparent area
    bbox = img.getbbox()
    
    if bbox:
        # Crop to remove transparent space
        img_cropped = img.crop(bbox)
        print(f"{img_name}: Original {img.size}, Cropped to {img_cropped.size}")
        
        # Resize to 144x168 for basalt
        img_resized = img_cropped.resize((144, 168), Image.Resampling.NEAREST)
        
        # Save with _basalt suffix
        output_name = img_name.replace('.png', '_basalt.png')
        img_resized.save(output_name)
        print(f"Saved {output_name} at 144x168")
    else:
        print(f"Could not find bounding box for {img_name}")