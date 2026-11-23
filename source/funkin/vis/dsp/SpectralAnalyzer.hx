package funkin.vis.dsp;

import flixel.FlxG;
import lime.media.AudioSource;

/**
 * Self-contained SpectralAnalyzer matching the public API used by the Pico Mix
 * ABot speaker scripts (`new SpectralAnalyzer(source, bars, smoothing, peakHold)`,
 * `fftN`, `getLevels()`).
 *
 * The upstream funkin.vis haxelib is NOT compiled into this engine: it calls a
 * newer grig.audio `makeLogGraph` signature (7 args) than the installed one (4
 * args), so Project.xml excludes it. As a result HScript's
 * `import funkin.vis.dsp.SpectralAnalyzer;` fails with
 * "Import of class ... could not be added" and the visualizer never starts.
 *
 * This class lives in `source/`, so it is compiled into the binary and
 * `Type.resolveClass()` (used by HScript import) resolves it. FFT, log-frequency
 * band mapping and peak tracking are implemented here, with no dependency on
 * funkin.vis or grig.audio.
 */
typedef Bar =
{
	var value:Float;
	var peak:Float;
}

@:keep
class SpectralAnalyzer
{
	public var minDb(default, set):Float = -70;
	public var maxDb(default, set):Float = -20;
	public var fftN(default, set):Int = 4096;
	public var minFreq:Float = 50;
	public var maxFreq:Float = 22000;

	private var source:AudioSource;
	private var barCount:Int;
	private var smoothing:Float;
	private var peakHold:Int;
	private var fft:SelfFFT;
	private var bands:SelfBands;
	private var histories:Array<PeakFinder> = [];
	private var signal:Array<Float> = [];
	private var fftLen:Int = 4096;

	public function new(audioSource:AudioSource, barCount:Int, smoothingTimeConstant:Float = 0.8, peakHold:Int = 30)
	{
		this.barCount = barCount;
		this.smoothing = smoothingTimeConstant;
		this.peakHold = peakHold;
		this.source = resolveSource(audioSource);
		this.fft = new SelfFFT(nextPow2(fftN));
		this.bands = new SelfBands();
		calcHistories();
	}

	/**
	 * The script passes `FlxG.sound.music._channel.__audioSource`, but OpenFL
	 * 9.2.x names that field `__source` (renamed to `__audioSource` in 9.3.2).
	 * Reflect avoids a compile-time dependency on either private name.
	 */
	private static function resolveSource(passed:AudioSource):AudioSource
	{
		if (passed != null)
			return passed;

		try
		{
			var music = FlxG.sound.music;
			if (music == null)
				return null;
			var channel = Reflect.field(music, "_channel");
			if (channel == null)
				return null;
			var src = Reflect.field(channel, "__audioSource");
			if (src == null)
				src = Reflect.field(channel, "__source");
			return cast src;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	private function calcHistories()
	{
		if (barCount > histories.length)
			histories.resize(barCount);
		for (i in 0...barCount)
			if (histories[i] == null)
				histories[i] = new PeakFinder(peakHold);
	}

	private function zeroLevels(levels:Array<Bar>):Array<Bar>
	{
		levels.resize(barCount);
		for (i in 0...barCount)
		{
			if (levels[i] != null)
			{
				levels[i].value = 0;
				levels[i].peak = 0;
			}
			else
				levels[i] = {value: 0, peak: 0};
		}
		return levels;
	}

	public function getLevels(?levels:Array<Bar>):Array<Bar>
	{
		if (levels == null)
			levels = [];

		try
		{
			if (source == null || source.buffer == null || source.buffer.data == null)
				return zeroLevels(levels);

			var buffer = source.buffer;
			var bytesPerSample = Std.int(buffer.bitsPerSample / 8);
			if (bytesPerSample <= 0 || buffer.channels <= 0)
				return zeroLevels(levels);

			var dataLength = buffer.data.length;
			var music = FlxG.sound.music;
			var musicLength = music != null ? music.length : 0;
			if (musicLength <= 0 || dataLength <= 0)
				return zeroLevels(levels);

			var startFrame = Std.int(music.time / musicLength * dataLength);
			if (startFrame < 0)
				return zeroLevels(levels);
			startFrame -= startFrame % bytesPerSample;
			if (startFrame < 0)
				startFrame = 0;

			var wanted = fftLen * bytesPerSample * buffer.channels;
			var endFrame = Std.int(Math.min(startFrame + wanted, dataLength));
			if (endFrame <= startFrame)
				return zeroLevels(levels);

			var segment = buffer.data.subarray(startFrame, endFrame);
			readSignal(segment, buffer.bitsPerSample);

			if (buffer.channels > 1)
			{
				var channels = buffer.channels;
				var mono = Std.int(signal.length / channels);
				for (i in 0...mono)
				{
					var sum = 0.0;
					for (c in 0...channels)
						sum += signal[i * channels + c];
					signal[i] = sum / channels;
				}
				signal.resize(mono);
			}

			var spectrum = fft.calcFreq(signal);
			var graph = bands.makeLogGraph(spectrum, barCount + 1, Std.int(maxDb - minDb), 256);

			var count = graph.length - 1;
			if (count > levels.length)
				levels.resize(count);

			for (i in 0...count)
			{
				if (histories[i] == null)
					histories[i] = new PeakFinder(peakHold);

				var value = graph[i] / 256;
				var last = histories[i].lastValue;
				if (smoothing > 0 && smoothing < 1 && Math.isFinite(value))
					value = smoothing * last + (1 - smoothing) * Math.abs(value);
				else
					value = Math.abs(value);
				if (!Math.isFinite(value))
					value = 0;
				histories[i].push(value);

				if (levels[i] != null)
				{
					levels[i].value = value;
					levels[i].peak = histories[i].peak;
				}
				else
					levels[i] = {value: value, peak: histories[i].peak};
			}
			levels.resize(count);
			return levels;
		}
		catch (e:Dynamic)
		{
			// Visualizer is cosmetic: never let it take down the song.
			return zeroLevels(levels);
		}
	}

	private function readSignal(data:lime.utils.UInt8Array, bitsPerSample:Int)
	{
		signal.resize(0);
		switch (bitsPerSample)
		{
			case 8:
				for (i in 0...data.length)
					signal.push(data[i] / 128.0);
			case 16:
				for (i in 0...Std.int(data.length / 2))
					signal.push(readI16(data, i * 2) / 32767.0);
			case 24:
				for (i in 0...Std.int(data.length / 3))
					signal.push(readI24(data, i * 3) / 8388607.0);
			case 32:
				for (i in 0...Std.int(data.length / 4))
					signal.push(readI32(data, i * 4) / 2147483647.0);
			default:
				for (i in 0...data.length)
					signal.push(data[i] / 128.0);
		}
	}

	private static inline function readI16(data:lime.utils.UInt8Array, p:Int):Int
	{
		var v = data[p] | (data[p + 1] << 8);
		return (v & 0x8000) != 0 ? v - 0x10000 : v;
	}

	private static inline function readI24(data:lime.utils.UInt8Array, p:Int):Int
	{
		var v = data[p] | (data[p + 1] << 8) | (data[p + 2] << 16);
		return (v & 0x800000) != 0 ? v - 0x1000000 : v;
	}

	private static inline function readI32(data:lime.utils.UInt8Array, p:Int):Int
	{
		return data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
	}

	private static function nextPow2(value:Int):Int
	{
		var p = 1;
		while (p < value)
			p <<= 1;
		return p;
	}

	function set_minDb(value:Float):Float
	{
		minDb = value;
		return value;
	}

	function set_maxDb(value:Float):Float
	{
		maxDb = value;
		return value;
	}

	function set_fftN(value:Int):Int
	{
		fftN = value;
		fftLen = value;
		fft = new SelfFFT(nextPow2(value));
		calcHistories();
		return value;
	}
}

/** Rolling peak + exponential-smoothing history for one frequency band. */
private class PeakFinder
{
	private var buffer:Array<Float>;
	private var index:Int = 0;
	public var peak(default, null):Float = 0;
	public var lastValue(get, never):Float;

	public function new(length:Int = 30)
	{
		buffer = [];
		for (i in 0...length)
			buffer.push(0);
	}

	public function push(value:Float)
	{
		buffer[index] = value;
		if (value > peak)
			peak = value;
		else
		{
			var m = buffer[0];
			for (v in buffer)
				if (v > m)
					m = v;
			peak = m;
		}
		index = (index + 1 == buffer.length) ? 0 : index + 1;
	}

	private function get_lastValue():Float
	{
		return index == 0 ? buffer[buffer.length - 1] : buffer[index - 1];
	}
}

/** Radix-2 Cooley-Tukey FFT with a Hamming window, ported from grig.audio. */
private class SelfFFT
{
	private static inline var TWO_PI = 6.2831853;

	private var n:Int;
	private var logN:Int;
	private var hamming:Array<Float> = [];
	private var reversed:Array<Int> = [];
	private var rootRe:Array<Float> = [];
	private var rootIm:Array<Float> = [];
	private var re:Array<Float> = [];
	private var im:Array<Float> = [];

	public function new(n:Int = 512)
	{
		this.n = n;
		logN = Std.int(Math.log(n) / Math.log(2));
		for (i in 0...n)
			hamming.push(1 - 0.85 * Math.cos(i * (TWO_PI / n)));
		for (i in 0...n)
			reversed.push(bitReverse(i));
		for (i in 0...Std.int(n / 2))
		{
			rootRe.push(Math.cos(i * (TWO_PI / n)));
			rootIm.push(Math.sin(i * (TWO_PI / n)));
		}
		for (i in 0...n)
		{
			re.push(0);
			im.push(0);
		}
	}

	private function bitReverse(x:Int):Int
	{
		var y = 0;
		var i = logN;
		while (i > 0)
		{
			y = (y << 1) | (x & 1);
			x >>= 1;
			i--;
		}
		return y;
	}

	public function calcFreq(data:Array<Float>):Array<Float>
	{
		for (i in 0...n)
		{
			var v = i < data.length ? data[i] : 0.0;
			re[reversed[i]] = v * hamming[i];
			im[reversed[i]] = 0.0;
		}

		var half = 1;
		var inv = Std.int(n / 2);
		while (inv > 0)
		{
			var g = 0;
			while (g < n)
			{
				var b = 0;
				var r = 0;
				while (b < half)
				{
					var evenRe = re[g + b];
					var evenIm = im[g + b];
					var cr = rootRe[r];
					var ci = rootIm[r];
					var oddRe = cr * re[g + half + b] - ci * im[g + half + b];
					var oddIm = cr * im[g + half + b] + ci * re[g + half + b];
					re[g + b] = evenRe + oddRe;
					im[g + b] = evenIm + oddIm;
					re[g + half + b] = evenRe - oddRe;
					im[g + half + b] = evenIm - oddIm;
					b++;
					r += inv;
				}
				g += half << 1;
			}
			half <<= 1;
			inv >>= 1;
		}

		var freq:Array<Float> = [];
		for (i in 0...Std.int(n / 2))
			freq.push(2 * Math.sqrt(re[1 + i] * re[1 + i] + im[1 + i] * im[1 + i]) / n);
		freq[Std.int(n / 2) - 1] = Math.sqrt(re[Std.int(n / 2)] * re[Std.int(n / 2)] + im[Std.int(n / 2)] * im[Std.int(n / 2)]) / n;
		return freq;
	}
}

/** Log-frequency band mapping, ported from grig.audio.FFTVisualization. */
private class SelfBands
{
	private var xscale:Array<Float> = [];

	public function new() {}

	private static function computeLogXScale(bands:Int):Array<Float>
	{
		var xs:Array<Float> = [];
		for (i in 0...(bands + 1))
			xs.push(0);
		xs[bands] = 0;
		for (i in 0...bands)
			xs[i] = Math.pow(256, i / bands) - 0.5;
		return xs;
	}

	private static function computeFreqBand(freq:Array<Float>, xs:Array<Float>, band:Int, bands:Int):Float
	{
		var a = Math.ceil(xs[band]);
		var b = Math.floor(xs[band + 1]);
		var total = 0.0;
		if (b < a)
		{
			if (b >= 0 && b < freq.length)
				total += freq[b] * (xs[band + 1] - xs[band]);
		}
		else
		{
			if (a > 0 && a - 1 < freq.length)
				total += freq[a - 1] * (a - xs[band]);
			while (a < b)
			{
				if (a >= 0 && a < freq.length)
					total += freq[a];
				a++;
			}
			if (b < 256 && b >= 0 && b < freq.length)
				total += freq[b] * (xs[band + 1] - b);
		}
		total *= bands / 12;
		if (total <= 0)
			return -200;
		return 20 * (Math.log(total) / Math.log(10));
	}

	public function makeLogGraph(freq:Array<Float>, bands:Int, dbRange:Int, intRange:Int):Array<Int>
	{
		if (xscale.length != bands + 1)
			xscale = computeLogXScale(bands);

		var graph:Array<Int> = [];
		for (i in 0...bands)
		{
			var val = computeFreqBand(freq, xscale, i, bands);
			val = (1 + val / dbRange) * intRange;
			graph.push(Std.int(Math.max(0, Math.min(intRange, val))));
		}
		return graph;
	}
}
