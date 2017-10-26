#!/usr/bin/env dub --build=release-nobounds --compiler=ldmd2 -v --single
/+ dub.json: {
    "name":"randindex_bench",
    "dependencies": {
        "mir-random":{"path": "../"}
    }
} +/
import mir.random : rand, randIndex;
import mir.random.engine : isSaturatedRandomEngine, EngineReturnType;
import mir.random.engine.mersenne_twister : Mt19937, Mt19937_64;
import mir.random.engine.pcg : pcg32_oneseq, pcg64_oneseq_once_insecure;
import mir.random.engine.xorshift : Xoroshiro128Plus, Xorshift1024StarPhi;
import mir.utility : min, max;

import std.traits: isUnsigned, Unqual;

import std.stdio, std.datetime, std.conv;

/*
Sample results on Intel(R) Core(TM) i7-7920HQ CPU @ 3.10GHz

//
// GENERATING ULONG BENCHMARKS
//

Benchmarks for generating ulong from MersenneTwisterEngine!(uint, 32LU, 624LU, 397LU, 31LU, 2567483615u, 11LU, 4294967295u, 7LU, 2636928640u, 15LU, 4022730752u, 18LU, 1812433253u):
randIndexV1: 0.633563 * 10 ^^ 8 calls/s; sum = 21800330329
randIndexV2: 1.11266 * 10 ^^ 8 calls/s; sum = 21799356954

Benchmarks for generating ulong from MersenneTwisterEngine!(ulong, 64LU, 312LU, 156LU, 31LU, 13043109905998158313LU, 29LU, 6148914691236517205LU, 17LU, 8202884508482404352LU, 37LU, 18444473444759240704LU, 43LU, 6364136223846793005LU):
randIndexV1: 0.796416 * 10 ^^ 8 calls/s; sum = 21799577506
randIndexV2: 1.87091 * 10 ^^ 8 calls/s; sum = 21800184913

Benchmarks for generating ulong from XorshiftStarEngine!(ulong, 1024u, 31u, 11u, 30u, 11400714819323198483LU, ulong):
randIndexV1: 1.06966 * 10 ^^ 8 calls/s; sum = 21799501203
randIndexV2: 3.05227 * 10 ^^ 8 calls/s; sum = 21799876814

Benchmarks for generating ulong from Xoroshiro128Plus:
randIndexV1: 1.0195 * 10 ^^ 8 calls/s; sum = 21799621342
randIndexV2: 4.40044 * 10 ^^ 8 calls/s; sum = 21800425876

Benchmarks for generating ulong from PermutedCongruentialEngine!(xsh_rr, cast(stream_t)2, true):
randIndexV1: 0.718778 * 10 ^^ 8 calls/s; sum = 21799772797
randIndexV2: 1.55491 * 10 ^^ 8 calls/s; sum = 21799158450

Benchmarks for generating ulong from PermutedCongruentialEngine!(rxs_m_xs_forward, cast(stream_t)2, true):
randIndexV1: 0.866363 * 10 ^^ 8 calls/s; sum = 21799794704
randIndexV2: 2.52525 * 10 ^^ 8 calls/s; sum = 21800197408

//
// GENERATING UINT BENCHMARKS
//

Benchmarks for generating uint from MersenneTwisterEngine!(uint, 32LU, 624LU, 397LU, 31LU, 2567483615u, 11LU, 4294967295u, 7LU, 2636928640u, 15LU, 4022730752u, 18LU, 1812433253u):
randIndexV1: 1.3836 * 10 ^^ 8 calls/s
randIndexV2: 2.00803 * 10 ^^ 8 calls/s
new mir.random.randIndex (potential inlining shenanigans): 2.42571 * 10 ^^ 8 calls/s

Benchmarks for generating uint from MersenneTwisterEngine!(ulong, 64LU, 312LU, 156LU, 31LU, 13043109905998158313LU, 29LU, 6148914691236517205LU, 17LU, 8202884508482404352LU, 37LU, 18444473444759240704LU, 43LU, 6364136223846793005LU):
randIndexV1: 1.29997 * 10 ^^ 8 calls/s
randIndexV2: 1.8269 * 10 ^^ 8 calls/s
new mir.random.randIndex (potential inlining shenanigans): 2.30216 * 10 ^^ 8 calls/s

Benchmarks for generating uint from XorshiftStarEngine!(ulong, 1024u, 31u, 11u, 30u, 11400714819323198483LU, ulong):
randIndexV1: 2.28637 * 10 ^^ 8 calls/s
randIndexV2: 3.16081 * 10 ^^ 8 calls/s
new mir.random.randIndex (potential inlining shenanigans): 3.70199 * 10 ^^ 8 calls/s

Benchmarks for generating uint from Xoroshiro128Plus:
randIndexV1: 2.56082 * 10 ^^ 8 calls/s
randIndexV2: 4.37158 * 10 ^^ 8 calls/s
new mir.random.randIndex (potential inlining shenanigans): 6.9869 * 10 ^^ 8 calls/s

Benchmarks for generating uint from PermutedCongruentialEngine!(xsh_rr, cast(stream_t)2, true):
randIndexV1: 1.50404 * 10 ^^ 8 calls/s
randIndexV2: 2.32221 * 10 ^^ 8 calls/s
new mir.random.randIndex (potential inlining shenanigans): 3.86847 * 10 ^^ 8 calls/s

Benchmarks for generating uint from PermutedCongruentialEngine!(rxs_m_xs_forward, cast(stream_t)2, true):
randIndexV1: 1.47411 * 10 ^^ 8 calls/s
randIndexV2: 2.49377 * 10 ^^ 8 calls/s
new mir.random.randIndex (potential inlining shenanigans): 4.24178 * 10 ^^ 8 calls/s
*/

T randIndexV1(T, G)(ref G gen, T m)
    if(isSaturatedRandomEngine!G && isUnsigned!T)
{
    pragma(inline, false);//Try to prevent LDC from doing anything clever with the modulus.

    assert(m, "m must be positive");
    T ret = void;
    T val = void;
    do
    {
        val = gen.rand!T;
        ret = val % m;
    }
    while (val - ret > -m);
    return ret;
}

version (LDC)
{
    //TODO: figure out specific feature flag or CPU versions where 128 bit multiplication works!
    version (X86_64)
        private enum bool probablyCanMultiply128 = true;
    else
        private enum bool probablyCanMultiply128 = size_t.sizeof >= ulong.sizeof;

    static if (probablyCanMultiply128 && !is(ucent))
    {
        private @nogc nothrow pure @safe
        {
            pragma(LDC_inline_ir) R inlineIR(string s, R, P...)(P);

            pragma(inline, true)
            ulong[2] mul_128(ulong a, ulong b)
            {
                return inlineIR!(`
                    %a = zext i64 %0 to i128
                    %b = zext i64 %1 to i128
                    %m = mul i128 %a, %b
                    %n = lshr i128 %m, 64
                    %h = trunc i128 %n to i64
                    %l = trunc i128 %m to i64
                    %agg1 = insertvalue [2 x i64] undef, i64 %l, 0
                    %agg2 = insertvalue [2 x i64] %agg1, i64 %h, 1
                    ret [2 x i64] %agg2`, ulong[2])(a, b);
            }

            static union mul_128_u
            {
                ulong[2] v;
                struct { ulong leftover, highbits; }
            }
        }
    }
}

T randIndexV2(T, G)(ref G gen, T m)
    if(isSaturatedRandomEngine!G && isUnsigned!T)
{
    pragma(inline, false);//Try to prevent LDC from doing anything clever with the modulus.
    static if (EngineReturnType!G.sizeof >= T.sizeof * 2)
        alias MaybeR = EngineReturnType!G;
    else static if (uint.sizeof >= T.sizeof * 2)
        alias MaybeR = uint;
    else static if (ulong.sizeof >= T.sizeof * 2)
        alias MaybeR = ulong;
    else static if (is(ucent) && __traits(compiles, {static assert(ucent.sizeof >= T.sizeof * 2);}))
        mixin ("alias MaybeR = ucent;");
    else
        alias MaybeR = void;

    static if (!is(MaybeR == void))
    {
        if (!__ctfe)
        {
            alias R = MaybeR;
            static assert(R.sizeof >= T.sizeof * 2);
            import mir.ndslice.internal: _expect;
            //Use Daniel Lemire's fast alternative to modulo reduction:
            //https://lemire.me/blog/2016/06/30/fast-random-shuffling/
            R randombits = cast(R) gen.rand!T;
            R multiresult = randombits * m;
            T leftover = cast(T) multiresult;
            if (_expect(leftover < m, false))
            {
                immutable threshold = -m % m ;
                while (leftover < threshold)
                {
                    randombits =  cast(R) gen.rand!T;
                    multiresult = randombits * m;
                    leftover = cast(T) multiresult;
                }
            }
            enum finalshift = T.sizeof * 8;
            return cast(T) (multiresult >>> finalshift);
        }
    }
    else version(LDC)
    {
        static if (T.sizeof == ulong.sizeof && probablyCanMultiply128)
        {
            if (!__ctfe)
            {
                import mir.ndslice.internal: _expect;
                //Use Daniel Lemire's fast alternative to modulo reduction:
                //https://lemire.me/blog/2016/06/30/fast-random-shuffling/
                mul_128_u u = void;
                ulong r = gen.rand!ulong;
                u.v = mul_128(r, cast(ulong)m);
                if (_expect(u.leftover < m, false))
                {
                    immutable T threshold = -m % m;
                    while (u.leftover < threshold)
                    {
                        u.v = mul_128(gen.rand!ulong, cast(ulong)m);
                    }
                }
                return u.highbits;
            }
        }
    }
    //Default algorithm.
    assert(m, "m must be positive");
    T ret = void;
    T val = void;
    do
    {
        val = gen.rand!T;
        ret = val % m;
    }
    while (val - ret > -m);
    return ret;
}

void main(string[] args)
{
    import std.meta : AliasSeq;

    foreach (PrngType; AliasSeq!(Mt19937, Mt19937_64, Xorshift1024StarPhi, Xoroshiro128Plus, pcg32_oneseq, pcg64_oneseq_once_insecure))
    {
        writeln("\nBenchmarks for generating ulong from ", PrngType.stringof, ":");
        enum seed = PrngType.max / 2;
        auto gen = PrngType(seed);
        enum ulong count = 800_000_000;
        enum ulong modulus_min = 6;
        enum ulong modulus_max = 6 + 100;
        static assert(count % (modulus_max - modulus_min) == 0);
        enum outer_loop_iterations = count / (modulus_max - modulus_min);
        enum warmup_outer_loop_iterations = min(outer_loop_iterations / 2, 2_000_000u);
        ulong s = 0;

        StopWatch sw;
        sw.start;
        foreach(_; 0 .. warmup_outer_loop_iterations) //boost CPU
        {
            foreach (m; modulus_min ..modulus_max)
            {
                s += gen.randIndexV1!ulong(m);
                s += gen.randIndexV2!ulong(m);
            }
        }
        sw.stop;
        sw.reset;
        gen.__ctor(seed);
        s = 0;
        sw.start;
        foreach(_; 0..outer_loop_iterations)
        {
            foreach (m; modulus_min .. modulus_max)
                s += gen.randIndexV1!ulong(m);
        }
        sw.stop;
        writefln("randIndexV1: %s * 10 ^^ 8 calls/s; sum = %d", double(count) / sw.peek.msecs / 100_000, s);
        sw.start;
        foreach(_; 0 .. warmup_outer_loop_iterations) //boost CPU
        {
            foreach (m; modulus_min ..modulus_max)
            {
                s += gen.randIndexV1!ulong(m);
                s += gen.randIndexV2!ulong(m);
            }
        }
        sw.stop;
        sw.reset;
        gen.__ctor(seed);
        s = 0;
        sw.start;
        foreach(_; 0..outer_loop_iterations)
        {
            foreach (m; modulus_min .. modulus_max)
                s += gen.randIndexV2!ulong(m);
        }
        sw.stop;
        writefln("randIndexV2: %s * 10 ^^ 8 calls/s; sum = %d", double(count) / sw.peek.msecs / 100_000, s);
    }

    foreach (PrngType; AliasSeq!(Mt19937, Mt19937_64, Xorshift1024StarPhi, Xoroshiro128Plus, pcg32_oneseq, pcg64_oneseq_once_insecure))
    {
        writeln("\nBenchmarks for generating uint from ", PrngType.stringof, ":");
        enum seed = PrngType.max / 2;
        auto gen = PrngType(seed);
        enum ulong count = 800_000_000;
        enum uint modulus_min = 6;
        enum uint modulus_max = 6 + 100;
        static assert(count % (modulus_max - modulus_min) == 0);
        enum outer_loop_iterations = count / (modulus_max - modulus_min);
        enum warmup_outer_loop_iterations = min(outer_loop_iterations / 2, 2_000_000u);
        ulong s = 0;

        StopWatch sw;
        sw.start;
        foreach(_; 0 .. warmup_outer_loop_iterations) //boost CPU
        {
            foreach (m; modulus_min .. modulus_max)
            {
                s += gen.randIndexV1!uint(m);
                s += gen.randIndexV2!uint(m);
            }
        }
        sw.stop;
        sw.reset;
        gen.__ctor(seed);
        s = 0;
        sw.start;
        foreach(_; 0..outer_loop_iterations)
        {
            uint s1 = 0;
            foreach (m; modulus_min .. modulus_max)
                s1 += gen.randIndexV1!uint(m);
            s += s1;
        }
        sw.stop;
        writefln("randIndexV1: %s * 10 ^^ 8 calls/s; sum = %d", double(count) / sw.peek.msecs / 100_000, s);
        sw.start;
        foreach(_; 0 .. warmup_outer_loop_iterations) //boost CPU
        {
            foreach (m; modulus_min ..modulus_max)
            {
                s += gen.randIndexV1!uint(m);
                s += gen.randIndexV2!uint(m);
            }
        }
        sw.stop;
        sw.reset;
        gen.__ctor(seed);
        s = 0;
        sw.start;
        foreach(_; 0..outer_loop_iterations)
        {
            uint s1 = 0;
            foreach (m; modulus_min .. modulus_max)
                s1 += gen.randIndexV2!uint(m);
            s += s1;
        }
        sw.stop;
        writefln("randIndexV2: %s * 10 ^^ 8 calls/s; sum = %d", double(count) / sw.peek.msecs / 100_000, s);
        sw.start;
        foreach(_; 0 .. warmup_outer_loop_iterations) //boost CPU
        {
            foreach (m; modulus_min ..modulus_max)
            {
                s += gen.randIndexV1!uint(m);
                s += gen.randIndex!uint(m);
            }
        }
        sw.stop;
        sw.reset;
        gen.__ctor(seed);
        s = 0;
        sw.start;
        foreach(_; 0..outer_loop_iterations)
        {
            uint s1 = 0;
            foreach (m; modulus_min .. modulus_max)
                s1 += gen.randIndex!uint(m);
            s += s1;
        }
        sw.stop;
        writefln("new mir.random.randIndex (potential inlining shenanigans): %s * 10 ^^ 8 calls/s; sum = %d", double(count) / sw.peek.msecs / 100_000, s);
    }

    {
        //Uniform distribution check.
        static struct Counter
        {
            @nogc nothrow pure @safe:
            enum bool isRandomEngine = true;
            enum uint max = uint.max;
            uint state;
            @disable this();
            @disable this(this);
            this(uint state) { this.state = state; }
            uint opCall() { return state++; }
        }
        import mir.random.engine;
        enum uint nbuckets = uint(1u << 16);
        static assert((1uL << 32) % nbuckets == 0);
        enum uint expectedSize = uint((1uL << 32) / nbuckets);

        Counter gen = Counter(0);
        uint[] buckets = new uint[nbuckets];
        foreach (_; 0uL .. ulong(1uL << 32))
            buckets[gen.randIndexV2!uint(nbuckets)] += 1;
        foreach (x; buckets)
            if (x != expectedSize)
                assert(0, "Non-uniform distribution!");
        writeln("Uniform distribution check passed for randIndexV2.");
    }
}
