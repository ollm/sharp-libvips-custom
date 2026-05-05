# Custom Sharp Build

`sharp-custom` and `sharp-libvips-custom` (`@img-custom`) are prebuilt Sharp binaries with built-in support for `HEIF/HEIC`, `JP2`, and `JXL` (WASM builds are not available).

> `JXL` is not available on `linux-s390x`, `linux-riscv64`, and `linux-armv6` due to lack of Highway SIMD support.

These builds also enable `AV1_HIGHBITDEPTH`, allowing decoding of 10/12-bit AVIF images.

> [!WARNING]
> Use the official Sharp binaries unless you specifically need these features.

## Usage

Add the following `overrides` to your `package.json`, making sure the versions match those of your installed `sharp` and `sharp-libvips`.

```bash
npm install
```

In some cases, you may need to remove `node_modules` and `package-lock.json` for the overrides to take effect.

```bash
rm -rf node_modules package-lock.json
npm install
```

### Overrides

```json
{
	"overrides": {
		"sharp": {
			"@img/sharp-darwin-arm64": "npm:@img-custom/sharp-darwin-arm64@0.11.0",
			"@img/sharp-darwin-x64": "npm:@img-custom/sharp-darwin-x64@0.11.0",
			"@img/sharp-linux-arm": "npm:@img-custom/sharp-linux-arm@0.11.0",
			"@img/sharp-linux-arm64": "npm:@img-custom/sharp-linux-arm64@0.11.0",
			"@img/sharp-linux-ppc64": "npm:@img-custom/sharp-linux-ppc64@0.11.0",
			"@img/sharp-linux-riscv64": "npm:@img-custom/sharp-linux-riscv64@0.11.0",
			"@img/sharp-linux-s390x": "npm:@img-custom/sharp-linux-s390x@0.11.0",
			"@img/sharp-linux-x64": "npm:@img-custom/sharp-linux-x64@0.11.0",
			"@img/sharp-linuxmusl-arm64": "npm:@img-custom/sharp-linuxmusl-arm64@0.11.0",
			"@img/sharp-linuxmusl-x64": "npm:@img-custom/sharp-linuxmusl-x64@0.11.0",
			"@img/sharp-win32-arm64": "npm:@img-custom/sharp-win32-arm64@0.11.0",
			"@img/sharp-win32-ia32": "npm:@img-custom/sharp-win32-ia32@0.11.0",
			"@img/sharp-win32-x64": "npm:@img-custom/sharp-win32-x64@0.11.0",

			"@img/sharp-libvips-darwin-arm64": "npm:@img-custom/sharp-libvips-darwin-arm64@1.3.0-rc.5",
			"@img/sharp-libvips-darwin-x64": "npm:@img-custom/sharp-libvips-darwin-x64@1.3.0-rc.5",
			"@img/sharp-libvips-linux-arm": "npm:@img-custom/sharp-libvips-linux-arm@1.3.0-rc.5",
			"@img/sharp-libvips-linux-arm64": "npm:@img-custom/sharp-libvips-linux-arm64@1.3.0-rc.5",
			"@img/sharp-libvips-linux-ppc64": "npm:@img-custom/sharp-libvips-linux-ppc64@1.3.0-rc.5",
			"@img/sharp-libvips-linux-riscv64": "npm:@img-custom/sharp-libvips-linux-riscv64@1.3.0-rc.5",
			"@img/sharp-libvips-linux-s390x": "npm:@img-custom/sharp-libvips-linux-s390x@1.3.0-rc.5",
			"@img/sharp-libvips-linux-x64": "npm:@img-custom/sharp-libvips-linux-x64@1.3.0-rc.5",
			"@img/sharp-libvips-linuxmusl-arm64": "npm:@img-custom/sharp-libvips-linuxmusl-arm64@1.3.0-rc.5",
			"@img/sharp-libvips-linuxmusl-x64": "npm:@img-custom/sharp-libvips-linuxmusl-x64@1.3.0-rc.5",
			"@img/sharp-libvips-win32-arm64": "npm:@img-custom/sharp-libvips-win32-arm64@1.3.0-rc.5",
			"@img/sharp-libvips-win32-ia32": "npm:@img-custom/sharp-libvips-win32-ia32@1.3.0-rc.5",
			"@img/sharp-libvips-win32-x64": "npm:@img-custom/sharp-libvips-win32-x64@1.3.0-rc.5"
		}
	}
}
```