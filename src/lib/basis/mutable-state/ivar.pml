(* ivar.pml
 *
 * COPYRIGHT (c) 2013 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * I-Structures
 *)

#include "spin-lock.def"
#include "debug.def"

structure IVar = (*
sig
    type 'a ivar
    val new : () -> 'a ivar
    val put : ('a ivar * 'a) -> ()
    val get : 'a ivar -> 'a
end*)
struct

    _primcode(
        extern void *M_Print_Int(void *, int);

        typedef tid = ![
            int,           (*Size of the list*)
            List.list];    (*thread id*)  
            
        typedef waiter = ![
            vproc,         (*0: vproc affinity*)
            FLS.fls,       (*1: fiber local storage*)
            cont(any, any),     (*2: thread's continuation*)
            tid,            (*3: thread id*)
            Cancelation.cancelable];  (*4: cancelable*)        
    
        typedef ivar = ![
            int,           (*0: spin lock*)
            bool,          (*1: speculative?*)
            any,           (*2: value*)
            bool,          (*3: full?*)
            List.list,     (*4: list of waiters if this is empty*)
            List.list,     (*5: restart info*)
            any,           (*6: thread id*)
            List.list      (*7: list of writers if this is spec full*)];

        define @pmlInd(w : waiter, ws : List.list / exh : exh) : List.list = 
            fun prefixEq(tid1 : List.list, tid2 : List.list) : bool = case tid1 
                of CONS(hd1 : [int], tl1 : List.list) => case tid2
                    of CONS(hd2 : [int], tl2 : List.list) => if I32Eq(#0(hd1), #0(hd2)) then apply prefixEq(tl1, tl2) else return(false)
                     | nil => let e : exn = Fail(@"Impossible") throw exh(e)
                    end
                  |nil => case tid2
                    of CONS(_ : [int], _ : List.list) => let e : exn = Fail(@"Impossible") throw exh(e)
                     | nil => return(true)
                  end
                end
            fun prefix(tid1 : tid, tid2 : tid) : bool = 
                let n1 : int = #0(tid1)
                let n2 : int = #0(tid2)
                let l1 : List.list = #1(tid1)
                let l2 : List.list = #1(tid2)
                if I32Eq(n1, n2)
                then apply prefixEq(l1, l2)
                else if I32Gt(n1, n2) 
                     then return(false)
                     else case l2
                        of CONS(hd1 : [int], tl1 : List.list) => let tid2' : ![int, List.list] = alloc(I32Sub(n2, 1), tl1)
                            apply prefix(tid1, tid2')
                          |nil => return(false)
                        end
            fun ind(ws : List.list) : List.list = case ws 
                of CONS(w1 : waiter, tl : List.list) => 
                    let prefixRes : bool = apply prefix(#3(w1), #3(w))
                    if (prefixRes)
                    then do ccall M_Print("Not adding item to working set!\n")
                         return(ws)
                    else let prefixRes2 : bool = apply prefix(#3(w), #3(w1))
                         if (prefixRes2)
                         then apply ind(tl)
                         else let res : List.list = apply ind(tl)
                              return(CONS(w1, res))
                |nil => do ccall M_Print("Adding item to working set!\n")
                        return(CONS(w, nil))
                end
           apply ind(ws)
        ;

        define @printTID2(tid : tid / exh : exh) : () = 
            do ccall M_Print("TID: ")
            fun helper(tid : List.list) : () = 
                case tid
                    of CONS(hd : [int], tail : List.list) => 
                        do apply helper(tail)
                        do ccall M_Print(", ")
                        do ccall M_PrintInt(#0(hd))
                        return()
                    | nil => return()
                end
            do apply helper(#1(tid))
            do ccall M_Print("\n")
            return()
        ;

        define @printTID(/exh : exh) : () = 
            let tid : any = FLS.@get-key(alloc(TID_KEY) / exh)
            let tid : tid = (tid) tid
            @printTID2(tid/exh)
        ;

        define @iNew( x : unit / exh : exh) : ivar =
            let x : ivar = alloc(0, false, $0, false, nil, nil, $0, nil)
            let x : ivar = promote(x)
            return (x);

        define @getCancelable(/exh : exh) : Cancelation.cancelable = 
            let ite : FLS.ite = FLS.@get-ite(/exh)
            let c : Option.option = #1(ite)
            case c 
                of Option.SOME(c' : Cancelation.cancelable) => return(c')
                 | Option.NONE => do ccall M_Print("Error in ivar.pml: no cancelation!\n")
                                  let e : exn = Fail(@"Error: no cancelation in ivar.pml\n")
                                  throw exh(e)
            end
        ;

        define @iGet(i : ivar / exh : exh) : any = 
        fun restart() : any = 
            let self : vproc = SchedulerAction.@atomic-begin()
            SPIN_LOCK(i, 0)
            if Equal(#3(i), true) (*full*)
            then if Equal(#1(i), true)  (*spec full*)
                 then cont getK (x : unit, x : unit) = apply restart()
                      do ccall M_Print("Reading speculatively full ivar\n")
                      let fls : FLS.fls = FLS.@get-in-atomic(self)
                      let tid : any = FLS.@get-key(alloc(TID_KEY) / exh)
                      let affinity : vproc = host_vproc
                      let c : Cancelation.cancelable = @getCancelable(/exh)
                      let item : waiter = alloc(affinity, fls, getK, (tid) tid, c)
                      let l : List.list = CONS(item, #5(i))
                      let l : List.list = promote(l)
                      do #5(i) := l  
                      SPIN_UNLOCK(i, 0)
                      do SchedulerAction.@atomic-end(self)
                      return(#2(i))
                 else SPIN_UNLOCK(i, 0)   (*commit full*)
                      do SchedulerAction.@atomic-end(self)
                      do ccall M_Print("Reading commit full ivar\n")
                      return (#2(i)) 
            else cont getK'(x : any, s : bool) = (*empty*)
                    if Equal(s, true) (*previously read empty, check if its now spec full*)
                    then let self : vproc = SchedulerAction.@atomic-begin()
                         SPIN_LOCK(i, 0)
                         do ccall M_Print("Reading speculatively full ivar\n")
                         cont getK''(x : unit, x : unit) = apply restart()
                         let fls : FLS.fls = FLS.@get-in-atomic(self)
                         let tid : any = FLS.@get-key(alloc(TID_KEY) / exh)
                         let affinity : vproc = self
                         let c : Cancelation.cancelable = @getCancelable(/exh)
                         let item : waiter = alloc(affinity, fls, getK'', (tid) tid, c)
                         let l : List.list = CONS(item, #5(i))
                         let l : List.list = promote(l)
                         do #5(i) := l
                         SPIN_UNLOCK(i, 0)
                         do SchedulerAction.@atomic-end(self)
                         return(x)
                    else return(x)
                 do ccall M_Print("Reading from empty ivar\n")
                 let fls : FLS.fls = FLS.@get-in-atomic(self)
                 let tid : any = FLS.@get-key(alloc(TID_KEY) / exh)
                 let c : Cancelation.cancelable = @getCancelable(/exh)
                 let item : waiter = alloc(self, fls, getK', (tid) tid, c)
                 let l : list = CONS(item, #4(i))
                 let l : list = promote(l)
                 do #4(i) := l
                 SPIN_UNLOCK(i, 0)
                 SchedulerAction.@stop-from-atomic(self)
        apply restart()         
        ;

        define @iPut(arg : [ivar, any] / exh : exh) : unit = 
            let i : ivar = #0(arg)
            let v : any = #1(arg)
            let v : any = promote(v)
            let self : vproc = SchedulerAction.@atomic-begin()
            let spec : any = FLS.@get-key(alloc(SPEC_KEY) / exh)
            let spec : bool = (bool)spec
            fun restart (waiters : List.list) : unit = case waiters
                of nil => return (UNIT)
                 | CONS(hd : waiter, tl : List.list) => 
                      do ccall M_Print("Restarting blocked reader\n")
                      let k : cont(any, any) = #2(hd)
                      cont takeK(_ : unit) = throw k (v, spec)
                      do VProcQueue.@enqueue-on-vproc(#0(hd), #1(hd), takeK) 
                      apply restart(tl)
                 end
            SPIN_LOCK(i, 0)
            if Equal(#3(i), true) (*already full*)
            then if Equal(spec, true)
                 then SPIN_LOCK(i, 0)  (*this write is speculative*)
                      cont getK(x : unit, x : unit) = 
                        do #2(i) := v    (*value*)
                        do #1(i) := true (*still spec full until committed*)
                        do #3(i) := true (*full*)      
                        let readers : List.list = #4(i)
                        do #4(i) := nil
                        let _ : unit = apply restart(#4(i))
                        return(UNIT)                  
                      let fls : FLS.fls = FLS.@get-in-atomic(self)
                      let tid : any = FLS.@get-key(alloc(TID_KEY) / exh)
                      let c : Cancelation.cancelable = @getCancelable(/exh)
                      let item : waiter = alloc(self, fls, getK, (tid) tid, c)
                      let item : waiter = promote(item)
                      let l : List.list = CONS(item, #5(i))
                      let l : List.list = promote(l)
                      do #5(i) := l
                      SPIN_UNLOCK(i, 0)
                      SchedulerAction.@stop-from-atomic(self)
                 else SPIN_UNLOCK(i, 0)
                      do SchedulerAction.@atomic-end(self)
                      do ccall M_Print("Attempt to write to full IVar, exiting...\n")
                      let e : exn = Fail(@"Attempt to write to full IVar")
                      throw exh(e)
            else let blocked : List.list = #4(i)
                 do #4(i) := nil
                 SPIN_UNLOCK(i, 0)
                 do #2(i) := v    (*value field*)
                 do #1(i) := spec (*spec field*)
                 do #3(i) := true (*full field*)
                 let writes : ![List.list] = FLS.@get-key(alloc(WRITES_KEY) / exh)
                 let newWrites : List.list = promote(CONS(i, #0(writes)))
                 do #0(writes) := newWrites
                 do ccall M_Print("Writing to ivar\n")
                 apply restart (blocked)
        ;

        (*cases:
            1) ivar is already commit full -> raise error
            2) ivar is spec full -> replace the value with this one and restart dependants
            3) ivar is empty -> not possible
        *)
        define @commit(writes : List.list/ exh:exh) : () = 
            fun helper(ws : List.list) : () = case ws
                of nil => return()
                 | CONS(hd : ivar, tl : List.list) => 
                    if Equal(#1(hd), true) (*speculative?*)
                    then if Equal(#3(hd), true) (*full?*)
                         then return()
                         else return()
                    else return ()
                end
            apply helper(writes)
       ;

       (*Takes a list of ivars that need to be rolled back, and a working set
         of computations to be restarted (initially nil)*)
       define @rollback(writes : List.list / exh : exh) : () = 
            fun helper(writes : List.list, workingSet : List.list) : List.list = case writes
                of nil => return(workingSet)
                 | CONS(hd : ivar, tl : List.list) => 
                    do ccall M_Print("Rolling back IVar\n")
                    do #3(hd) := false (*set to empty*)
                    let dependents : List.list = #5(hd)
                    do #5(hd) := nil
                    do #7(hd) := nil
                    let newWS : List.list = apply procDependents(dependents, tl, workingSet)
                    return(newWS)
                 end
            and procDependents(deps : List.list, ivars : List.list, workingSet : List.list) : List.list = case deps
                of nil => apply helper(ivars, workingSet)
                 | CONS(hd : waiter, tl : List.list) => 
                    let workingSet' : List.list = @pmlInd(hd, workingSet / exh)
                    let fls : FLS.fls = #1(hd)
                    let fls : FLS.fls = promote(fls)
                    let ws : ![List.list] = FLS.@get-key-dict(fls, alloc(WRITES_KEY) / exh)
                    let wsLength : int = PrimList.@length(#0(ws)/exh)
                    let ivars' : List.list = PrimList.@append(#0(ws), writes / exh)
                    apply procDependents(tl, ivars', workingSet')
                end
            let restarts : List.list = apply helper(writes, nil)
            fun restart (waiters : List.list) : () = case waiters
                    of nil => return ()
                     | CONS(waiter : waiter, tl : List.list) => 
                          do ccall M_Print("Restarting dependent reader\n")
                          let c : Cancelation.cancelable = #4(waiter)
                          let _ : unit = Cancelation.@cancel(c / exh)
                          let k : cont(any, any) = #2(waiter)
                          cont takeK(_ : unit) = throw k (UNIT, UNIT)
                          do VProcQueue.@enqueue-on-vproc(#0(waiter), #1(waiter), takeK)
                          apply restart(tl)
                     end
            apply restart(restarts)
       ;    
       
    )
    
    type 'a ivar = _prim(ivar)
    val newIVar : unit -> 'a ivar = _prim(@iNew)
    val getIVar : 'a ivar -> 'a = _prim(@iGet)
    val putIVar : ('a ivar * 'a) -> unit = _prim(@iPut)
    
end




