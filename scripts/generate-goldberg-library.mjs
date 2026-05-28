#!/usr/bin/env node

import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const pieceListURL = "https://www.mutopiaproject.org/piece-list.html";
const mutopiaBaseURL = "https://www.mutopiaproject.org/";
const outputPath = path.resolve(
  "Sources/bach-typewriter-swift/Resources/Library/GoldbergLibrary.json",
);
const cacheDir = path.resolve(".build/goldberg-mutopia");
const minTypingMidi = 48; // C3
const maxTypingMidi = 90; // F#6

const noteNames = [
  "C",
  "C#",
  "D",
  "D#",
  "E",
  "F",
  "F#",
  "G",
  "G#",
  "A",
  "A#",
  "B",
];

function midiToName(note) {
  const pitch = noteNames[note % 12];
  const octave = Math.floor(note / 12) - 1;
  return `${pitch}${octave}`;
}

async function fetchText(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Fetch failed ${response.status}: ${url}`);
  return response.text();
}

function htmlDecode(value) {
  return value
    .replaceAll("&amp;", "&")
    .replaceAll("&quot;", '"')
    .replaceAll("&#39;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">");
}

function trackTitle(label) {
  if (label === "Aria") return "Goldberg Aria";
  return `Goldberg Variation ${label}`;
}

async function findMutopiaPieces() {
  const html = await fetchText(pieceListURL);
  const rows = [...html.matchAll(/<tr><td>J\. S\. Bach<\/td><td><a href="([^"]+)">Goldberg Variations - ([^<]+)<\/a><\/td><td>BWV 988<\/td>/g)];
  const pieces = rows
    .map((match) => ({
      infoURL: new URL(htmlDecode(match[1]), mutopiaBaseURL).toString(),
      label: htmlDecode(match[2]).trim(),
    }))
    .filter((piece) => piece.label === "Aria" || /^\d+$/.test(piece.label))
    .sort((a, b) => {
      if (a.label === "Aria") return -1;
      if (b.label === "Aria") return 1;
      return Number(a.label) - Number(b.label);
    });

  if (pieces.length !== 31) {
    throw new Error(`Expected 31 Goldberg pieces from Mutopia, found ${pieces.length}`);
  }

  return pieces;
}

async function midiURLForPiece(piece) {
  const html = await fetchText(piece.infoURL);
  const lyMatch = html.match(/<a href="([^"]+\.ly)">LilyPond file<\/a>/);
  if (!lyMatch) throw new Error(`No LilyPond file link found on ${piece.infoURL}`);
  return new URL(htmlDecode(lyMatch[1]), piece.infoURL).toString();
}

function stripComments(source) {
  return source
    .split("\n")
    .map((line) => line.replace(/%.*/, ""))
    .join("\n");
}

function extractBlockAfter(source, markerRegex, markerName) {
  const markerMatch = markerRegex.exec(source);
  if (!markerMatch) {
    throw new Error(`Missing marker ${markerName}`);
  }

  const firstBrace = source.indexOf("{", markerMatch.index);
  if (firstBrace === -1) {
    throw new Error(`Missing opening brace after ${markerName}`);
  }

  let depth = 0;
  for (let index = firstBrace; index < source.length; index += 1) {
    const char = source[index];
    if (char === "{") depth += 1;
    if (char === "}") {
      depth -= 1;
      if (depth === 0) {
        return source.slice(firstBrace + 1, index);
      }
    }
  }

  throw new Error(`Missing closing brace after ${markerName}`);
}

function lilyPitchToSemitone(token) {
  const match = token.match(/^([a-g])(isis|eses|is|es|!|)?([',]*)/);
  if (!match) return null;

  const letter = match[1];
  const accidental = match[2] ?? "";
  const base = new Map([
    ["c", 0],
    ["d", 2],
    ["e", 4],
    ["f", 5],
    ["g", 7],
    ["a", 9],
    ["b", 11],
  ]).get(letter);

  let value = base;
  if (accidental === "is") value += 1;
  if (accidental === "isis") value += 2;
  if (accidental === "es") value -= 1;
  if (accidental === "eses") value -= 2;
  return ((value % 12) + 12) % 12;
}

function noteNameFromSemitone(semitone, previousMidi) {
  let bestMidi = null;
  for (let octave = 2; octave <= 7; octave += 1) {
    const midi = semitone + ((octave + 1) * 12);
    if (midi < minTypingMidi || midi > maxTypingMidi) {
      continue;
    }
    if (bestMidi === null) {
      bestMidi = midi;
      continue;
    }

    const bestDistance = Math.abs(bestMidi - previousMidi);
    const distance = Math.abs(midi - previousMidi);
    if (distance < bestDistance || (distance === bestDistance && midi > bestMidi)) {
      bestMidi = midi;
    }
  }
  return { midi: bestMidi, name: midiToName(bestMidi) };
}

function tokenizeSoprano(block) {
  const cleaned = block
    .replace(
      /\b([a-g](?:isis|eses|is|es|!|)?[',]*)[0-9.]*\s*[_^]?\s*~\s+\1[0-9.]*/g,
      "$1",
    )
    .replace(/<([^>]+)>[0-9.]*[_^~()[\]-]*/g, (_, chordBody) => {
      const chordNotes = chordBody.match(/[a-g](?:isis|eses|is|es|!|)?[',]*/g) ?? [];
      const melodyNote = chordNotes[chordNotes.length - 1] ?? "";
      return ` ${melodyNote} `;
    })
    .replace(/\b[a-g](?:isis|eses|is|es|!|)?[',]*[0-9.]*\\rest\b/g, " ")
    .replace(/\\[a-zA-Z]+(?:\s*#['A-Za-z0-9.()-]+)?/g, " ")
    .replace(/[{}()[\]|<>^_~=-]/g, " ");

  return cleaned.match(/\b[a-g](?:isis|eses|is|es|!|)?[',]*[0-9.]*/g) ?? [];
}

function parseSopranoNoteSequence(source) {
  const withoutComments = stripComments(source);
  let block = extractBlockAfter(withoutComments, /\bsoprano\s*=/, "soprano");
  let tokens = tokenizeSoprano(block);
  if (tokens.length === 0) {
    const referencedVoice = block.match(/\\(soprano[A-Za-z0-9_]*)/)?.[1];
    if (referencedVoice) {
      block = extractBlockAfter(withoutComments, new RegExp(`\\b${referencedVoice}\\s*=`), referencedVoice);
      tokens = tokenizeSoprano(block);
    }
  }

  const notes = [];
  let previousMidi = null;

  for (const token of tokens) {
    const semitone = lilyPitchToSemitone(token);
    if (semitone === null) continue;

    if (previousMidi === null) {
      previousMidi = semitone + (5 * 12); // Start near the original current melody range: G4 = MIDI 67.
      if (previousMidi < minTypingMidi) previousMidi += 12;
      if (previousMidi > maxTypingMidi) previousMidi -= 12;
      notes.push(midiToName(previousMidi));
      continue;
    }

    const next = noteNameFromSemitone(semitone, previousMidi);
    previousMidi = next.midi;
    notes.push(next.name);
  }

  return notes;
}

async function main() {
  await mkdir(cacheDir, { recursive: true });
  await mkdir(path.dirname(outputPath), { recursive: true });

  const pieces = await findMutopiaPieces();
  const tracks = [];

  for (const piece of pieces) {
    const sourceURL = await midiURLForPiece(piece);
    const id = piece.label === "Aria" ? "goldberg-aria" : `goldberg-var-${piece.label.padStart(2, "0")}`;
    const sourcePath = path.join(cacheDir, `${id}.ly`);
    let source;

    try {
      source = await readFile(sourcePath, "utf8");
    } catch {
      source = await fetchText(sourceURL);
      await writeFile(sourcePath, source);
    }

    const noteNamesForTrack = parseSopranoNoteSequence(source);
    tracks.push({
      id,
      title: trackTitle(piece.label),
      sourceURL,
      noteNames: noteNamesForTrack,
    });

    console.log(`${id}: ${noteNamesForTrack.length} notes`);
  }

  const payload = {
    source: "Mutopia Project Bach-Gesellschaft Goldberg Variations BWV 988 LilyPond soprano voices",
    sourceURL: "https://www.mutopiaproject.org/cgibin/make-table.cgi?collection=bachgb&preview=1",
    license: "Creative Commons Attribution-ShareAlike 3.0",
    generatedAt: new Date().toISOString(),
    tracks,
  };

  await writeFile(outputPath, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`Wrote ${outputPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
