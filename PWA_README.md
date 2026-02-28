# PWA Installation Guide

Your Drive Link Converter is now a **Progressive Web App (PWA)**! 🎉

## What's New

- ✅ Installable on desktop and mobile devices
- ✅ Works offline (cached assets)
- ✅ App-like experience with standalone mode
- ✅ Custom app icon
- ✅ Install prompt for users

## Files Added

```
d/
├── index.html          (updated with PWA meta tags)
├── manifest.json       (app configuration)
├── sw.js               (service worker for offline support)
└── icons/              (app icons in multiple sizes)
    ├── icon-72x72.png
    ├── icon-96x96.png
    ├── icon-128x128.png
    ├── icon-144x144.png
    ├── icon-152x152.png
    ├── icon-192x192.png
    ├── icon-384x384.png
    └── icon-512x512.png
```

## How to Install

### On Desktop (Chrome/Edge)
1. Open the app in your browser
2. Look for the install prompt at the bottom of the screen
3. Click **Install** button
4. Or click the install icon in the address bar (⊕ or ⬇️)

### On Android (Chrome)
1. Open the app in Chrome
2. Tap the menu (⋮) → **Install app**
3. Or use the install prompt that appears

### On iOS (Safari)
1. Open the app in Safari
2. Tap the **Share** button
3. Scroll down and tap **Add to Home Screen**
4. Tap **Add** in the top right corner

## Deployment Requirements

For PWA features to work, the app must be served over:
- **HTTPS** (required for production)
- **localhost** (for development)

### Quick Test Server

```bash
# Using Python 3
python3 -m http.server 8000

# Using Node.js (npx)
npx serve .

# Using PHP
php -S localhost:8000
```

Then open `http://localhost:8000` in your browser.

## Regenerating Icons

If you need to regenerate icons, use:

```bash
cd icons
./generate-icons.sh
```

Requires ImageMagick. Install with:
- macOS: `brew install imagemagick`
- Linux: `sudo apt-get install imagemagick`

## Testing PWA Features

### Chrome DevTools
1. Open DevTools (F12)
2. Go to **Application** tab
3. Check:
   - **Manifest** - View app metadata
   - **Service Workers** - Check registration status
   - **Storage** - View cached assets

### Lighthouse
1. Open DevTools
2. Go to **Lighthouse** tab
3. Select **Progressive Web App**
4. Click **Analyze page load**

## Features

- **Offline Support**: App loads even without internet
- **Install Prompt**: Users get a native-like install experience
- **Theme Color**: Matches app chrome to your design
- **Standalone Mode**: Opens like a native app (no browser UI)
- **Responsive**: Works on all screen sizes

## Troubleshooting

### Install prompt not showing?
- Ensure you're on HTTPS or localhost
- Check browser console for service worker errors
- Clear browser cache and reload

### App not working offline?
- Service worker may not be registered
- Check DevTools → Application → Service Workers
- Ensure all assets are cached properly

### Icons not displaying?
- Verify icon paths in manifest.json
- Check that icons exist in the icons/ folder
- Ensure proper file permissions

---

**Enjoy your installable PWA!** 🚀
