const fs = require('node:fs');
const path = require('node:path');

const BUILD_FILE_WINDOWS = process.argv[2] || 'build/win.sh';

function walk(dir, callback)
{
	const entries = fs.readdirSync(dir, {withFileTypes: true});

	for(const entry of entries)
	{
		const fullPath = path.join(dir, entry.name);

		// Skip .git
		if(entry.name === '.git')
			continue;

		if(fullPath.includes('/custom/patch-common.js') || fullPath.includes('/custom/.github'))
			continue;

		if(entry.isDirectory())
			walk(fullPath, callback);
		else if(entry.isFile())
			callback(fullPath);
	}
}

// Apply replacements to a file
function processFile(filePath, replacements)
{
	const content = fs.readFileSync(filePath, 'utf8');
	let updated = content;

	for(const {search, replace} of replacements)
	{
		updated = updated.replace(search, replace);
	}

	if(updated !== content)
	{
		fs.writeFileSync(filePath, updated, 'utf8');
		console.log(`Updated: ${filePath}`);
	}
}

const replacements = [];

replacements.push(
	{
		search: /cp bin\/\*\.dll lib\//g,
		replace: `cp bin/*.dll lib/
for modules_dir in bin/vips-modules-*; do
  [ -d "$modules_dir" ] || continue
  mkdir -p "lib/$(basename "$modules_dir")"
  cp "$modules_dir"/*.dll "lib/$(basename "$modules_dir")/"
done`,
	},
	{
		search: /tar czf[\s\S]+?\.md/g,
		replace: `TAR_ARGS=(
  include
  lib/glib-2.0
  lib/libvips.lib
  lib/*.dll
  *.json
  THIRD-PARTY-NOTICES.md
)
for modules_dir in lib/vips-modules-*; do
  [ -d "$modules_dir" ] || continue
  TAR_ARGS+=("$modules_dir")
done
tar czf "/packaging/sharp-libvips-\${PLATFORM}.tar.gz" "\${TAR_ARGS[@]}"`,
	}
);

processFile(BUILD_FILE_WINDOWS, replacements);