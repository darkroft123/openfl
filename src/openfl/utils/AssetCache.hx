package openfl.utils;

import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.text.Font;
#if lime
import lime.utils.Assets as LimeAssets;
#end

/**
	AssetCache con LRU (Least Recently Used) para Dark's Collection.
	Sobreescribe el AssetCache estandar de OpenFL.

	Cuando se supera maxMemoryBytes, los assets menos usados se eliminan automaticamente.
	Esto previene el crecimiento ilimitado de RAM.
**/
class AssetCache implements IAssetCache
{
	public var enabled(get, set):Bool;

	@:noCompletion @:dox(hide) public var bitmapData:Map<String, BitmapData>;
	@:noCompletion @:dox(hide) public var font:Map<String, Font>;
	@:noCompletion @:dox(hide) public var sound:Map<String, Sound>;

	/**
		Maximo de memoria en bytes para el cache de BitmapData.
		Cuando se supera, se eliminan los assets menos usados (LRU).
		256MB por defecto. Pon 0 para desactivar el limite.
	**/
	public var maxMemoryBytes:Int;

	@:noCompletion private var __enabled:Bool = true;

	// LRU: orden de acceso, ultimo = mas reciente
	@:noCompletion private var __lruOrder:Array<String>;
	// Contador de memoria actual para BitmapData
	@:noCompletion private var __currentMemoryBytes:Int;

	public function new()
	{
		bitmapData = new Map<String, BitmapData>();
		font = new Map<String, Font>();
		sound = new Map<String, Sound>();
		__lruOrder = [];
		__currentMemoryBytes = 0;
		maxMemoryBytes = 256 * 1024 * 1024; // 256MB
	}

	/**
		Limpia todos los assets o los que coincidan con un prefijo.
	**/
	public function clear(prefix:String = null):Void
	{
		if (prefix == null)
		{
			bitmapData = new Map<String, BitmapData>();
			font = new Map<String, Font>();
			sound = new Map<String, Sound>();
			__lruOrder = [];
			__currentMemoryBytes = 0;
		}
		else
		{
			var keys = bitmapData.keys();
			for (key in keys)
			{
				if (StringTools.startsWith(key, prefix))
				{
					removeBitmapData(key);
				}
			}

			var keys = font.keys();
			for (key in keys)
			{
				if (StringTools.startsWith(key, prefix))
				{
					removeFont(key);
				}
			}

			var keys = sound.keys();
			for (key in keys)
			{
				if (StringTools.startsWith(key, prefix))
				{
					removeSound(key);
				}
			}
		}
	}

	/**
		Obtiene un BitmapData del cache y lo marca como "recien usado" (LRU).
	**/
	public function getBitmapData(id:String):BitmapData
	{
		var bd = bitmapData.get(id);
		if (bd != null)
		{
			__touchLRU(id);
		}
		return bd;
	}

	public function getFont(id:String):Font
	{
		return font.get(id);
	}

	public function getSound(id:String):Sound
	{
		return sound.get(id);
	}

	public function hasBitmapData(id:String):Bool
	{
		return bitmapData.exists(id);
	}

	public function hasFont(id:String):Bool
	{
		return font.exists(id);
	}

	public function hasSound(id:String):Bool
	{
		return sound.exists(id);
	}

	public function removeBitmapData(id:String):Bool
	{
		if (bitmapData.exists(id))
		{
			var bd = bitmapData.get(id);
			if (bd != null)
			{
				__currentMemoryBytes -= __estimateBitmapSize(bd);
			}
			__removeFromLRU(id);
			#if lime
			LimeAssets.cache.image.remove(id);
			#end
			return bitmapData.remove(id);
		}
		return false;
	}

	public function removeFont(id:String):Bool
	{
		#if lime
		LimeAssets.cache.font.remove(id);
		#end
		return font.remove(id);
	}

	public function removeSound(id:String):Bool
	{
		#if lime
		LimeAssets.cache.audio.remove(id);
		#end
		return sound.remove(id);
	}

	/**
		Agrega o reemplaza un BitmapData en el cache.
		Si se supera maxMemoryBytes, elimina los menos usados.
	**/
	public function setBitmapData(id:String, bitmapData:BitmapData):Void
	{
		// Si ya existia, restar la memoria vieja
		if (this.bitmapData.exists(id))
		{
			var old = this.bitmapData.get(id);
			if (old != null)
			{
				__currentMemoryBytes -= __estimateBitmapSize(old);
			}
			__removeFromLRU(id);
		}

		this.bitmapData.set(id, bitmapData);
		__currentMemoryBytes += __estimateBitmapSize(bitmapData);
		__lruOrder.push(id);

		// Evict si se supera el limite
		if (maxMemoryBytes > 0)
		{
			while (__currentMemoryBytes > maxMemoryBytes && __lruOrder.length > 0)
			{
				__evictOldest();
			}
		}
	}

	public function setFont(id:String, font:Font):Void
	{
		this.font.set(id, font);
	}

	public function setSound(id:String, sound:Sound):Void
	{
		this.sound.set(id, sound);
	}

	/**
		Estima el tamano en bytes de un BitmapData.
		Ancho * Alto * 4 bytes (RGBA).
	**/
	private function __estimateBitmapSize(bd:BitmapData):Int
	{
		if (bd == null) return 0;
		return bd.width * bd.height * 4;
	}

	/**
		Marca un asset como "recien usado" moviendolo al final del LRU.
	**/
	private function __touchLRU(id:String):Void
	{
		__removeFromLRU(id);
		__lruOrder.push(id);
	}

	/**
		Remueve un ID del array LRU.
	**/
	private function __removeFromLRU(id:String):Void
	{
		var idx = __lruOrder.indexOf(id);
		if (idx >= 0)
		{
			__lruOrder.splice(idx, 1);
		}
	}

	/**
		Elimina el asset menos usado (el primero del LRU).
	**/
	private function __evictOldest():Void
	{
		if (__lruOrder.length == 0) return;

		var oldestId = __lruOrder.shift();
		if (oldestId != null && bitmapData.exists(oldestId))
		{
			var bd = bitmapData.get(oldestId);
			if (bd != null)
			{
				__currentMemoryBytes -= __estimateBitmapSize(bd);
			}
			#if lime
			LimeAssets.cache.image.remove(oldestId);
			#end
			bitmapData.remove(oldestId);
		}
	}

	/**
		Obtiene cuantos assets hay en el cache de BitmapData.
	**/
	public function getBitmapDataCount():Int
	{
		var count = 0;
		for (_ in bitmapData)
			count++;
		return count;
	}

	/**
		Obtiene la memoria actual usada por BitmapData en bytes.
	**/
	public function getCurrentMemoryBytes():Int
	{
		return __currentMemoryBytes;
	}

	// Get & Set Methods
	@:noCompletion private function get_enabled():Bool
	{
		return __enabled;
	}

	@:noCompletion private function set_enabled(value:Bool):Bool
	{
		return __enabled = value;
	}
}
