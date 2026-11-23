package backend;

#if sys
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
#end

/**
 * Bakes GIF or still-image states into one Sparrow atlas for a custom
 * character. Pure Haxe: uses the `format` haxelib already shipped with the
 * engine, so no Python, ImageMagick or external converter is needed.
 *
 * Output per character: <id>.png, <id>.xml and <id>.json (state anchors).
 * Frame names follow the runtime convention: "intro 0", "idle 0", etc.
 */
typedef BakeSource =
{
	state:String,
	path:String
}

typedef BakeResult =
{
	ok:Bool,
	message:String,
	frames:Int,
	fps:Float
}

#if sys
typedef Frame =
{
	name:String,
	state:String,
	width:Int,
	height:Int,
	argb:Bytes,
	?x:Int,
	?y:Int
}
#end

class CharSelectBaker
{
	static final STATES:Array<String> = ['intro', 'idle', 'confirm'];
	/** Stay well below GPU texture limits; a single row of frames can exceed 13k px. */
	static final MAX_SHEET_W:Int = 4096;

	#if sys

	public static function bake(id:String, sources:Array<BakeSource>, destFolder:String, ?fps:Float = 0):BakeResult
	{
		if(id == null || id.length == 0)
			return {ok: false, message: 'Missing character id', frames: 0, fps: 0};

		var frames:Array<Frame> = [];
		var detectedFps:Float = 0;
		for(src in sources)
		{
			if(src == null || src.path == null || src.path.length == 0) continue;
			if(STATES.indexOf(src.state) < 0) continue;
			try
			{
				var decoded:Array<Frame> = decode(src.state, src.path);
				for(f in decoded) frames.push(f);
				var gifFps:Float = detectFps(src.path);
				if(gifFps > detectedFps) detectedFps = gifFps;
			}
			catch(e:Dynamic)
				trace('CharSelectBaker: could not read ${src.path} ($e)');
		}

		if(frames.length == 0)
			return {ok: false, message: 'No readable frames', frames: 0, fps: 0};

		var outFps:Float = (fps != null && fps > 0) ? fps : (detectedFps > 0 ? detectedFps : 25);

		// Shelf packing keeps the atlas under the GPU texture width limit.
		var placed:Array<Frame> = [];
		var penX:Int = 0;
		var penY:Int = 0;
		var rowH:Int = 0;
		var sheetW:Int = 0;
		for(f in frames)
		{
			if(penX > 0 && penX + f.width > MAX_SHEET_W)
			{
				penX = 0;
				penY += rowH;
				rowH = 0;
			}
			f.x = penX;
			f.y = penY;
			placed.push(f);
			penX += f.width;
			if(f.height > rowH) rowH = f.height;
			if(penX > sheetW) sheetW = penX;
		}
		var sheetH:Int = penY + rowH;

		var sheet:Bytes = Bytes.alloc(sheetW * sheetH * 4);
		for(f in placed)
			for(fy in 0...f.height)
			{
				var srcPos:Int = fy * f.width * 4;
				var dstPos:Int = ((f.y + fy) * sheetW + f.x) * 4;
				sheet.blit(dstPos, f.argb, srcPos, f.width * 4);
			}

		try
		{
			if(!FileSystem.exists(destFolder)) FileSystem.createDirectory(destFolder);
			var pngData:format.png.Data = format.png.Tools.build32ARGB(sheetW, sheetH, sheet);
			var out:BytesOutput = new BytesOutput();
			new format.png.Writer(out).write(pngData);
			File.saveBytes('$destFolder/$id.png', out.getBytes());

			File.saveContent('$destFolder/$id.xml', buildXml(id, placed));
			File.saveContent('$destFolder/$id.json', buildAnchors(frames));

			return {ok: true, message: 'Baked ${frames.length} frames', frames: frames.length, fps: outFps};
		}
		catch(e:Dynamic)
			return {ok: false, message: Std.string(e), frames: frames.length, fps: outFps};
	}

	static function decode(state:String, path:String):Array<Frame>
	{
		var ext:String = Path.extension(path).toLowerCase();
		var out:Array<Frame> = [];
		if(ext == 'gif')
		{
			var data:format.gif.Data = new format.gif.Reader(File.read(path, true)).read();
			var w:Int = data.logicalScreenDescriptor.width;
			var h:Int = data.logicalScreenDescriptor.height;
			var count:Int = format.gif.Tools.framesCount(data);
			for(i in 0...count)
			{
				var rgba:Bytes = format.gif.Tools.extractFullRGBA(data, i);
				out.push({name: '$state $i', state: state, width: w, height: h, argb: rgbaToArgb(rgba)});
			}
		}
		else
		{
			var data:format.png.Data = new format.png.Reader(File.read(path, true)).read();
			var header:format.png.Data.Header = format.png.Tools.getHeader(data);
			var argb:Bytes = format.png.Tools.extract32(data);
			out.push({name: '$state 0', state: state, width: header.width, height: header.height, argb: argb});
		}
		return out;
	}

	static function detectFps(path:String):Float
	{
		if(Path.extension(path).toLowerCase() != 'gif') return 0;
		try
		{
			var data:format.gif.Data = new format.gif.Reader(File.read(path, true)).read();
			var gce = format.gif.Tools.graphicControl(data, 0);
			if(gce != null && gce.delay > 0) return 100 / gce.delay;
		}
		catch(e:Dynamic) {}
		return 0;
	}

	/** format.gif returns RGBA; format.png wants ARGB. */
	static function rgbaToArgb(rgba:Bytes):Bytes
	{
		var out:Bytes = Bytes.alloc(rgba.length);
		var i:Int = 0;
		while(i + 3 < rgba.length)
		{
			var r:Int = rgba.get(i);
			var g:Int = rgba.get(i + 1);
			var b:Int = rgba.get(i + 2);
			var a:Int = rgba.get(i + 3);
			out.set(i, a);
			out.set(i + 1, r);
			out.set(i + 2, g);
			out.set(i + 3, b);
			i += 4;
		}
		return out;
	}

	static function buildXml(id:String, frames:Array<Frame>):String
	{
		var sb:StringBuf = new StringBuf();
		sb.add('<?xml version="1.0" encoding="UTF-8"?>\n');
		sb.add('<TextureAtlas imagePath="$id.png">\n');
		for(f in frames)
		{
			sb.add('<SubTexture name="${f.name}" x="${f.x}" y="${f.y}" width="${f.width}" height="${f.height}"');
			sb.add(' frameX="0" frameY="0" frameWidth="${f.width}" frameHeight="${f.height}"/>\n');
		}
		sb.add('</TextureAtlas>\n');
		return sb.toString();
	}

	static function buildAnchors(frames:Array<Frame>):String
	{
		var anchors:Dynamic = {};
		for(state in STATES)
			for(f in frames)
				if(f.state == state)
				{
					Reflect.setField(anchors, state, [f.width / 2, f.height / 2]);
					break;
				}
		return haxe.Json.stringify(anchors, '\t');
	}
	#else
	public static function bake(id:String, sources:Array<BakeSource>, destFolder:String, ?fps:Float = 0):BakeResult
		return {ok: false, message: 'Baking requires a desktop build', frames: 0, fps: 0};
	#end
}
