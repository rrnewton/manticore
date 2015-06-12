(* read-set.pml
 *
 * COPYRIGHT (c) 2014 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Chronologically ordered read sets for NoRec
 *)

 

structure FFReadSetCounter = 
struct

#define NEXT 3
#define NEXTK 6
#define KPOINTER 5
#define HEAD 0
#define TAIL 1
#define LASTK 2
#define NUMK 3

#define START_TIMER let vp : vproc = host_vproc do ccall GenTimerStart(vp)
#define STOP_TIMER let vp : vproc = host_vproc do ccall GenTimerStop(vp)
   


	(*Careful, if this changes, we could possibly be indexing a "WithoutK" item 
     *incorrectly when filtering the read set*)
    datatype 'a item = Write of 'a * 'a * 'a | NilItem | WithK of 'a * 'a * 'a * 'a * 'a * 'a
                     | WithoutK of 'a * 'a * 'a | Abort of unit 


    _primcode(
        define @allocPrintFun(x:unit / exh:exh) : any = 
            fun f(x:any / exh:exh) : unit = return(UNIT)
            let box : ![fun(any / exh -> unit)] = alloc(f)
            let box : ![fun(any / exh -> unit)] = promote(box)
            return(box);
    )
    
    val allocPrintFun : unit -> 'a = _prim(@allocPrintFun)
    val printFunPtr = allocPrintFun()
    fun getPrintFunPtr() = printFunPtr

    _primcode(

        extern void M_Print_Long2(void *, void *, void *);
        extern void M_IncCounter(void *, int , long);
        extern void * fastForward(void*, void*, void*, void*, void*, void*, void*, void*) __attribute__((pure,alloc));

    	typedef read_set = ![item,      (*0: first element of the read set*) 
    						 item, 	    (*1: last element of the read set*)
    						 item, 	    (*2: last checkpoint (element on short path)*)
    						 long];	    (*3: number of checkpoints in read set*)

        typedef mutWithK = ![any,    (*0: tag*)
                             any,    (*1: tvar*)
                             any,    (*2: contents read*)
                             item,   (*3: next pointer*)
                             any,    (*4: write set*)
                             any,    (*5: continuation*)
                             item];  (*6: next checkpoint pointer*)

        typedef stamp = VClock.stamp;
        typedef tvar = ![any, long, long]; (*contents, lock, version stamp*)

        define inline @get-stamp(/exh:exh) : stamp = 
            fun stampLoop() : long = 
                let current : long = VClock.@get(/exh)
                let lastBit : long = I64AndB(current, 1:long)
                if I64Eq(lastBit, 0:long)
                then return(current)
                else do Pause() apply stampLoop()
            let stamp : stamp = apply stampLoop()
            return(stamp)
        ;

        define @getPrintFunPtr = getPrintFunPtr;

        define @registerPrintFun(f : fun(any / exh -> unit) / exh:exh) : unit = 
            let funBox : ![fun(any / exh -> unit)] = @getPrintFunPtr(UNIT / exh)
            let f : fun(any / exh -> unit) = promote(f)
            do #0(funBox) := f
            return(UNIT);

    	define @new() : read_set = 
            let dummyTRef : ![any,long,long] = alloc(enum(0), 0:long, 0:long)
            let dummy : item = WithoutK(dummyTRef, enum(0), NilItem)
    		let rs : read_set = alloc(dummy, dummy, NilItem, 0:long)
    		return(rs)
    	;

        define inline @logStat(x:any / exh:exh) : () = 
#ifdef COLLECT_STATS                            
            let stats : list = FLS.@get-key(STATS_KEY / exh)
            let stats : list = CONS(x, stats)
            FLS.@set-key(STATS_KEY, stats / exh)
#else
            return()
#endif          
        ;

        define @sanity-check(readSet : read_set) : () =
            fun sanityLoop(i:item) : () = 
                case i 
                   of NilItem => return()
                    | WithK(tv:tvar,_:any,_:item,ws:item,k:cont(any),next:item) => 
                        let count : long = #1(tv)
                        do if Equal(k, enum(0))
                            then do ccall M_Print("Found null continuation on short path\n") return()
                            else return()
                        if I64Lte(count, 0:long)
                        then do ccall M_Print_Long2("Error: tvar on short path has %lu reference count, for tvar %lu\n", count, #2(tv)) apply sanityLoop(next)
                        else apply sanityLoop(next)
                end
            if Equal(readSet, enum(0))
            then return()
            else apply sanityLoop(#LASTK(readSet))
        ;

        define inline @decCounts(readSet : read_set / exh : exh) : () = 
            fun decLoop(i:item) : () = 
                case i 
                   of NilItem => return()
                    | WithK(tv:tvar, _:any, _:item, _:item, _:cont(any),next:item) => 
                        let _ : long = I64FetchAndAdd(&1(tv), ~1:long)
                        apply decLoop(next)
                    | _ => 
                        let casted : [any] = ([any]) i
                        do ccall M_Print_Long("decCounts: impossible! tag is %lu\n", #0(casted)) 
                        throw exh(Fail(@"decCounts: impossible\n"))
                end
            if Equal(readSet, enum(0))
            then return()
            else apply decLoop(#LASTK(readSet))
        ;

        define @short-path-len(readSet : read_set / exh:exh) : () = 
            fun lenLoop(i:item, count:long) : long = 
                case i 
                   of NilItem => return(count)
                    | WithK(tv:tvar, _:any, _:item, ws:item, k:cont(any), next:item) => 
                        apply lenLoop(next, I64Add(count, 1:long))
                    | WithoutK(tv:tvar, _:any, next:item) => 
                        do ccall M_Print("short-path-len: Impossible\n") return(0:long)
                end
            let l : long = apply lenLoop(#LASTK(readSet), 0:long)
            if I64Eq(l, #NUMK(readSet))
            then return()
            else 
                do ccall M_Print_Long2("Short path length is %d, should be %d\n", l, #NUMK(readSet))
                return()
        ;

        define inline @incCounts(readSet : read_set, sentinel : item / exh : exh) : () =
            fun incLoop(shortPath : item, i:int) : () = 
                case shortPath 
                   of NilItem => do ccall M_Print_Long("incCounts: This should be impossible, sentinel is %p\n", sentinel) return()
                    | WithK(tv:tvar, _:any, _:item, _:item, _:cont(any),next:item) => 
                        let _ : long = I64FetchAndAdd(&1(tv), 1:long)
                        if Equal(next, sentinel)
                        then 
                            let casted : mutWithK = (mutWithK) shortPath
                            do #NEXTK(casted) := NilItem
                            return()
                        else apply incLoop(next, I32Add(i, 1))
                    | _ => 
                        let casted : [any] = ([any]) shortPath
                        do ccall M_Print_Long("incCounts: Impossible! tag is %lu\n", #0(casted)) 
                        return()
                end
            let lastK : item = #LASTK(readSet)
            if Equal(lastK, sentinel)
            then do FLS.@set-key(FF_KEY, enum(0) / exh) return()  (*no checkpoints after violation*)
            else 
                do apply incLoop(lastK, 1)   (*increment reference counts for checkpoints after violation*)
                FLS.@set-key(FF_KEY, readSet / exh)
        ;


        define @abortABCD(readSet : read_set, checkpoint : item, startStamp : ![stamp, int], count:long, revalidate : fun(item, item, long / -> ) / exh:exh) : () = 
            case checkpoint 
               of NilItem => (*no checkpoint available*)
                    (*<FF>*)
                    let oldFFInfo : read_set = FLS.@get-key(FF_KEY / exh)
                    do @decCounts(oldFFInfo / exh)
                    do @incCounts(readSet, NilItem / exh)
                    (*</FF>*)
                    let abortK : cont() = FLS.@get-key(ABORT_KEY / exh)
                    throw abortK()
                | WithK(tv:tvar, _:any, next:item, ws:item, abortK:cont(any),_:item) => 
                    let casted : ![any, any, any, item] = (![any, any, any, item]) checkpoint
                    do #NEXT(casted) := NilItem
                    fun getLoop() : any = 
                        let v : any = #0(tv)
                        let t : long = VClock.@get(/exh)
                        if I64Eq(t, #0(startStamp))
                        then return(v)
                        else
                            let currentTime : stamp = @get-stamp(/exh)
                            do #0(startStamp) := currentTime
                            do apply revalidate(#HEAD(readSet), NilItem, 0:long)
                            apply getLoop()
                    let current : any = apply getLoop()
                    let newRS : read_set = alloc(#HEAD(readSet), checkpoint, checkpoint, count)
                    do FLS.@set-key(READ_SET, newRS / exh)
                    do FLS.@set-key(WRITE_SET, ws / exh)
                    (*<FF>*)
                    let oldFFInfo : read_set = FLS.@get-key(FF_KEY / exh)
                    do @decCounts(oldFFInfo / exh)
                    do @incCounts(readSet, checkpoint / exh)
                    (*</FF>*)
                    let captureFreq : int = FLS.@get-counter2()
                    do FLS.@set-counter(captureFreq)
                    BUMP_PABORT
                    throw abortK(current)
            end
        ;

        define @validate(readSet : read_set, startStamp:![stamp, int] / exh:exh) : () = 
            fun validateLoopABCD(rs : item, abortInfo : item, count:long) : () =
                case rs 
                   of NilItem => (*finished validating*)
                        let currentTime : stamp = VClock.@get(/exh)
                        if I64Eq(currentTime, #0(startStamp))
                        then return() (*no one committed while validating*)
                        else  (*someone else committed, so revalidate*)
                            let currentTime : stamp = @get-stamp(/exh)
                            do #0(startStamp) := currentTime
                            apply validateLoopABCD(#HEAD(readSet), NilItem, 0:long)
                    | WithoutK(tv:tvar, x:any, next:item) =>
                        if Equal(#0(tv), x)
                        then apply validateLoopABCD(next, abortInfo, count)
                        else @abortABCD(readSet, abortInfo, startStamp, count, validateLoopABCD / exh)
                    | WithK(tv:tvar,x:any,next:item,ws:item,abortK:any,_:item) =>
                        if Equal(#0(tv), x)
                        then 
                            if Equal(abortK, enum(0))
                            then apply validateLoopABCD(next, abortInfo, count)            (*update checkpoint*)
                            else apply validateLoopABCD(next, rs, I64Add(count, 1:long))
                        else
                            if Equal(abortK, enum(0))
                            then @abortABCD(readSet, abortInfo, startStamp, count, validateLoopABCD / exh)
                            else @abortABCD(readSet, rs, startStamp, I64Add(count, 1:long), validateLoopABCD / exh)
                end
            let currentTime : stamp = @get-stamp(/exh)
            do #0(startStamp) := currentTime
            apply validateLoopABCD(#HEAD(readSet), NilItem, 0:long)
        ;

        define @rs-len(readSet : read_set / exh:exh) : () =
            fun lenLoop(i:item, count:int) : int = 
                case i 
                   of NilItem => return(count)
                    | WithK(tv:tvar, _:any, next:item, ws:item, k:cont(any), _:item) => 
                        apply lenLoop(next, I32Add(count, 1))
                    | WithoutK(tv:tvar, _:any, next:item) => 
                        apply lenLoop(next, I32Add(count, 1))
                end
            let l : int = apply lenLoop(#HEAD(readSet), 0)
            do ccall M_Print_Int("Read set length is %d\n", l)
            return();

        define @ff-finish(readSet : read_set, checkpoint : item, i:long / exh:exh) : () =
            case checkpoint 
               of WithK(tv:tvar,x:any,_:item,ws:item,k:cont(any),next:item) => 
                    let casted : mutWithK = (mutWithK) checkpoint
                    do #NEXT(casted) := NilItem
                    let newRS : read_set = alloc(#0(readSet), checkpoint, checkpoint, i)
                    do FLS.@set-key(READ_SET, newRS / exh)
                    do FLS.@set-key(WRITE_SET, ws / exh)
                    BUMP_KCOUNT
                    throw k(x)
                | _ => throw exh(Fail(@"Impossible: ff-finish\n"))
            end
        ;

        define @ff-validate(readSet : read_set, oldRS : item, myStamp : ![long,int] / exh:exh) : () = 
            fun ffLoop(rs:item, i:long, checkpoint : item) : () = 
                case rs
                   of NilItem => @ff-finish(readSet, checkpoint, i / exh)
                    | WithoutK(tv:tvar, x:any, next:item) => 
                        if Equal(#0(tv), x)
                        then apply ffLoop(next, i, checkpoint)
                        else @ff-finish(readSet, checkpoint, i / exh)
                    | WithK(tv:tvar,x:any,next:item,ws:item,k:cont(any),_:item) => 
                        if Equal(#0(tv), x)
                        then
                            if Equal(k, enum(0))
                            then apply ffLoop(next, i, checkpoint)
                            else apply ffLoop(next, I64Add(i, 1:long), rs)
                        else 
                            if Equal(k, enum(0))
                            then @ff-finish(readSet, checkpoint, i / exh)
                            else
                                let newRS : read_set = alloc(#0(readSet), rs, rs, I64Add(i, 1:long))
                                fun getLoop() : any = 
                                    let v : any = #0(tv)
                                    let t : long = VClock.@get(/exh)
                                    if I64Eq(t, #0(myStamp))
                                    then return(v)
                                    else
                                        do @validate(newRS, myStamp / exh)
                                        apply getLoop()
                                do FLS.@set-key(READ_SET, newRS / exh)
                                do FLS.@set-key(WRITE_SET, ws / exh)
                                let casted : mutWithK = (mutWithK) rs
                                do #NEXT(casted) := NilItem
                                let current : any = apply getLoop()
                                throw k(current)
                end
            apply ffLoop(oldRS, #NUMK(readSet), oldRS)
        ;

        define @fast-forward(readSet : read_set, writeSet : item, tv:tvar, retK:cont(any), myStamp : ![long, int] / exh:exh) : () = 
            let ffInfo : read_set = FLS.@get-key(FF_KEY / exh)
            if Equal(ffInfo, enum(0))
            then return()
            else (*we should only allocate the checkRS closure if we are going to actually use it*)
                fun checkRS(rs:item, i:long) : () = 
                    case rs 
                       of NilItem =>  return()
                        | WithK(tv':tvar,_:any,_:item,ws:item,k:cont(any),next:item) => 
                            INC_FF(1:long)
                            if Equal(tv, tv')
                            then (*tvars are equal*)
                                let res : int = ccall M_PolyEq(k, retK)
                                if I32Eq(res, 1)
                                then (*continuations are equal*)
                                    if Equal(ws, writeSet) 
                                    then (*continuations, write sets, and tvars are equal, fast forward...*)
                                        do @decCounts(ffInfo / exh)  (*decrement counts for everything on short path of ffInfo*)
                                        do FLS.@set-key(FF_KEY, enum(0) / exh)  (*null out fast forward info*)
                                        (*hook the two read sets together*)
                                        let ffFirstK : mutWithK = (mutWithK) rs
                                        do #NEXTK(ffFirstK) := #LASTK(readSet) 
                                        let currentLast : item = #TAIL(readSet)
                                        let currentLast : mutWithK = (mutWithK) currentLast
                                        do #NEXT(currentLast) := rs
                                        (*add to remember set*)
                                        let vp : vproc = host_vproc
                                        let rememberSet : any = vpload(REMEMBER_SET, vp)
                                        let newRemSet : [mutWithK, int, [mutWithK, int, any]] = alloc(ffFirstK, NEXTK, alloc(currentLast, NEXT, rememberSet))
                                        do vpstore(REMEMBER_SET, vp, newRemSet)
                                        @ff-validate(readSet, rs, myStamp / exh)
                                    else apply checkRS(next, I64Add(i, 1:long))
                                else apply checkRS(next, I64Add(i, 1:long))
                            else apply checkRS(next, I64Add(i, 1:long))
                        | _ => throw exh(Fail("checkRS: impossible\n"))
                    end
                apply checkRS(#LASTK(ffInfo), 1:long)
        ;

        define @c-fast-forward(readSet : read_set, writeSet : item, tv:tvar, retK:cont(any), myStamp : ![long, int] / exh:exh) : () = 
            let ffInfo : read_set = FLS.@get-key(FF_KEY / exh)
            if Equal(ffInfo, enum(0))
            then return()
            else 
                let clock : ![stamp] = VClock.@get-boxed(/exh)
                let vp : vproc = host_vproc
                let ffRes : read_set = ccall fastForward(readSet, ffInfo, writeSet, tv, retK, myStamp, clock, vp)
                if Equal(ffRes, UNIT)
                then return()
                else 
                    case #LASTK(ffRes)
                       of NilItem => 
                            let abortK : cont() = FLS.@get-key(ABORT_KEY / exh)
                            throw abortK()
                        | WithK(tv:tvar,x:any,_:item,ws:item,k:cont(any),next:item) => 
                            do FLS.@set-key(READ_SET, ffRes / exh)
                            do FLS.@set-key(WRITE_SET, ws / exh)
                            do FLS.@set-key(FF_KEY, enum(0) / exh)
                            do ccall M_Print_Long("About to throw to k (Address %p)\n", k)
                            throw k(x)
                    end
        ;


        define inline @getNumK(rs : read_set) : long = return(#NUMK(rs));

        

        define inline @filterRS(readSet : read_set / exh : exh) : () = 
            fun dropKs(l:item, n:long) : long =   (*drop every other continuation*)
                case l
                   of NilItem => return(n)
                    | WithK(_:any,_:any,_:item,_:item,_:cont(any),next:item) =>
                        case next
                           of NilItem => return(n)
                            | WithK(tv:tvar,_:any,_:item,_:item,_:cont(any),nextNext:item) =>
                                (* NOTE: if compiled with -debug, this will generate warnings
                                 * that we are updating a bogus local pointer, however, given the
                                 * nature of the data structure, we do preserve the heap invariants*)
                                let l : mutWithK = (mutWithK) l
                                let next : mutWithK = (mutWithK) next
                                do #KPOINTER(next) := enum(0):any
                                do #NEXTK(l) := nextNext
                                apply dropKs(nextNext, I64Sub(n, 1:long))
                            | _ => 
                                let casted : [any, any, any] = ([any, any, any])next
                                do ccall M_Print_Long("filterRS (inner case): Impossible, tag is %lu\n", #0(casted)) 
                                throw exh(Fail(@"filterRS: impossible"))
                        end
                    | _ => 
                        let casted : [any, any, any] = ([any, any, any])l
                        do ccall M_Print_Long("filterRS: Impossible, tag is %lu\n", #0(casted)) 
                        throw exh(Fail(@"filterRS: impossible"))
                end
            let x : long = apply dropKs(#LASTK(readSet), #NUMK(readSet))
            do #NUMK(readSet) := x
            return();


        (*Note that these next two defines, rely on the fact that a heap limit check will not get
         *inserted within the body*)
        (*Add a checkpointed read to the read set*)
        define @insert-with-k(tv:tvar, v:any, k:cont(any), ws:item, readSet : read_set / exh:exh) : () = 
            let newItem : item = WithK(tv, v, NilItem, ws, k, #LASTK(readSet))
            let vp : vproc = host_vproc
            let nurseryBase : long = vpload(NURSERY_BASE, vp)
            let limitPtr : long = vpload(LIMIT_PTR, vp)
            let lastAddr : any = (any) #TAIL(readSet)
            let casted : ![any,any,item,item] = (![any,any,item,item])lastAddr
            if I64Gte(lastAddr, nurseryBase)
            then
                if I64Lt(lastAddr, limitPtr)
                then (*last item is still in nursery*)
                    do #NEXT(casted) := newItem
                    do #TAIL(readSet) := newItem
                    do #LASTK(readSet) := newItem
                    do #NUMK(readSet) := I64Add(#NUMK(readSet), 1:long)
                    return()
                else (*not in nursery, add last item to remember set*)
                    let newRS : read_set = alloc(#HEAD(readSet), newItem, newItem, I64Add(#NUMK(readSet), 1:long))
                    let rs : any = vpload(REMEMBER_SET, vp)
                    let newRemSet : [![any,any,item,item], int, any] = alloc(casted, NEXT, rs)
                    do vpstore(REMEMBER_SET, vp, newRemSet)
                    do #NEXT(casted) := newItem
                    do FLS.@set-key(READ_SET, newRS / exh)
                    return()
            else (*not in nursery, add last item to remember set*)
                let newRS : read_set = alloc(#HEAD(readSet), newItem, newItem, I64Add(#NUMK(readSet), 1:long))
                let rs : any = vpload(REMEMBER_SET, vp)
                let newRemSet : [![any,any,item,item], int, any] = alloc(casted, NEXT, rs)
                do vpstore(REMEMBER_SET, vp, newRemSet)
                do #NEXT(casted) := newItem
                do FLS.@set-key(READ_SET, newRS / exh)
                return()
        ;

        define @printHeader(tv:any) : () = 
            let header : any = ArrLoad(tv, ~1)
            do ccall M_Print_Long("Header is %lu\n", header)
            return();

        (*add a non checkpointed read to the read set*)
    	define @insert-without-k(tv:any, v:any, readSet : read_set / exh:exh) : () =
    		let newItem : item = WithoutK(tv, v, NilItem)
    		let vp : vproc = host_vproc
    		let nurseryBase : long = vpload(NURSERY_BASE, vp)
            let limitPtr : long = vpload(LIMIT_PTR, vp)
            let lastAddr : any = (any) #TAIL(readSet)
            let casted : ![any,any,any,item] = (![any,any,any,item]) lastAddr
            if I64Gte(lastAddr, nurseryBase)
            then
                if I64Lt(lastAddr, limitPtr)
                then (*last item is still in nursery*)
                    do #NEXT(casted) := newItem
                    do #TAIL(readSet) := newItem
                    return()
                else (*not in nursery, add last item to remember set*)
                    let newRS : read_set = alloc(#HEAD(readSet), newItem, #LASTK(readSet), #NUMK(readSet))
                    let rs : any = vpload(REMEMBER_SET, vp)
                    let newRemSet : [![any,any,item,item], int, any] = alloc(casted, NEXT, rs)
                    do vpstore(REMEMBER_SET, vp, newRemSet)
                    do #NEXT(casted) := newItem
                    do FLS.@set-key(READ_SET, newRS / exh)
                    return()
            else (*not in nursery, add last item to remember set*)
                let newRS : read_set = alloc(#HEAD(readSet), newItem, #LASTK(readSet), #NUMK(readSet))
                let rs : any = vpload(REMEMBER_SET, vp)
                let newRemSet : [![any,any,item,item], int, any] = alloc(casted, NEXT, rs)
                do vpstore(REMEMBER_SET, vp, newRemSet)
                do #NEXT(casted) := newItem
                do FLS.@set-key(READ_SET, newRS / exh)
                return()
        ;
        
        define @new-w(x:unit / exh:exh) : read_set = 
            let firstElem : item = WithoutK(alloc(~1), enum(0), NilItem)
            let rs : read_set = alloc(firstElem, firstElem, firstElem, 0:long)
            return(rs);

        define @insert-w(arg : [any, read_set] / exh:exh) : read_set = 
            do @insert-without-k(#0(arg), enum(0), #1(arg) / exh)
            let new : read_set = FLS.@get-key(READ_SET / exh)
            return(new);

        define @printRS(arg : [read_set, fun(any / exh -> unit)] / exh:exh) : unit =
            let rs : read_set = #0(arg)
            let f : fun(any / exh -> unit) = #1(arg)
            fun printLoop(i:item) : unit = 
                case i 
                   of NilItem => return(UNIT)
                    | WithoutK(hd:any, _:any, tl:item) => 
                        let _ : unit = apply f(hd / exh)
                        apply printLoop(tl)
                end
            apply printLoop(#0(rs));

        define @check-count(tv : any / exh:exh) : unit = 
            let tv : tvar = (tvar) tv
            do ccall M_Print_Long("referece count is %lu\n", #1(tv))
            return(UNIT)
        ;
    )
    val registerPrintFun : ('a -> unit) -> unit = _prim(@registerPrintFun)

    type 'a read_set = _prim(read_set)
    val new : unit -> 'a read_set = _prim(@new-w)
    val insert : 'a * 'a read_set -> 'a read_set = _prim(@insert-w)
    val printRS : 'a read_set * ('a -> unit) -> unit = _prim(@printRS)

    val checkCount : 'a -> unit = _prim(@check-count)
end



