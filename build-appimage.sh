#!/bin/bash
set -euo pipefail
cd ~/FreeTube

echo "===== STEP 1: Check current package.json fields ====="
node -e "const pkg = require('./package.json'); console.log('  name:', pkg.name); console.log('  productName:', pkg.productName); console.log('  version:', pkg.version)"

echo ""
echo "===== STEP 2: Modify package.json ====="
node -e "
const fs = require('fs')
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'))
console.log('  Before: name=' + pkg.name + ', productName=' + pkg.productName)
pkg.name = 'freetube-discover'
pkg.productName = 'FreeTube Discover'
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n')
console.log('  After:  name=' + pkg.name + ', productName=' + pkg.productName)
"

echo ""
echo "===== STEP 3: Create AppImage-only build script ====="
cat > _scripts/build-appimage.mjs << 'EOF'
import { Arch, build, Platform } from 'electron-builder'
import config from './ebuilder.config.mjs'

const targets = Platform.LINUX.createTarget(['AppImage'], Arch.x64)

const output = await build({ targets, config, publish: 'never' })
console.log(output)
EOF
echo "  ✓ Created _scripts/build-appimage.mjs"

echo ""
echo "===== STEP 4: Run webpack pack ====="
echo "  Compiling main, renderer, preload, and botGuardScript..."
echo "  This may take 2-5 minutes..."
pnpm run pack

echo ""
echo "===== STEP 5: Build AppImage ====="
echo "  Packaging into AppImage..."
echo "  This may take 1-2 minutes..."
node _scripts/build-appimage.mjs

echo ""
echo "===== STEP 6: Verify output ====="
echo "--- AppImage files ---"
ls -lh build/*.AppImage 2>/dev/null || echo "  No AppImage found in build/"
echo ""
echo "--- All build output ---"
ls -lh build/ 2>/dev/null

echo ""
echo "===== STEP 7: Disk space ====="
df -h ~

echo ""
echo "===== DONE ====="
echo ""
echo "To copy to your Arch system:"
echo "  scp build/FreeTube\\ Discover-*.AppImage user@arch-host:~/"
echo ""
echo "Then on Arch:"
echo "  chmod +x 'FreeTube Discover-*.AppImage'"
echo "  ./'FreeTube Discover-*.AppImage'"
echo ""
echo "Config directory: ~/.config/freetube-discover/"
echo "This is separate from your pacman FreeTube's ~/.config/FreeTube/"
echo ""
echo "Note: If Arch doesn't have fuse2 installed, run:"
echo "  sudo pacman -S fuse2"
echo "  Or run with: ./'FreeTube Discover-*.AppImage' --appimage-extract-and-run"
