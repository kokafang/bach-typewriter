import fs from "node:fs";
import path from "node:path";

const outPath = path.resolve("Sources/bach-typewriter-swift/Resources/Sounds/obvious-test-tone.wav");
const sampleRate = 44100;
const duration = 2.0;
const samples = Math.floor(sampleRate * duration);
const data = Buffer.alloc(samples * 2);

for (let i = 0; i < samples; i += 1) {
  const t = i / sampleRate;
  const tremolo = 0.55 + 0.45 * Math.sin(2 * Math.PI * 5 * t);
  const sample = Math.sin(2 * Math.PI * 880 * t) * tremolo * 0.45;
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
fs.writeFileSync(outPath, Buffer.concat([header, data]));
console.log(outPath);
