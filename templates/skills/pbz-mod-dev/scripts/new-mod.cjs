'use strict';

const fs = require('node:fs');
const path = require('node:path');

function main([id, destination, suppliedTemplate, ...extra]) {
    if (!id || !destination || extra.length) {
        throw new Error('Usage: node new-mod.cjs <mod-id> <new-project-dir> [template-dir]');
    }
    if (!/^[a-z0-9_-]+$/i.test(id) || /^(con|prn|aux|nul|com[1-9]|lpt[1-9])$/i.test(id)) {
        throw new Error('Choose a portable MOD ID using ASCII letters, digits, underscores or hyphens.');
    }

    const bundled = path.resolve(__dirname, '../assets/ts-mod');
    const template = fs.realpathSync(suppliedTemplate ?? (fs.existsSync(bundled)
        ? bundled : path.resolve(__dirname, '../../../../templates/ts-mod')));
    const resolved = path.resolve(destination);
    const target = path.join(fs.realpathSync(path.dirname(resolved)), path.basename(resolved));
    const relative = path.relative(template, target);
    if (!relative || (relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative))) {
        throw new Error('Create the MOD project outside the source template.');
    }

    const config = JSON.parse(fs.readFileSync(path.join(template, 'tsconfig.json'), 'utf8'));
    const entry = fs.readFileSync(path.join(template, 'src/main.ts'), 'utf8');
    const sampleId = /^(const MOD_ID = )(['"])my-mod\2;/m;
    if (!config.compilerOptions || !sampleId.test(entry) ||
        !fs.existsSync(path.join(template, 'package-lock.json')) ||
        !fs.existsSync(path.join(template, 'vendor/game-api/index.d.ts'))) {
        throw new Error('Expected an intact PBZ TypeScript MOD template with its bundled SDK.');
    }
    config.compilerOptions.outDir = `dist/${id}`;

    fs.mkdirSync(target); // Refuse any existing destination, including an empty directory.
    const excluded = new Set(['.git', 'node_modules', 'dist']);
    fs.cpSync(template, target, {
        recursive: true,
        filter: source => source === template || !excluded.has(path.basename(source))
    });
    fs.writeFileSync(path.join(target, 'tsconfig.json'), `${JSON.stringify(config, null, 2)}\n`);
    fs.writeFileSync(path.join(target, 'src/main.ts'), entry.replace(sampleId, (_, prefix, quote) => `${prefix}${quote}${id}${quote};`));
    console.log(`Created ${target}; build output: dist/${id}/main.js`);
}

try {
    main(process.argv.slice(2));
} catch (error) {
    console.error(error.message);
    process.exitCode = 1;
}
