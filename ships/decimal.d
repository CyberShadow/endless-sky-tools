import std.algorithm.searching;
import std.conv;
import std.exception;
import std.math;
import std.traits;

struct Decimal(uint digits, Base = long)
{
	enum Base factor = pow(10, digits);

	Base rawValue;

	Base opAssign(Base value) @nogc
	{
		rawValue = value * factor;
		return value;
	}

	this(Base value) @nogc
	{
		opAssign(value);
	}

	typeof(this) opAssign(string s)
	{
		auto parts = s.findSplit(".");
		auto intPart = parts[0];
		static if (isSigned!Base)
		{
			Base sign = intPart.skipOver("-") ? -1 : 1;
			if (!intPart.length)
				intPart = "0";
		}
		else
			enum sign = 1;
		auto fracPart = parts[2];
		enforce(fracPart.length <= digits, "Too little precision: " ~ s);
		while (fracPart.length < digits)
			fracPart ~= "0";
		rawValue = (intPart.to!int * factor + fracPart.to!int) * sign;
		return this;
	}

	this(string s)
	{
		opAssign(s);
	}

	typeof(this) opAssign(R)(R value)
	if (is(R : real) && !is(R : long))
	{
		rawValue = cast(Base)(value * factor);
		return this;
	}

	this(R)(R value)
	if (is(R : real) && !is(R : long))
	{
		opAssign(value);
	}

	T to(T)() const @nogc
	if (is(T : real) && !is(T : long))
	{
		return T(rawValue) / factor;
	}

	T to(T)() const @nogc
	if (is(T : long))
	{
		return cast(T)(rawValue / factor);
	}

	T to(T)() const
	if (is(T == string))
	{
		return toString();
	}

	string toString() const
	{
		if (rawValue == Base.max)
			return "∞";
		static if (isSigned!Base)
			if (rawValue == Base.min)
				return "-∞";

		Base v = rawValue;
		string sign;
		if (v < 0)
		{
			v = -v;
			sign = "-";
		}
		auto str = v.to!string;
		while (str.length < digits+1)
			str = "0" ~ str;
		str = str[0..$-digits] ~ "." ~ str[$-digits..$];
		foreach (n; 0..digits+1)
			if (str[$-1] == (n==digits?'.':'0'))
				str = str[0..$-1];
			else
				break;
		return sign ~ str;
	}

	bool isInteger() const
	{
		return rawValue % factor == 0;
	}

	bool opCast(T)() const
	if (is(T == bool))
	{
		return !!rawValue;
	}

	T opCast(T)() const
	if (is(T == Decimal))
	{
		return this;
	}

	private static Decimal makeRaw(Base value) @nogc
	{
		Decimal d;
		d.rawValue = value;
		return d;
	}

	Decimal opBinary(string op)(Decimal b) const @nogc
	if (op == q{+} || op == q{-})
	{
		return makeRaw(mixin(q{rawValue} ~ op ~ q{b.rawValue}));
	}

	Decimal opBinary(string op)(Decimal b) const @nogc
	if (op == q{*})
	{
		return makeRaw(mixin(q{(rawValue} ~ op ~ q{b.rawValue) / factor}));
	}

	Decimal opBinary(string op)(Decimal b) const @nogc
	if (op == q{/})
	{
		return makeRaw(mixin(q{(rawValue * factor)} ~ op ~ q{b.rawValue}));
	}

	Decimal opBinary(string op)(Base b) const @nogc
	if (op == q{*} || op == q{/})
	{
		return makeRaw(mixin(q{rawValue} ~ op ~ q{b}));
	}

	Decimal opBinaryRight(string op)(Base b) const @nogc
	if (op == q{*})
	{
		return makeRaw(mixin(q{b} ~ op ~ q{rawValue}));
	}

	Decimal opBinaryRight(string op)(Base b) const @nogc
	if (op == q{/})
	{
		return makeRaw(mixin(q{(b * factor * factor)} ~ op ~ q{rawValue}));
	}

	Decimal opBinaryRight(string op)(Base b) const @nogc
	if (op == q{+} || op == q{-})
	{
		return makeRaw(mixin(q{(b * factor)} ~ op ~ q{rawValue}));
	}

	Decimal opOpAssign(string op)(Decimal b) @nogc
	if (op == q{+} || op == q{-})
	{
		mixin(q{rawValue} ~ op ~ q{=b.rawValue;});
		return this;
	}

	Decimal opOpAssign(string op)(Decimal b) @nogc
	if (op == q{*})
	{
		this = mixin(q{this} ~ op ~ q{b});
		return this;
	}

	Decimal opOpAssign(string op)(Base b) @nogc
	if (op == q{*} || op == q{/})
	{
		mixin(q{rawValue} ~ op ~ q{=b;});
		return this;
	}

	bool opEquals(Decimal b) const @nogc
	{
		return this.rawValue == b.rawValue;
	}

	bool opEquals(Base b) const @nogc
	{
		return this.rawValue == Decimal(b).rawValue;
	}

	Base opCmp(Decimal b) const @nogc
	{
		return this.rawValue - b.rawValue;
	}

	Base opCmp(Base b) const @nogc
	{
		return this.rawValue - Decimal(b).rawValue;
	}

	enum min = makeRaw(Base.min);
	enum max = makeRaw(Base.max);
}

unittest
{
	auto d = Decimal!2("1");
	assert(d == 1);
	d += Decimal!2("2");
	assert(d == 3);
	assert(d > 0);
	assert(2 * d == 6);
	assert(d + d == 6);
	assert(d * d == 9);
	assert(d / d == 1);
	d -= Decimal!2(1);
	assert(d == 2);
	assert(1 / Decimal!2("0.1") == 10);
	assert(3 - Decimal!2(2) == 1);
	d = 5;
	d *= 4;
	assert(d == 20);
	assert(d / 2 == 10);
	d /= 5;
	assert(d == 4);
}
