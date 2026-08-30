package openfl.display3D.utils;

import lime.utils.UInt8Array;

class UInt8Buff
{
	/**
	 * Maximo de buffers por tamano en el pool.
	 * Si se supera, los mas viejos se descartan.
	 */
	static inline var MAX_POOL_PER_SIZE:Int = 16;

	static var _pools:Map<Int, Array<UInt8Buff>> = new Map();

	public static function getPool(length:Int):Array<UInt8Buff> {
		if(!_pools.exists(length)) {
			_pools.set(length, []);
		}
		return _pools.get(length);
	}

	/**
	 * Recycle or create new UInt8Buff.
	 * Be sure to put() them back into the pool after you're done with them!
	 */
	public static inline function get(length:Int):UInt8Buff
	{
		var pool = getPool(length);
		var rect = pool.length > 0 ? pool.pop() : new UInt8Buff(length);
		rect._inPool = false;
		return rect;
	}

	/**
	 * Recycle or create a new UInt8Buff which will automatically be released
	 * to the pool when passed into a function.
	 */
	public static inline function weak(length:Int):UInt8Buff
	{
		var rect = get(length);
		rect._weak = true;
		return rect;
	}

	/**
	 * Limpia todos los pools, liberando memoria.
	 * Llamar en state switch para reducir uso de RAM.
	 */
	public static function clearPools():Void
	{
		for (key in _pools.keys())
		{
			var pool = _pools.get(key);
			if (pool != null)
			{
				pool.splice(0, pool.length);
			}
		}
		_pools = new Map();
	}

	/**
	 * Obtiene el numero total de buffers en todos los pools.
	 */
	public static function totalPooled():Int
	{
		var total = 0;
		for (pool in _pools)
		{
			total += pool.length;
		}
		return total;
	}

	var _weak:Bool = false;
	var _inPool:Bool = false;

	public var length(get, never):Int;

	inline function get_length() {
		return buffer.length;
	}

	public var buffer:UInt8Array;

	private function new(length:Int)
	{
		buffer = new UInt8Array(length);
	}

	/**
	 * Add this UInt8Buff to the recycling pool.
	 * Si el pool ya tiene MAX_POOL_PER_SIZE buffers de este tamano, no agrega mas.
	 */
	public inline function put():Void
	{
		if (!_inPool)
		{
			_inPool = true;
			_weak = false;
			var pool = getPool(length);
			if (pool.length < MAX_POOL_PER_SIZE)
			{
				pool.push(this);
			}
		}
	}

	/**
	 * Add this UInt8Buff to the recycling pool if it's a weak reference (allocated via weak()).
	 */
	public inline function putWeak():Void
	{
		if (_weak)
		{
			put();
		}
	}

	/**
	 * Necessary for compatibility.
	 */
	public function destroy() {}
}
