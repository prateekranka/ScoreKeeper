#!/usr/bin/env node

import path from 'node:path';
import { DEFAULT_INPUT, REQUIRED_SLUGS, readAndValidate } from './lib/live-keyframes.mjs';

const inputFlag = process.argv.indexOf('--input');
const inputPath = inputFlag >= 0 ? process.argv[inputFlag + 1] : DEFAULT_INPUT;

if (inputFlag >= 0 && (!inputPath || inputPath.startsWith('--'))) {
  console.error('LIVE_KEYFRAMES_INVALID --input requires a JSON path');
  process.exit(2);
}

try {
  const model = readAndValidate(inputPath);
  const summary = {
    status: 'valid',
    input: path.resolve(inputPath),
    schema: model.schema,
    source: model.source,
    artboard: model.artboard,
    canvas: model.canvas,
    fps: model.fps,
    nodes: model.nodes.map(({ name, parent, kind, semanticPart, sourceElementIndices }) => ({ name, parent, kind, semanticPart, sourceElementIndices })),
    animations: REQUIRED_SLUGS.map((slug) => ({
      slug,
      durationFrames: model.animations[slug].durationFrames,
      loop: model.animations[slug].loop,
      tracks: Object.entries(model.animations[slug].tracks).reduce((count, [, properties]) => count + Object.values(properties).reduce((sum, track) => sum + track.length, 0), 0),
    })),
  };
  console.log(JSON.stringify(summary, null, 2));
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(2);
}
