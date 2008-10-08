(* rand.pml
 *
 * COPYRIGHT (c) 2008 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)


structure Rand =
  struct

    structure PT = PrimTypes

    _primcode(
      
      extern long M_Random(long, long);
      extern int M_RandomInt(int, int);
      extern void M_SeedRand();
      extern double M_DRand (double, double);

      define inline @in-range(arg : [PT.ml_long, PT.ml_long] / exh : PT.exh) : PT.ml_long =
        let r : long = ccall M_Random(#0(#0(arg)), #0(#1(arg)))
        return(alloc(r))
      ;

      define inline @in-range(lo : long, hi : long / exh : PT.exh) : long =
        let r : long = ccall M_Random(lo, hi)
        return(r)
      ;

      define inline @in-range-int(lo : int, hi : int / exh : PT.exh) : int =
        let r : int = ccall M_RandomInt(lo, hi)
        return(r)
      ;

      define inline @in-range-wrap(arg : [PT.ml_long, PT.ml_long] / exh : PT.exh) : PT.ml_long =
        let r : long = @in-range(#0(#0(arg)), #0(#1(arg)) / exh)
        return(alloc(r))
      ;

    (* seed the random number generator *)
      define @seed(x : PT.unit / exh : PT.exh) : PT.unit =
        do ccall M_SeedRand()
        return(UNIT)
      ;

      define @rand-double (arg : [PT.ml_double, PT.ml_double] / exh : PT.exh) : PT.ml_double =
	let r : double = ccall M_DRand (#0(#0(arg)), #0(#1(arg)))
	return (alloc(r))
      ;

    )

    val inRange : (long * long) -> long = _prim(@in-range-wrap)
    val seed : unit -> unit = _prim(@seed)
    val _ = seed()
    val randDouble : (double * double) -> double = _prim(@rand-double)

  end
