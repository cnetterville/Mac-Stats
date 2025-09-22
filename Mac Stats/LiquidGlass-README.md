# Liquid Glass Support for Mac Stats

This implementation adds modern liquid glass visual effects to your Mac Stats app, providing a beautiful translucent, blurred background appearance similar to modern macOS apps.

## Features

### Automatic System Detection
- Detects macOS version and applies appropriate effects
- macOS Big Sur (11.0+): Advanced materials
- macOS Monterey (12.0+): Enhanced blur effects
- macOS Ventura (13.0+): Ultra-thin materials
- Older systems: Graceful fallback

### Glass Materials
- **Ultra Thin**: Very subtle effect
- **Thin**: Light translucency
- **Regular**: Balanced appearance (default)
- **Thick**: More pronounced effect
- **Ultra Thick**: Maximum translucency
- **Specialized**: Sidebar, Menu, Popover, Header, Sheet

### Enhanced Components
- `EnhancedCardView`: Replaces CardView with glass effects
- `EnhancedCardHeaderView`: Glass-enhanced headers
- `GlassButton`: Interactive buttons with glass styling
- `GlassProgressView`: Progress bars with glass effects
- `GlassSparklineView`: Charts with enhanced visuals

## Usage

### Basic Glass Card