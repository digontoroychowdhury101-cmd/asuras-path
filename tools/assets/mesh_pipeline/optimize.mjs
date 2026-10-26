// Offline asset preparation using MIT glTF Transform and meshoptimizer.
// Writes a new, uncompressed GLB. Originals and uploaded Roblox IDs are never modified.
import { NodeIO, PropertyType, Primitive } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, weld, simplify, reorder } from '@gltf-transform/functions';
import { MeshoptEncoder, MeshoptSimplifier, MeshoptDecoder } from 'meshoptimizer';
import { readFile, writeFile, stat, access } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';

const [inputArg, outputArg, ...flags] = process.argv.slice(2);
if (!inputArg || !outputArg) throw new Error('Usage: node optimize.mjs input.glb NEW-output.glb [--ratio=0.5] [--error=0.001]');
const input = resolve(inputArg), output = resolve(outputArg);
if (input === output) throw new Error('Output must be a different file');
try { await access(output); throw new Error('Output already exists; choose a new file'); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
const options = Object.fromEntries(flags.map(flag => flag.replace(/^--/, '').split('=')));
if (Object.keys(options).some(key => !['ratio', 'error'].includes(key))) throw new Error('Unknown option');
const ratio = Number(options.ratio ?? 1), error = Number(options.error ?? 0.001);
if (!(ratio > 0 && ratio <= 1 && error > 0 && error <= 0.01)) throw new Error('Use 0 < ratio <= 1 and 0 < error <= 0.01');
await Promise.all([MeshoptEncoder.ready, MeshoptSimplifier.ready, MeshoptDecoder.ready]);
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({'meshopt.decoder': MeshoptDecoder});
const document = await io.read(input);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function measure(doc) {
    const root = doc.getRoot();
    let vertices = 0, triangles = 0, primitives = 0;
    const bounds = [Infinity, Infinity, Infinity, -Infinity, -Infinity, -Infinity];
    for (const mesh of root.listMeshes()) for (const primitive of mesh.listPrimitives()) {
        if (primitive.getMode() !== Primitive.Mode.TRIANGLES) throw new Error('Only triangle assets are supported');
        const positions = primitive.getAttribute('POSITION');
        vertices += positions.getCount();
        triangles += (primitive.getIndices()?.getCount() ?? positions.getCount()) / 3;
        const values = positions.getArray();
        for (let index = 0; index < values.length; index += 3) for (let axis = 0; axis < 3; axis++) {
            bounds[axis] = Math.min(bounds[axis], values[index + axis]);
            bounds[axis + 3] = Math.max(bounds[axis + 3], values[index + axis]);
        }
        primitives++;
    }
    return {meshes: root.listMeshes().length, primitives, vertices, triangles, bounds,
        materials: root.listMaterials().length, textures: root.listTextures().length,
        skins: root.listSkins().length, animations: root.listAnimations().length,
        textureHashes: root.listTextures().map(t => hash(t.getImage())).sort()};
}
const before = measure(document);
await document.transform(weld(), dedup({propertyTypes: [PropertyType.ACCESSOR, PropertyType.TEXTURE]}));
if (ratio < 1) await document.transform(simplify({simplifier: MeshoptSimplifier, ratio, error, lockBorder: true}));
await document.transform(reorder({encoder: MeshoptEncoder, target: 'performance'}));
const bytes = await io.writeBinary(document);
const after = measure(await io.readBinary(bytes));
for (const key of ['materials', 'skins', 'animations']) if (before[key] !== after[key]) throw new Error(`Unexpected ${key} change`);
if (JSON.stringify([...new Set(before.textureHashes)]) !== JSON.stringify([...new Set(after.textureHashes)])) throw new Error('Embedded texture payload changed');
if (ratio === 1 && before.triangles !== after.triangles) throw new Error('Lossless pass changed triangle count');
if (ratio === 1 && before.bounds.some((v, i) => Math.abs(v - after.bounds[i]) > 1e-6)) throw new Error('Lossless pass changed bounds');
await writeFile(output, bytes);
const sourceBytes = await readFile(input);
const report = {input: inputArg, output: outputArg, ratio, error, before, after,
    inputBytes: (await stat(input)).size, outputBytes: bytes.byteLength,
    inputSHA256: hash(sourceBytes), outputSHA256: hash(bytes),
    pipeline: {'glTF-Transform': '4.5.1', meshoptimizer: '1.3.0'},
    compression: 'none; no Draco, quantization, meshopt compression, or KTX output'};
await writeFile(output + '.report.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({triangles: [before.triangles, after.triangles], vertices: [before.vertices, after.vertices],
    bytes: [report.inputBytes, report.outputBytes], output}, null, 2));
