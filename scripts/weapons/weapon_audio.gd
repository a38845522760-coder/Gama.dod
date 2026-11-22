extends RefCounted
class_name WeaponAudio

## Procedurally synthesised weapon sounds (no audio files needed).

const RATE: int = 22050
static var _cache: Dictionary = {}

static func get_stream(kind: String) -> AudioStreamWAV:
    if _cache.has(kind):
        return _cache[kind]
    var stream: AudioStreamWAV
    match kind:
        "shot":
            stream = _synth(0.30, func(t: float, i: int, last: float) -> float:
                var noise := randf() * 2.0 - 1.0
                var crack := noise * exp(-t * 55.0) * 0.95
                var body := (noise * 0.7 + last * 0.3) * exp(-t * 17.0) * 0.55
                var thump := sin(TAU * (118.0 - 70.0 * minf(t * 6.0, 1.0)) * t) * exp(-t * 15.0) * 0.95
                return crack + body + thump)
        "dry":
            stream = _synth(0.08, func(t: float, _i: int, _last: float) -> float:
                return (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.5 + sin(TAU * 1800.0 * t) * exp(-t * 120.0) * 0.4)
        "mag_out":
            stream = _synth(0.16, func(t: float, _i: int, _last: float) -> float:
                return (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.45 + sin(TAU * 420.0 * t) * exp(-t * 45.0) * 0.55)
        "mag_in":
            stream = _synth(0.2, func(t: float, _i: int, _last: float) -> float:
                return (randf() * 2.0 - 1.0) * exp(-t * 45.0) * 0.5 + sin(TAU * 260.0 * t) * exp(-t * 28.0) * 0.7)
        "bolt":
            stream = _synth(0.18, func(t: float, _i: int, _last: float) -> float:
                var click := (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.5
                var clack := sin(TAU * 700.0 * t) * exp(-t * 60.0) * 0.5
                var late := sin(TAU * 520.0 * maxf(t - 0.09, 0.0)) * exp(-maxf(t - 0.09, 0.0) * 70.0) * (0.5 if t > 0.09 else 0.0)
                return click + clack + late)
        "hit":
            stream = _synth(0.07, func(t: float, _i: int, _last: float) -> float:
                return sin(TAU * 1500.0 * t) * exp(-t * 55.0) * 0.6)
        "kill":
            stream = _synth(0.22, func(t: float, _i: int, _last: float) -> float:
                return (sin(TAU * 900.0 * t) + sin(TAU * 1350.0 * t) * 0.6) * exp(-t * 18.0) * 0.45)
        "impact":
            stream = _synth(0.12, func(t: float, _i: int, _last: float) -> float:
                return (randf() * 2.0 - 1.0) * exp(-t * 42.0) * 0.6)
        "groan":
            stream = _synth(0.9, func(t: float, _i: int, last: float) -> float:
                var f := 82.0 + 22.0 * sin(t * 9.0) - 25.0 * t
                var env := sin(clampf(t / 0.9, 0.0, 1.0) * PI)
                var voice := sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) + 0.25 * sin(TAU * f * 3.1 * t)
                var rasp := (randf() * 2.0 - 1.0) * 0.35
                return (voice * 0.45 + (rasp * 0.6 + last * 0.4) * 0.3) * env * 0.8)
        "roar":
            stream = _synth(1.4, func(t: float, _i: int, last: float) -> float:
                var f := 55.0 + 14.0 * sin(t * 6.0)
                var env := sin(clampf(t / 1.4, 0.0, 1.0) * PI)
                var voice := sin(TAU * f * t) + 0.6 * sin(TAU * f * 2.0 * t) + 0.4 * sin(TAU * f * 3.3 * t)
                var rasp := (randf() * 2.0 - 1.0)
                return (voice * 0.4 + (rasp * 0.5 + last * 0.5) * 0.4) * env)
        "spit":
            stream = _synth(0.25, func(t: float, _i: int, _last: float) -> float:
                return (randf() * 2.0 - 1.0) * exp(-t * 14.0) * 0.45 + sin(TAU * (500.0 - 900.0 * t) * t) * exp(-t * 9.0) * 0.4)
        "thud":
            stream = _synth(0.16, func(t: float, _i: int, _last: float) -> float:
                return sin(TAU * 70.0 * t) * exp(-t * 26.0) * 0.9 + (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.4)
        "pickup":
            stream = _synth(0.3, func(t: float, _i: int, _last: float) -> float:
                return (sin(TAU * 880.0 * t) + sin(TAU * 1320.0 * maxf(t - 0.08, 0.0)) * (1.0 if t > 0.08 else 0.0)) * exp(-t * 9.0) * 0.4)
        "buy":
            stream = _synth(0.25, func(t: float, _i: int, _last: float) -> float:
                return (sin(TAU * 1200.0 * t) * exp(-t * 20.0) + sin(TAU * 1800.0 * maxf(t - 0.06, 0.0)) * exp(-maxf(t - 0.06, 0.0) * 20.0) * (1.0 if t > 0.06 else 0.0)) * 0.45)
        _:
            stream = _synth(0.05, func(_t: float, _i: int, _last: float) -> float: return 0.0)
    _cache[kind] = stream
    return stream

static func _synth(duration: float, generator: Callable) -> AudioStreamWAV:
    var count := int(float(RATE) * duration)
    var data := PackedByteArray()
    data.resize(count * 2)
    var last: float = 0.0
    for i in range(count):
        var t := float(i) / float(RATE)
        var sample: float = float(generator.call(t, i, last))
        last = sample
        # Short fade-out avoids a click at the end of the buffer.
        var fade := clampf(float(count - i) / 120.0, 0.0, 1.0)
        var value := int(clampf(sample * fade, -1.0, 1.0) * 30000.0)
        data.encode_s16(i * 2, value)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = RATE
    stream.stereo = false
    stream.data = data
    return stream
