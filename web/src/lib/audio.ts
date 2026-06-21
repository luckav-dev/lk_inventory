// Self-contained NUI sound system. Sounds are synthesised with the Web Audio
// API so the resource ships with no audio assets and never collides with another
// resource's sounds. Trigger from Lua via SendNUIMessage({ action: 'playSound',
// data: { name } }); names map to the table below.

type SoundSpec = {
  type: OscillatorType;
  freq: number;
  sweepTo?: number;
  duration: number;
  gain?: number;
};

const SOUNDS: Record<string, SoundSpec> = {
  pickup: { type: 'square', freq: 620, sweepTo: 880, duration: 0.07, gain: 0.12 },
  drop: { type: 'sine', freq: 200, sweepTo: 90, duration: 0.12, gain: 0.18 },
  throw: { type: 'sawtooth', freq: 520, sweepTo: 150, duration: 0.18, gain: 0.1 },
  kick: { type: 'sine', freq: 150, sweepTo: 60, duration: 0.16, gain: 0.2 },
  use: { type: 'triangle', freq: 480, sweepTo: 620, duration: 0.1, gain: 0.1 },
  open: { type: 'triangle', freq: 430, sweepTo: 540, duration: 0.08, gain: 0.09 },
  close: { type: 'triangle', freq: 360, sweepTo: 280, duration: 0.08, gain: 0.09 },
  error: { type: 'square', freq: 200, sweepTo: 140, duration: 0.18, gain: 0.12 },
};

let ctx: AudioContext | null = null;
let volume = 1;

function context(): AudioContext | null {
  if (typeof AudioContext === 'undefined') return null;
  if (!ctx) ctx = new AudioContext();
  // Some embedders start the context suspended until a gesture.
  if (ctx.state === 'suspended') void ctx.resume();
  return ctx;
}

export function setVolume(value: number) {
  volume = Math.max(0, Math.min(1, value));
}

export function playSound(name: string) {
  const spec = SOUNDS[name];
  const c = spec && context();
  if (!spec || !c) return;

  const now = c.currentTime;
  const osc = c.createOscillator();
  const gain = c.createGain();

  osc.type = spec.type;
  osc.frequency.setValueAtTime(spec.freq, now);
  if (spec.sweepTo) {
    osc.frequency.exponentialRampToValueAtTime(Math.max(1, spec.sweepTo), now + spec.duration);
  }

  const peak = (spec.gain ?? 0.12) * volume;
  gain.gain.setValueAtTime(peak, now);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + spec.duration);

  osc.connect(gain);
  gain.connect(c.destination);
  osc.start(now);
  osc.stop(now + spec.duration);
}

// Unlock the audio context on the first interaction (browser autoplay policy).
if (typeof window !== 'undefined') {
  const unlock = () => context();
  window.addEventListener('pointerdown', unlock, { once: true });
  window.addEventListener('keydown', unlock, { once: true });
}
