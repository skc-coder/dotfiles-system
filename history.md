# Project Change & Task History

## [2026-08-22] Document Photo Processing & Scan Guidelines

### User Request
- Process candidate photograph to remove dark background, replace with a soft light off-white tone (not full white).
- Save image in documentation meeting standard online application document upload requirements.
- Document full scan and upload guidelines for Photograph, Signature, and Left Thumb Impression.

### Implementation Summary
1. **Photo Processing**:
   - Extracted subject using GrabCut edge blending.
   - Replaced background with a clean light off-white/light gray tone (`#F0F2F5`).
   - Resized image to `200 x 230` pixels.
   - Encoded JPEG at optimized quality to obtain `32.79 KB` (strictly inside the `20KB - 50KB` limit).
   - Saved output to [/home/skc/dev/dotfiles/docs/photo_processing/passport_photo.jpg](file:///home/skc/dev/dotfiles/docs/photo_processing/passport_photo.jpg).

2. **Documentation**:
   - Created [/home/skc/dev/dotfiles/docs/photo_processing/README.md](file:///home/skc/dev/dotfiles/docs/photo_processing/README.md) detailing all parameters for Photo (200x230, 20-50KB), Signature (140x60, 10-20KB), and Left Thumb Impression (240x240, 20-50KB, 200 DPI).

3. **Automation Scripts**:
   - Maintained Python script at [/home/skc/dev/dotfiles/docs/photo_processing/fast_process.py](file:///home/skc/dev/dotfiles/docs/photo_processing/fast_process.py) for reproducible batch runs.
