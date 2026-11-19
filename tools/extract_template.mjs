#!/usr/bin/env node
// tools/extract_template.mjs
// ─────────────────────────────────────────────────────────────────────────────
// Codemod: extrae la plantilla inline (`template: `...``) de un componente Vue
// grande a su propio módulo `components/templates/<Nombre>Template.js` y deja en
// el componente `template: TEMPLATE` + el import correspondiente.
//
// Objetivo: que editar la LÓGICA de un componente
// monolítico no obligue a cargar los ~KB de su plantilla (y viceversa). La
// extracción es BYTE-PERFECTA (copia literal, sin reescribir), así que no cambia
// el comportamiento: Vue compila la misma cadena en tiempo de ejecución.
//
// Uso:  node tools/extract_template.mjs editor/js/components/ConfigManager.js
// Idempotente: si ya está extraída (`template: TEMPLATE`), no hace nada.
// ─────────────────────────────────────────────────────────────────────────────
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';

const rel = process.argv[2];
if (!rel) {
	console.error('Uso: node tools/extract_template.mjs <ruta/al/Componente.js>');
	process.exit(2);
}

const src = readFileSync(rel, 'utf8');
const name = basename(rel, '.js');

if (/template:\s*TEMPLATE\b/.test(src)) {
	console.log(`= ${name}: ya extraída, nada que hacer.`);
	process.exit(0);
}

// 1) Localiza el inicio del literal de plantilla: `template: ` seguido de backtick.
const startMatch = src.match(/\btemplate:\s*`/);
if (!startMatch) {
	console.error(`✗ ${name}: no encontré 'template: \`'.`);
	process.exit(1);
}
const openTick = startMatch.index + startMatch[0].length - 1; // índice del backtick de apertura

// 2) Cierre del literal = siguiente backtick (las plantillas Vue no llevan backticks internos).
const closeTick = src.indexOf('`', openTick + 1);
if (closeTick === -1) {
	console.error(`✗ ${name}: literal de plantilla sin cierre.`);
	process.exit(1);
}

// 3) Seguridad: tras el backtick de cierre debe venir ',' y el fin del componente ('};').
const tail = src.slice(closeTick + 1);
if (!/^\s*,\s*};?\s*$/.test(tail)) {
	console.error(`✗ ${name}: la plantilla no es la última propiedad (tras el cierre hay: ${JSON.stringify(tail.slice(0, 40))}). Extrae a mano.`);
	process.exit(1);
}

const inner = src.slice(openTick + 1, closeTick); // contenido EXACTO de la plantilla

// 4) Escribe el módulo de plantilla (copia literal).
const tplDir = join(dirname(rel), 'templates');
if (!existsSync(tplDir)) mkdirSync(tplDir, { recursive: true });
const tplName = `${name}Template.js`;
const tplPath = join(tplDir, tplName);
const header = `// components/templates/${tplName}\n`
	+ `// Plantilla (markup Vue) extraída de ${name}.js.\n`
	+ `// Solo maquetación: NO contiene lógica. La lógica (setup/props/estado) vive en ${name}.js.\n`
	+ `// Regenerable con: node tools/extract_template.mjs editor/js/components/${name}.js\n`;
writeFileSync(tplPath, `${header}export default \`${inner}\`;\n`, 'utf8');

// 5) Sustituye el literal por la referencia TEMPLATE. `slice(0, startMatch.index)`
// conserva todo (incluida la indentación) hasta justo antes de 'template:'; el
// resto del componente tras el literal era solo ",\n};" (validado en el paso 3).
let out = src.slice(0, startMatch.index) + 'template: TEMPLATE,\n};\n';

// 6) Inserta el import tras el último import de nivel superior.
const importRe = /^import .*$/gm;
let lastImportEnd = 0;
let m;
while ((m = importRe.exec(out)) !== null) lastImportEnd = m.index + m[0].length;
const importLine = `\nimport TEMPLATE from './templates/${tplName}';`;
out = out.slice(0, lastImportEnd) + importLine + out.slice(lastImportEnd);

writeFileSync(rel, out, 'utf8');

const kb = (n) => (n / 1024).toFixed(1);
console.log(`✓ ${name}: plantilla → templates/${tplName} (${kb(inner.length)} KB). Componente ahora ${kb(out.length)} KB (antes ${kb(src.length)} KB).`);
