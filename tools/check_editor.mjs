#!/usr/bin/env node
// ============================================================================
// check_editor.mjs  ·  Verificador estático del editor (SPA Vue 3)
// ----------------------------------------------------------------------------
// HERRAMIENTA PERMANENTE. Da a un agente (o a un humano) una forma ESTÁNDAR y
// rápida de comprobar que un cambio en `editor/` no ha roto lo básico, SIN
// necesidad de arrancar el navegador. Comprueba tres cosas:
//
//   1) SINTAXIS: `node --check` de todos los `editor/**/*.js` (y este .mjs).
//   2) IMPORTS: cada import relativo (`./`, `../`) resuelve a un fichero real
//      (detecta refactors que dejan imports colgando). Los imports de CDN
//      (https://) se ignoran a propósito.
//   3) COBERTURA DE PESTAÑAS: cada tab de `nav.js` (TAB_META) aparece en el
//      render de `app.js` (evita "registré el componente pero no lo pinté").
//
// Uso:   node tools/check_editor.mjs
// Salida: lista de errores + código de salida != 0 si algo falla (CI-friendly).
// ============================================================================

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve, relative } from 'node:path';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const EDITOR = join(ROOT, 'editor');
const JS_DIR = join(EDITOR, 'js');

const errors = [];
const warnings = [];

/** Lista recursiva de ficheros con una extensión dada. */
function walk(dir, ext, out = []) {
	for (const name of readdirSync(dir)) {
		// js/vendor/ contiene dependencias de terceros vendorizadas (Vue): ni se
		// comprueba su sintaxis ni sus imports (no son código del editor).
		if (name === 'vendor') continue;
		const full = join(dir, name);
		const st = statSync(full);
		if (st.isDirectory()) walk(full, ext, out);
		else if (full.endsWith(ext)) out.push(full);
	}
	return out;
}

const rel = (p) => relative(ROOT, p).replace(/\\/g, '/');

// ── 1) Sintaxis: node --check de cada .js ────────────────────────────────────
const jsFiles = existsSync(JS_DIR) ? walk(JS_DIR, '.js') : [];
for (const f of jsFiles) {
	try {
		execFileSync(process.execPath, ['--check', f], { stdio: 'pipe' });
	} catch (e) {
		const msg = (e.stderr ? e.stderr.toString() : e.message).trim();
		errors.push(`[sintaxis] ${rel(f)}\n    ${msg.split('\n').slice(0, 4).join('\n    ')}`);
	}
}

// ── 2) Imports relativos resueltos ───────────────────────────────────────────
const RE_IMPORT = /\bimport\b[^'"]*?['"]([^'"]+)['"]/g;
for (const f of jsFiles) {
	const src = readFileSync(f, 'utf8');
	let m;
	while ((m = RE_IMPORT.exec(src)) !== null) {
		const spec = m[1];
		if (!spec.startsWith('.')) continue; // CDN / bare specifiers: fuera de alcance
		const target = resolve(dirname(f), spec);
		if (!existsSync(target)) {
			errors.push(`[import] ${rel(f)} → '${spec}' no existe (${rel(target)})`);
		}
	}
}

// ── 3) Cobertura de pestañas: descriptor (collections.js) ↔ registro (app.js) ─
// El editor activo se pinta con <component :is> a partir de collections.js (TABS).
// Invariante: cada componente del descriptor debe estar REGISTRADO en app.js
// (`components: { ... }`), o `:is` no lo resolverá.
const collPath = join(JS_DIR, 'collections.js');
const appPath = join(JS_DIR, 'app.js');
if (existsSync(collPath) && existsSync(appPath)) {
	const collSrc = readFileSync(collPath, 'utf8');
	const appSrc = readFileSync(appPath, 'utf8');
	// Componentes declarados en el descriptor: component: 'XxxManager'.
	const comps = [...collSrc.matchAll(/component:\s*'(\w+)'/g)].map(m => m[1]);
	// Componentes registrados en app.js: components: { A, B, C }.
	const reg = appSrc.match(/components:\s*\{([^}]*)\}/);
	const registered = reg ? reg[1].split(',').map(s => s.trim()).filter(Boolean) : [];
	if (!comps.length) warnings.push('[tab] no se pudo parsear TABS en collections.js (¿cambió el formato?)');
	for (const c of comps) {
		if (!registered.includes(c)) {
			errors.push(`[tab] componente '${c}' del descriptor (collections.js) NO está registrado en app.js (components: {…})`);
		}
	}
	// TAB_META (nav.js), si define claves propias, debe coincidir con el descriptor.
	const navPath = join(JS_DIR, 'nav.js');
	if (existsSync(navPath)) {
		const navSrc = readFileSync(navPath, 'utf8');
		const tabKeys = [...collSrc.matchAll(/\bkey:\s*'(\w+)'/g)].map(m => m[1]);
		// Solo avisamos si nav.js declara TAB_META a mano (bloque literal) y falta alguna.
		const block = navSrc.split('export const TAB_META')[1] || '';
		if (block.includes('{') && block.includes('};')) {
			const body = block.slice(block.indexOf('{'), block.indexOf('};') + 1);
			const literal = /^\s*(\w+):\s*\{/m.test(body);
			if (literal) {
				for (const k of tabKeys) {
					if (!new RegExp(`\\b${k}\\s*:`).test(body)) {
						warnings.push(`[tab] '${k}' está en el descriptor pero no en TAB_META literal de nav.js`);
					}
				}
			}
		}
	}
}

// ── Informe ──────────────────────────────────────────────────────────────────
console.log(`Editor check · ${jsFiles.length} ficheros .js analizados`);
for (const w of warnings) console.log('  ⚠️  ' + w);
if (errors.length) {
	console.log(`\n❌ ${errors.length} error(es):`);
	for (const e of errors) console.log('  • ' + e);
	process.exit(1);
}
console.log(warnings.length ? `\n✅ Sin errores (${warnings.length} aviso[s]).` : '\n✅ Sin errores ni avisos.');
