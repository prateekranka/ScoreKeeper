#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import {
  DEFAULT_INPUT,
  DEFAULT_OUTPUT,
  animationFrames,
  contactFrameNumbers,
  frameSvg,
  frameState,
  readAndValidate,
  readSvgAssetDocument,
  semanticPartFrameSvg,
} from './lib/live-keyframes.mjs';

const args = new Set(process.argv.slice(2));
const valueOf = (flag) => {
  const index = process.argv.indexOf(flag);
  return index >= 0 ? process.argv[index + 1] : undefined;
};
const inputFlag = process.argv.indexOf('--input');
const inputPath = valueOf('--input') ?? DEFAULT_INPUT;
const outputPath = path.resolve(valueOf('--output') ?? DEFAULT_OUTPUT);
const smoke = args.has('--smoke');

if (inputFlag >= 0 && (!valueOf('--input') || valueOf('--input').startsWith('--'))) {
  console.error('LIVE_KEYFRAMES_INVALID --input requires a JSON path');
  process.exit(2);
}

const commandPath = (name) => {
  try {
    return execFileSync('/usr/bin/which', [name], { encoding: 'utf8' }).trim();
  } catch {
    return null;
  }
};
const MAGICK = commandPath('magick');
const SIPS = '/usr/bin/sips';
const FFMPEG = commandPath('ffmpeg');

function run(command, commandArgs, options = {}) {
  return execFileSync(command, commandArgs, { stdio: ['ignore', 'pipe', 'pipe'], ...options });
}

function runBuffer(command, commandArgs) {
  return run(command, commandArgs, { encoding: 'buffer' });
}

function frameName(frame) {
  return `frame-${String(frame).padStart(4, '0')}`;
}

function readRgba(filePath, width, height) {
  const bytes = runBuffer(MAGICK, [filePath, '-depth', '8', 'rgba:-']);
  const expectedLength = width * height * 4;
  if (bytes.length !== expectedLength) throw new Error(`RGBA_READ_FAILED ${filePath}: expected ${expectedLength} bytes, got ${bytes.length}`);
  return bytes;
}

function alphaMask(bytes) {
  const mask = new Uint8Array(bytes.length / 4);
  for (let i = 0; i < mask.length; i += 1) mask[i] = bytes[i * 4 + 3] >= 128 ? 1 : 0;
  return mask;
}

function transformPoint(matrix, x, y) {
  return {
    x: matrix[0] * x + matrix[2] * y + matrix[4],
    y: matrix[1] * x + matrix[3] * y + matrix[5],
  };
}

function transformedRectangleCoverage(mask, width, height, rect, matrix) {
  let coveredPixels = 0;
  let sampledPixels = 0;
  // Ignore two source pixels at the boundary. Rotating a pixel-stepped handle
  // can legitimately round one interior sample onto the stationary cup edge;
  // the deeper inset still proves the visible hole remains transparent.
  for (let y = rect.y + 2; y < rect.y + rect.height - 2; y += 1) {
    for (let x = rect.x + 2; x < rect.x + rect.width - 2; x += 1) {
      const point = transformPoint(matrix, x, y);
      const targetX = Math.round(point.x);
      const targetY = Math.round(point.y);
      if (targetX < 0 || targetY < 0 || targetX >= width || targetY >= height) continue;
      sampledPixels += 1;
      if (mask[targetY * width + targetX]) coveredPixels += 1;
    }
  }
  return { sampledPixels, coveredPixels };
}

function alphaQa(framePath, width, height, holeMatrices, handleMaskPaths) {
  const bytes = readRgba(framePath, width, height);
  let transparentRgbMax = 0;
  for (let i = 0; i < bytes.length; i += 4) {
    if (bytes[i + 3] === 0) transparentRgbMax = Math.max(transparentRgbMax, bytes[i], bytes[i + 1], bytes[i + 2]);
  }
  const holeRects = {
    left: { x: 49, y: 129, width: 23, height: 40 },
    right: { x: 441, y: 129, width: 24, height: 40 },
  };
  const holes = Object.fromEntries(Object.entries(holeRects).map(([name, rect]) => {
    const matrix = holeMatrices?.[name];
    const handleMaskPath = handleMaskPaths?.[name];
    const mask = handleMaskPath ? alphaMask(readRgba(handleMaskPath, width, height)) : null;
    const coverage = matrix && mask
      ? transformedRectangleCoverage(mask, width, height, rect, matrix)
      : { sampledPixels: 0, coveredPixels: 0 };
    return [name, { ...rect, ...coverage, pass: Boolean(matrix) && Boolean(mask) && coverage.sampledPixels > 0 && coverage.coveredPixels === 0 }];
  }));
  const noWhiteFringe = transparentRgbMax <= 4;
  const handleHoles = Object.values(holes).every((hole) => hole.pass);
  return {
    noWhiteFringe,
    transparentRgbMax,
    handleHoles,
    holes,
    passed: noWhiteFringe && handleHoles,
  };
}

function makeComposite(framePath, outPath, width, height) {
  const checker = `${outPath}.checker.png`;
  const light = `${outPath}.light.png`;
  const dark = `${outPath}.dark.png`;
  run(MAGICK, ['-size', `${width}x${height}`, 'pattern:checkerboard', framePath, '-compose', 'over', '-composite', '-filter', 'point', '-resize', '360x292!', checker]);
  run(MAGICK, [framePath, '-background', '#F7F2E9', '-alpha', 'background', '-filter', 'point', '-resize', '360x292!', light]);
  run(MAGICK, [framePath, '-background', '#191A1F', '-alpha', 'background', '-filter', 'point', '-resize', '360x292!', dark]);
  run(MAGICK, [checker, light, dark, '-append', '-define', 'png:color-type=2', outPath]);
  for (const temp of [checker, light, dark]) fs.rmSync(temp, { force: true });
}

function renderAnimation(model, animation, sourceDocument, outputRoot) {
  const animationRoot = path.join(outputRoot, animation.slug);
  const svgDir = path.join(animationRoot, 'svg');
  const frameDir = path.join(animationRoot, 'rgba-frames');
  const compositeDir = path.join(animationRoot, 'composites');
  const semanticQaDir = path.join(animationRoot, 'semantic-alpha-qa');
  fs.mkdirSync(svgDir, { recursive: true });
  fs.mkdirSync(frameDir, { recursive: true });
  fs.mkdirSync(compositeDir, { recursive: true });
  fs.mkdirSync(semanticQaDir, { recursive: true });

  const frames = smoke ? [...new Set([0, Math.round(animation.durationFrames / 2), animation.durationFrames])] : animationFrames(animation);
  const frameReports = [];
  for (const frame of frames) {
    const name = frameName(frame);
    const svgPath = path.join(svgDir, `${name}.svg`);
    const pngPath = path.join(frameDir, `${name}.png`);
    // Keep the ffmpeg image2 sequence contiguous even for --smoke's sparse
    // canonical frame selection.
    const compositePath = path.join(compositeDir, `frame-${String(frames.indexOf(frame)).padStart(4, '0')}.png`);
    fs.writeFileSync(svgPath, frameSvg(model, animation, frame, sourceDocument));
    run(SIPS, ['-s', 'format', 'png', svgPath, '--out', pngPath], { encoding: 'utf8' });
    const state = frameState(model, animation, frame);
    const leftHandle = model.nodes.find((node) => node.kind === 'asset' && node.semanticPart === 'handle_l');
    const rightHandle = model.nodes.find((node) => node.kind === 'asset' && node.semanticPart === 'handle_r');
    const holeMatrices = {
      left: leftHandle ? state.worldMatrices.get(leftHandle.name) : null,
      right: rightHandle ? state.worldMatrices.get(rightHandle.name) : null,
    };
    const handleMaskPaths = {};
    for (const [side, semanticPart] of [['left', 'handle_l'], ['right', 'handle_r']]) {
      const handleSvgPath = path.join(semanticQaDir, `${name}-${semanticPart}.svg`);
      const handlePngPath = path.join(semanticQaDir, `${name}-${semanticPart}.png`);
      fs.writeFileSync(handleSvgPath, semanticPartFrameSvg(model, animation, frame, sourceDocument, semanticPart));
      run(SIPS, ['-s', 'format', 'png', handleSvgPath, '--out', handlePngPath], { encoding: 'utf8' });
      handleMaskPaths[side] = handlePngPath;
    }
    const qa = alphaQa(pngPath, model.canvas.width, model.canvas.height, holeMatrices, handleMaskPaths);
    if (!qa.passed) throw new Error(`ALPHA_QA_FAILED ${animation.slug} frame ${frame}: ${JSON.stringify(qa)}`);
    makeComposite(pngPath, compositePath, model.canvas.width, model.canvas.height);
    frameReports.push({ frame, rgba: path.relative(outputRoot, pngPath), composite: path.relative(outputRoot, compositePath), alphaQa: qa });
  }

  let contactFrames = contactFrameNumbers(animation).filter((frame) => frames.includes(frame));
  if (!contactFrames.length) contactFrames = [frames[0]];
  const contactInputs = contactFrames.map((frame) => path.join(frameDir, `${frameName(frame)}.png`));
  const contactSheet = path.join(animationRoot, `${animation.slug}-transparent-contact-sheet.png`);
  if (contactInputs.length) run(MAGICK, [...contactInputs, '-filter', 'point', '-resize', '128x104!', '+append', '-background', 'none', contactSheet]);

  const mp4Path = path.join(outputRoot, `${animation.slug}.mp4`);
  const ffmpegInput = path.join(compositeDir, 'frame-%04d.png');
  const ffmpegArgs = [
    '-y',
    '-framerate', String(model.fps),
    '-start_number', '0',
    '-i', ffmpegInput,
    '-frames:v', String(frames.length),
    '-vf', 'format=yuv420p',
    '-c:v', 'libx264',
    '-profile:v', 'high',
    '-level', '4.0',
    '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart',
    mp4Path,
  ];
  run(FFMPEG, ffmpegArgs, { encoding: 'utf8', maxBuffer: 2 * 1024 * 1024 });
  return {
    slug: animation.slug,
    durationFrames: animation.durationFrames,
    renderedFrames: frames,
    contactFrames,
    rgbaFrameDir: path.relative(outputRoot, frameDir),
    transparentContactSheet: path.relative(outputRoot, contactSheet),
    mp4: path.relative(outputRoot, mp4Path),
    frameReports,
  };
}

try {
  // This is intentionally the first filesystem operation involving output:
  // absent or invalid live data must not produce a misleading proof artifact.
  const model = readAndValidate(inputPath);
  if (!MAGICK || !FFMPEG || !fs.existsSync(SIPS)) {
    throw new Error(`LIVE_KEYFRAMES_INVALID missing required tools: ${[
      !MAGICK && 'magick',
      !FFMPEG && 'ffmpeg',
      !fs.existsSync(SIPS) && '/usr/bin/sips',
    ].filter(Boolean).join(', ')}`);
  }
  const sourceDocument = readSvgAssetDocument(model.source.resolvedPath);
  fs.rmSync(outputPath, { recursive: true, force: true });
  fs.mkdirSync(outputPath, { recursive: true });
  const animations = Object.values(model.animations).map((animation) => renderAnimation(model, animation, sourceDocument, outputPath));
  const aggregateContactSheet = path.join(outputPath, 'five-animation-transparent-contact-sheet.png');
  run(MAGICK, [
    ...animations.map((animation) => path.join(outputPath, animation.transparentContactSheet)),
    '-background', 'none',
    '-append',
    aggregateContactSheet,
  ]);
  const report = {
    status: 'rendered_from_live_keyframes',
    input: path.resolve(inputPath),
    source: model.source,
    artboard: model.artboard,
    canvas: model.canvas,
    fps: model.fps,
    smoke,
    semanticAssets: model.nodes.filter((node) => node.kind === 'asset').map(({ name, parent, semanticPart, sourceElementIndices }) => ({ name, parent, semanticPart, sourceElementIndices })),
    animations,
    aggregateTransparentContactSheet: path.relative(outputPath, aggregateContactSheet),
    notes: [
      'Transforms are evaluated from normalized live-keyframes.json only; this renderer contains no animation values.',
      'Each MP4 is a portrait-friendly stack of checker, light, and dark composites.',
      'RGBA frame QA checks transparent RGB fringe and each transformed canonical handle hole against its own semantic handle layer on every frame.',
    ],
  };
  fs.writeFileSync(path.join(outputPath, 'render-report.json'), `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify({ status: report.status, output: outputPath, animations: animations.map(({ slug, mp4, transparentContactSheet }) => ({ slug, mp4, transparentContactSheet })) }, null, 2));
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(2);
}
