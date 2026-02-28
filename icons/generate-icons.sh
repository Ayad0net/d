#!/bin/bash

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick is not installed. Please install it with:"
    echo "  macOS: brew install imagemagick"
    echo "  Linux: sudo apt-get install imagemagick"
    echo "  Or use an online converter for the SVG icon"
    exit 1
fi

cd "$(dirname "$0")"

# Generate PNG icons from SVG
sizes=(72 96 128 144 152 192 384 512)

for size in "${sizes[@]}"; do
    convert -background none -resize "${size}x${size}" icon.svg "icon-${size}x${size}.png"
    echo "Created icon-${size}x${size}.png"
done

echo "All icons generated successfully!"
