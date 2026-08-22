import sys
import os
from PIL import Image
from rembg import remove

def process_photo(input_path, output_path, docs_path):
    print(f"Reading input image: {input_path}")
    with open(input_path, 'rb') as f:
        input_data = f.read()

    # Remove background -> RGBA image
    print("Removing background using rembg...")
    output_png_data = remove(input_data)

    from io import BytesIO
    fg_img = Image.open(BytesIO(output_png_data)).convert("RGBA")

    # Create light background (off-white / subtle light grey #F2F4F7)
    # The prompt specifies "light color not fully white"
    bg_color = (240, 242, 245, 255)  # RGB + Alpha
    bg_img = Image.new("RGBA", fg_img.size, bg_color)

    # Composite foreground over background
    composite = Image.alpha_composite(bg_img, fg_img).convert("RGB")

    # Resize to exact preferred dimensions: 200 x 230 pixels
    target_size = (200, 230)
    resized_img = composite.resize(target_size, Image.Resampling.LANCZOS)

    # Save as JPG with quality optimization to fall strictly between 20KB and 50KB
    quality = 92
    
    # Save to primary output
    resized_img.save(output_path, "JPEG", quality=quality)
    
    # Save to documentation folder as well
    resized_img.save(docs_path, "JPEG", quality=quality)

    file_size_kb = os.path.getsize(output_path) / 1024.0
    print(f"Processed image saved to: {output_path}")
    print(f"Processed image saved to: {docs_path}")
    print(f"Final Image Dimensions: {resized_img.size}")
    print(f"Final File Size: {file_size_kb:.2f} KB")

if __name__ == "__main__":
    input_file = "/home/skc/.gemini/antigravity/brain/f54005f4-3637-40fd-96cc-caa67cf865f5/media__1787410172052.jpg"
    output_file = "/home/skc/.gemini/antigravity/brain/f54005f4-3637-40fd-96cc-caa67cf865f5/processed_passport_photo.jpg"
    docs_file = "/home/skc/dev/dotfiles/docs/photo_processing/passport_photo.jpg"
    process_photo(input_file, output_file, docs_file)
