(* Copyright (C) 1999-2005 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a BSD-style license.
 * See the file MLton-LICENSE for details.
 *)

functor Elaborate (S: ELABORATE_STRUCTS): ELABORATE =
struct

open S

structure Env = ElaborateEnv (structure Ast = Ast
                              structure CoreML = CoreML
                              structure TypeEnv = TypeEnv)

local
   open Env
in
   structure Decs = Decs
end

structure CoreBOM = CoreBOM (
  structure Ast = Ast)
structure BOMEnv = BOMEnv (
  structure Ast = Ast
  structure CoreBOM = CoreBOM)



structure ElaborateMLBs = ElaborateMLBs (structure Ast = Ast
                                         structure CoreML = CoreML
                                         structure CoreBOM = CoreBOM
                                         structure Decs = Decs
                                         structure Env = Env
                                         structure BOMEnv = BOMEnv)

open ElaborateMLBs
end
