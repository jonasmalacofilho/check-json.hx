package elebeta;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
#end

private class UnifyJsonError {
	public var field(default,null):String;
	public function new(field)
		this.field = field;
}

class WrongFieldType extends UnifyJsonError {
	public var expected:String;
	public var actualType:std.Type.ValueType;

	public function new(field, expected, actualType)
	{
		super(field);
		this.expected = expected;
		this.actualType = actualType;
	}

	public function actualTypeName()
	{
		return switch actualType {
		case TNull, TInt, TFloat, TBool, TObject, TFunction, TUnknown: Std.string(actualType).substr(1);
		case TClass(c): std.Type.getClassName(c);
		case TEnum(e): std.Type.getEnumName(e);
		}
	}

	public function toString()
		return 'Wrong type for field "$field": expected $expected but found ${actualTypeName()}';
}

class UnifyJson {
#if macro
	static function unifyArray(path:Expr, val:Expr, type:Type, nullable:Bool)
	{
		var localName = "array";
		var itemName = "item";
		var ipathName = "itemPath";
		var index = macro @:pos(val.pos) index;
		var local = macro @:pos(val.pos) $i{localName};
		var item = macro @:pos(val.pos) $i{itemName};
		var ipath = macro @:pos(val.pos) $i{ipathName};
		return macro @:pos(val.pos) {
			switch Type.typeof($val) {
			case TNull if ($v{nullable}): null;
			case TClass(c) if (Type.getClassName(c) == "Array"): null;
			case o: throw new elebeta.UnifyJson.WrongFieldType($path, "Array", o);
			}
			var $localName:Array<Dynamic> = $val;
			for ($index in 0...$local.length) {
				var $ipathName = $path + "[" + $index + "]";
				var $itemName = $local[$index];
				${unify(ipath, item, type, false)};
			}
		};
	}

	static function unifyField(path:Expr, val:Expr, f:ClassField)
	{
		var localName = "field";
		var local = macro @:pos(val.pos) $i{localName};
		return macro @:pos(val.pos) {
			var $localName = Reflect.field($val, $v{f.name});
			${unify(path, local, f.type, false)};
		}
	}

	static function unifyAnonymous(path:Expr, val:Expr, a:AnonType, nullable:Bool)
	{
		var fields = a.fields;
		if (a.status.match(AExtend(_)))
			trace("TODO handle AExtend struct status", val.pos);
		var pathName = "path";
		var path = macro @:pos(val.pos) $i{pathName};
		var block = [
			macro @:pos(val.pos) switch Type.typeof($val) {
			case TNull if ($v{nullable}): null;
			case TObject: null;
			case o: throw new elebeta.UnifyJson.WrongFieldType($path, "Object", o);
			}
		];
		for (f in fields)
			block.push(macro @:pos(val.pos) {
				var $pathName = $path + "." + $v{f.name};
				${unifyField(path, val, f)};
			});
		return macro @:pos(val.pos) $b{block};
	}

	static function unify(path:Expr, v:Expr, t:Type, nullable:Bool)
	{
		return switch t {
		case TMono(_), TDynamic(_):
			macro @:pos(v.pos) {};
		case TType(_.get() => { pack:[], name:"Null" }, [of]):
			unify(path, v, of, true);
		case TType(_.get() => t, params):
			unify(path, v, t.type.follow().applyTypeParameters(t.params, params), nullable);
		case TAnonymous(_.get() => a):
			unifyAnonymous(path, v, a, nullable);
		case TInst(_.get() => t, params):
			switch [t, params] {
			case [{ pack:[], name:"Array" }, [of]]:
				unifyArray(path, v, of, nullable);
			case [{ pack:[], name:"String" }, []]:
				macro @:pos(v.pos)
					switch Type.typeof($v) {
					case TNull if ($v{nullable}): null;
					case TClass(c) if (Type.getClassName(c) == "String"): null;
					case o: throw new elebeta.UnifyJson.WrongFieldType($path, "String", o);
					}
			case _:
				Context.error('Cannot generate code to unify json (partial) value with $t; if this looks wrong, please open an issue on GitHub', v.pos);
			}
		case TAbstract(_.get() => t, params):
			switch [t, params] {
			case [{ pack:[], name:"Bool" }, []]:
				macro @:pos(v.pos) switch Type.typeof($v) {
				case TNull if ($v{nullable}): null;
				case TBool: null;
				case o: throw new elebeta.UnifyJson.WrongFieldType($path, "Bool", o);
				}
			case [{ pack:[], name:"Int" }, []]:
				macro @:pos(v.pos) switch Type.typeof($v) {
				case TNull if ($v{nullable}): null;
				case TInt: null;
				case o: throw new elebeta.UnifyJson.WrongFieldType($path, "Int", o);
				}
			case [{ pack:[], name:"Float" }, []]:
				macro @:pos(v.pos) switch Type.typeof($v) {
				case TNull if ($v{nullable}): null;
				case TInt, TFloat: null;
				case o: throw new elebeta.UnifyJson.WrongFieldType($path, "Float", o);
				}
			case _:
				trace('TODO $t, skipping', v.pos);
				macro @:pos(v.pos) {};
			}
		case _:
			Context.error('Cannot generate code to unify json (partial) value with $t; if this looks wrong, please open an issue on GitHub', v.pos);
		}
	}
#end

	public static macro function unifyJson(value:Expr)
	{
		var type = try Context.typeof(value) catch (e:Dynamic) null;
		if (type.match(TDynamic(null)))
			type = Context.getExpectedType();
		if (type.match(TDynamic(null)))
			Context.error("Cannot figure out what is the expected type", value.pos);

		var localName = "value";
		var pathName = "path";
		var local = macro @:pos(value.pos) $i{localName};
		var path = macro @:pos(value.pos) $i{pathName};
		return macro @:pos(value.pos) {
			var $localName = $value;
			var $pathName = "";
			${unify(path, local, type, false)};
			$local;
		}
	}
}

