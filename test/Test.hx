import elebeta.UnifyJson;
import haxe.Json.parse;
import utest.*;
import utest.ui.*;

typedef TestField<T> = { field:T };

class Test {
	public function new() {}

	static macro function fails(e:haxe.macro.Expr, ?t:haxe.macro.Expr):haxe.macro.Expr
		return macro @:pos(e.pos) Assert.raises(function () return UnifyJson.unifyJson($e), $t);

	static macro function succeeds(e:haxe.macro.Expr):haxe.macro.Expr
		return macro @:pos(e.pos) Assert.same($e, UnifyJson.unifyJson($e));

	public function test_001_basics()
	{
		succeeds(( parse('{ "field" : 1 }') : { field : Int } ));

		succeeds(( parse('{ "field" : 1 }') : TestField<Int> ));
		succeeds(( parse('{ "field" : 3.14 }') : TestField<Float> ));
		succeeds(( parse('{ "field" : 3 }') : TestField<Float> ));
		succeeds(( parse('{ "field" : true }') : TestField<Bool> ));
		succeeds(( parse('{ "field" : "foo" }') : TestField<String> ));
		succeeds(( parse('{ "field" : {"field":1} }') : TestField<TestField<Int>> ));
		succeeds(( parse('{ "field" : [3, 1, 4] }') : TestField<Array<Int>> ));

		fails(( parse('{ "foo" : 1 }') : TestField<Int> ));
		fails(( parse('{ "field" : "foo" }') : TestField<Int> ));
		fails(( parse('{ "field" : null }') : TestField<Int> ));
		fails(( parse('{ "field" : "foo" }') : TestField<TestField<Int>> ));
		fails(( parse('{ "field" : null }') : TestField<TestField<Int>> ));
		fails(( parse('{ "field" : [3, 1, 4.15] }') : TestField<Array<Int>> ));
		fails(( parse('{ "field" : "foo" }') : TestField<Array<Int>> ));
		fails(( parse('{ "field" : null }') : TestField<Array<Int>> ));
	}

	var iv:TestField<Int>;
	static var sv:TestField<Int>;
	public function test_002_get_type()
	{
		var v = parse('{ "field" : 1 }');
		Assert.same(v, UnifyJson.unifyJson( (v:TestField<Int>) ));  // explicit
		Assert.same(v, ( UnifyJson.unifyJson(v) :TestField<Int> ));  // contextual: immediate

		var lv:TestField<Int> = v;
		Assert.same(v, UnifyJson.unifyJson(lv));  // contextual: local

		this.iv = v;
		Assert.same(v, UnifyJson.unifyJson(this.iv));  // contextual: instance field

		sv = v;
		Assert.same(v, UnifyJson.unifyJson(sv));  // contextual: static field
	}

	public function test_003_nullales()
	{
		succeeds(( parse('{}') : TestField<Null<Int>> ));
		succeeds(( parse('{ "field" : null }') : TestField<Null<Int>> ));
		succeeds(( parse('{ "field" : {} }') : TestField<TestField<Null<Int>>> ));
		succeeds(( parse('{ "field" : {"field":null} }') : TestField<TestField<Null<Int>>> ));

		fails(( parse('{ "field" : {} }') : TestField<Null<TestField<Int>>> ));
		fails(( parse('{ "field" : {"field":null} }') : TestField<Null<TestField<Int>>> ));
	}

	// public function test_004_complex()
	// {
		// TODO complex and/or composed structs
		// TODO abstracts
		// TODO enum abstracts
	// }

	public static function main()
	{
		var runner = new Runner();
		runner.addCase(new Test());
		Report.create(runner);
		runner.run();
	}
}

