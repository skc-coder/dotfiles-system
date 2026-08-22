import cv2
import numpy as np
from PIL import Image
import os

def process_photo_opencv(input_path, output_path, docs_path):
    # Load image
    img = cv2.imread(input_path)
    h, w, c = img.shape

    # GrabCut background segmentation
    mask = np.zeros(img.shape[:2], np.uint8)
    bgdModel = np.zeros((1,65), np.float64)
    fgdModel = np.zeros((1,65), np.float64)

    # Define bounding box around face/head/shoulders
    rect = (int(w*0.05), int(h*0.02), int(w*0.9), int(h*0.96))
    
    cv2.grabCut(img, mask, rect, bgdModel, fgdModel, 5, cv2.GC_INIT_WITH_RECT)
    mask2 = np.where((mask==2)|(mask==0), 0, 1).astype('uint8')
    
    # Smooth edges with Gaussian blur on mask
    mask_blur = cv2.GaussianBlur(mask2.astype(np.float32), (11, 11), 0)
    mask_3d = np.repeat(mask_blur[:, :, np.newaxis], 3, axis=2)

    # Light background (soft light grey/off-white #F0F2F5: BGR 245, 242, 240)
    light_bg = np.full_like(img, (245, 242, 240), dtype=np.uint8)

    # Blend foreground and light background
    final_img = (img * mask_3d + light_bg * (1 - mask_3d)).astype(np.uint8)

    # Convert BGR (OpenCV) to RGB (PIL)
    final_rgb = cv2.cvtColor(final_img, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(final_rgb)

    # Resize to exact specification 200 x 230 pixels
    target_size = (200, 230)
    resized_img = pil_img.resize(target_size, Image.Resampling.LANCZOS)

    # Save with high quality (100) and no subsampling to ensure size is > 20KB and <= 50KB
    quality = 100
    resized_img.save(output_path, "JPEG", quality=quality, subsampling=0)
    resized_img.save(docs_path, "JPEG", quality=quality, subsampling=0)

    file_size_kb = os.path.getsize(output_path) / 1024.0
    print(f"Processed Photo Dimensions: {resized_img.size}")
    print(f"Processed Photo Size: {file_size_kb:.2f} KB")

if __name__ == "__main__":
    input_file = "/home/skc/.gemini/antigravity/brain/f54005f4-3637-40fd-96cc-caa67cf865f5/media__1787410172052.jpg"
    output_file = "/home/skc/.gemini/antigravity/brain/f54005f4-3637-40fd-96cc-caa67cf865f5/processed_passport_photo.jpg"
    docs_file = "/home/skc/dev/dotfiles/docs/photo_processing/passport_photo.jpg"
    process_photo_opencv(input_file, output_file, docs_file)
