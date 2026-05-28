import fs from "node:fs";
import path from "node:path";

const outDir = path.resolve("Sources/bach-typewriter-swift/Resources/Sounds");
fs.mkdirSync(outDir, { recursive: true });

const semitone = new Map([
  ["C", 0], ["C#", 1], ["D", 2], ["D#", 3], ["E", 4], ["F", 5],
  ["F#", 6], ["G", 7], ["G#", 8], ["A", 9], ["A#", 10], ["B", 11]
]);

const pitchNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
const noteNames = [];
for (let midi = 48; midi <= 90; midi += 1) {
  const pitch = pitchNames[midi % 12];
  const octave = Math.floor(midi / 12) - 1;
  noteNames.push(`${pitch}${octave}`);
}

function frequencyFor(note) {
  const pitch = note.includes("#") ? note.slice(0, 2) : note.slice(0, 1);
  const octave = Number(note.slice(pitch.length));
  const midi = semitone.get(pitch) + (octave + 1) * 12;
  return 440 * Math.pow(2, (midi - 69) / 12);
}

function wavFor(freq) {
  const sampleRate = 44100;
  const duration = 0.2;
  const samples = Math.floor(sampleRate * duration);
  const data = Buffer.alloc(samples * 2);

  for (let i = 0; i < samples; i += 1) {
    const t = i / sampleRate;
    const edgeFadeIn = Math.min(1, t / 0.003);
    const edgeFadeOut = Math.min(1, Math.max(0, duration - t) / 0.008);
    const edgeFade = Math.min(edgeFadeIn, edgeFadeOut);
    const attack = Math.min(1, i / (sampleRate * 0.004));
    const decay = Math.exp(-t * 34);
    const release = Math.max(0, 1 - Math.max(0, t - 0.155) / 0.045);
    const body =
      Math.sin(2 * Math.PI * freq * t) * 0.64 +
      Math.sin(2 * Math.PI * freq * 2 * t) * 0.22 +
      Math.sin(2 * Math.PI * freq * 3 * t) * 0.11 +
      Math.sin(2 * Math.PI * freq * 5 * t) * 0.035;
    const click = Math.sin(2 * Math.PI * 2200 * t) * Math.exp(-t * 120) * 0.025;
    const sample = Math.max(-1, Math.min(1, (body * attack * decay * release + click) * edgeFade * 0.58));
    data.writeInt16LE(Math.round(sample * 32767), i * 2);
  }

  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(sampleRate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

function safeName(note) {
  return note.replace("#", "sharp");
}

for (const note of noteNames) {
  fs.writeFileSync(path.join(outDir, `${safeName(note)}.wav`), wavFor(frequencyFor(note)));
}

console.log(`Wrote ${noteNames.length} note wav files to ${outDir}`);
