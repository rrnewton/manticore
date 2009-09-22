fun randomParray n = tabP(n, fn _ => Rand.inRangeInt (0, 10000))

fun bench (seqSz, n, sort) = 
    let
	val r = randomParray n
	val b = Time.now ()
        val r = ImplicitThread.runOnWorkGroup(WorkStealing.workGroup(), fn () => sort r)
	val e = Time.now ()
    in
	Print.printLn(Time.toString (e-b));
	()
    end

val () = bench(PrimIO.readInt(), PrimIO.readInt(), Quicksort.quicksort)
