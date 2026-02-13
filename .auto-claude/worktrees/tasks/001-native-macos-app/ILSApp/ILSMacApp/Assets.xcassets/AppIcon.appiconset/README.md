# ILS macOS App Icon Setup

This directory contains the app icon asset catalog for the ILS macOS application.

## Current Status

The asset catalog structure is properly configured with `Contents.json` defining all required macOS icon sizes. However, **actual icon image files need to be added** to complete the setup.

## Required Icon Sizes

The following PNG files need to be created and added to this directory:

| Filename | Dimensions | Usage |
|----------|------------|-------|
| icon_16x16.png | 16×16px | Small icons (Finder, Dock at small sizes) |
| icon_16x16@2x.png | 32×32px | Retina display @ 16pt |
| icon_32x32.png | 32×32px | Medium icons |
| icon_32x32@2x.png | 64×64px | Retina display @ 32pt |
| icon_128x128.png | 128×128px | Larger icons |
| icon_128x128@2x.png | 256×256px | Retina display @ 128pt |
| icon_256x256.png | 256×256px | Very large icons |
| icon_256x256@2x.png | 512×512px | Retina display @ 256pt |
| icon_512x512.png | 512×512px | Extra large icons |
| icon_512x512@2x.png | 1024×1024px | Retina display @ 512pt |

## Icon Design Guidelines

### macOS Big Sur and Later

- **Shape**: Square with rounded corners (macOS automatically applies the rounded rect mask)
- **Background**: Can be transparent or solid color
- **Style**: Follow macOS Big Sur icon design guidelines with:
  - Subtle gradients
  - Depth and dimension
  - Clean, recognizable design at all sizes
  - Consistent with macOS visual language

### Design Recommendations

1. **Simplicity**: Keep the design simple enough to be recognizable at 16×16px
2. **Color**: Use a distinctive color scheme that stands out in the Dock
3. **Branding**: Incorporate ILS branding elements
4. **Testing**: Test at all sizes to ensure clarity and recognizability

### Tools for Creating Icons

- **Sketch** or **Figma**: Design at 1024×1024px, then export all sizes
- **Icon Composer** (part of Xcode): Legacy tool for icon creation
- **SF Symbols**: For incorporating system symbols
- **Preview/Pixelmator**: For basic editing and resizing

## Adding Icons to Xcode

1. Design your icons at all required sizes
2. Replace the placeholder files in this directory with your actual icon files
3. Ensure filenames exactly match those specified in `Contents.json`
4. Xcode will automatically detect and use the new icons
5. Build and run the app to verify the icon appears in the Dock

## Placeholder Status

Currently, this directory contains:
- ✅ `Contents.json` - Properly configured for macOS app icons
- ⚠️ Icon PNG files - **Need to be added by designer**

The app will build successfully with the current setup, but will use a default app icon until actual icon files are provided.
