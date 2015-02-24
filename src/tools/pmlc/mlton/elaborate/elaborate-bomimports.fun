functor ElaborateBOMImports (S: ELABORATE_BOMIMPORTS_STRUCTS): ELABORATE_BOMIMPORTS
  = struct
  open S
  structure BOM = Ast.BOM
  structure MLType = Env.TypeEnv.Type
  structure MLScheme = Env.TypeEnv.Scheme
  structure MLTycon = Env.TypeEnv.Tycon
  (* structure TypeOps = Env.TypeEnv.Type.Ops *)

  local
    fun printMLObj doLayout (obj, msg) =
      print (msg ^ (Layout.toString (doLayout obj)) ^ "\n")
  in
    val printMLTy = printMLObj MLType.layout
  end



  fun translateType (mlTyEnv: BOMEnv.MLTyEnv.t)
      (mlType: MLType.t): CoreBOM.BOMType.t =
    let
      fun applyCon (tyc: MLTycon.t, tyvec: MLType.t vector): CoreBOM.BOMType.t =
        case BOMEnv.MLTyEnv.lookupThis (mlTyEnv, tyc) of
          SOME bomTyc =>
            (case (bomTyc (Vector.map (translateType mlTyEnv) tyvec)) of
              SOME bomTy => bomTy
            | NONE => raise Fail "Bad application.")
        | NONE => raise Fail "Unmapped type."

      and translateCon (mlType: MLType.t): CoreBOM.BOMType.t =
        let
            (* DEBUG *)
          val _ = printMLTy (mlType, "unwrapping ty: ")
        in
          case (MLType.deConOpt mlType) of
            SOME (tyc, tyvec) => applyCon (tyc, tyvec)
          | NONE => raise Fail "Bad type."
        end
    in
      translateCon mlType
    end


  fun elaborateBOMImport (import, {env: Env.t, bomEnv: BOMEnv.t}, mlTyEnv) =
    let
      fun elaborateMLType ty = ElaborateCore.elaborateType (ty,
        ElaborateCore.Lookup.fromEnv env)
      local
          (* FIXME: this can probably be removed *)
        fun resolve doResolve (mlId, maybeId): CoreBOM.BOMId.t =
          case maybeId of
            SOME bomId => CoreBOM.BOMId.fromAst bomId
          | NONE => doResolve mlId
        (* fun resolveToBOMId doResolve idPair = resolve doResolve idPair *)
      in
        fun resolveValId (doResolve) (idPair): CoreBOM.ValId.t  =
          CoreBOM.ValId.fromBOMId' (resolve doResolve idPair)

      fun extendEnvs (tyargs, tyc, maybeId) =
        let
          (* Translate the ML types from the AST representation *)
          val maybeTyStr =
            case Env.lookupLongtycon (env, tyc) of
              SOME tyStr => SOME (tyStr)
            | NONE => NONE
          val tyId =
            CoreBOM.TyId.fromBOMId' (case maybeId of
              SOME astId => CoreBOM.BOMId.fromAst astId
            | NONE => CoreBOM.BOMId.fromLongtycon tyc)

          val maybeTycs =
            case maybeTyStr of
              (* Only datatypes can be imported, and we ignore their
              constructors since they must be explicitly imported *)
              SOME (tyStr) =>
                (* Apply the tycon to the provided arguments *)
                SOME (tyStr, CoreBOM.TyCon.TyC {
                  (* FIXME: this is probably WRONG for typarams *)
                  id = tyId, definition = ref [], params = (List.tabulate (
                    Vector.length tyargs, fn _ => CoreBOM.TyParam.new ()))})
             (* FIXME: better error handling *)
              | _ => NONE
        in
          case maybeTycs of
            SOME (tyStr, bomTyc) =>
              let
                  (* FIXME: error handling *)
                val (Env.TypeStr.Datatype {tycon,...}) =
                  Env.TypeStr.node tyStr
                (* First, we put the new tyc into the mapping *)
                val mlTyEnv' = BOMEnv.MLTyEnv.extendThis (mlTyEnv,
                  tycon, fn args => CoreBOM.TyCon.applyToArgs' (bomTyc, args))
                val bomEnv' = BOMEnv.TyEnv.extend (bomEnv, tyId,
                  BOMEnv.TypeDefn.newCon bomTyc)

                (* Apply it to the constructors we were given *)
                val mlTy = Env.TypeStr.apply (tyStr, tyargs)
                (* No params by this point *)
                val bomTy = translateType mlTyEnv' mlTy

                val bomEnv' = BOMEnv.TyEnv.extend (bomEnv', tyId,
                  BOMEnv.TypeDefn.newAlias {params = [], ty = bomTy})
              in
                SOME (bomEnv', mlTyEnv', bomTyc, bomTy)
              end
            | NONE => NONE
        end
      end

      fun translateCon (mlTyEnv, bomResultTy, tyargs) importCon =
        let
            (* FIXME: let's ignore the maybeTy for now *)
          val BOM.ImportCon.T (longcon, maybeTy, maybeId) =
            BOM.ImportCon.node importCon

          val (con, maybeScheme) = Env.lookupLongcon (env, longcon)
          (* FIXME: better error handling *)
          val SOME tyScheme = maybeScheme
          val mlTy = MLScheme.apply (tyScheme, tyargs)

          (* DEBUG *)
          val _ = print ("Env: " ^ (Layout.toString (Env.layout env )) ^ "\n")
          val _ = print ("Con: " ^
            (Layout.toString (Ast.Longcon.layout longcon)) ^ "\n")
          val _ = print ("Scheme: " ^ (Layout.toString (MLScheme.layout (
            Option.valOf maybeScheme))) ^ "\n")


          val newValId = resolveValId CoreBOM.BOMId.fromLongcon (longcon, maybeId)
          val bomConTy =
            case MLType.deArrowOpt mlTy of
              (* MLton doesn't distinguish between arrow and
              constructors here, so we have to handle this as a
              special case *)
              SOME (dom, rng) => CoreBOM.BOMType.Con {
                dom = translateType mlTyEnv dom,
                rng = translateType mlTyEnv rng
              }
           | NONE => translateType mlTyEnv mlTy

          val _ =
            if CoreBOM.BOMType.equal (bomResultTy,
              case bomConTy of
                CoreBOM.BOMType.Con {rng,...} => rng
              | tycon as (CoreBOM.BOMType.TyCon tycon') => tycon
              | CoreBOM.BOMType.Error => raise Fail "Con wasn't found in env."
              | _ => raise Fail "Type is not a con.")
            then ()
            else raise Fail "Bad con application."
        in
            (* FIXME: never any params in imports? *)
          (newValId, CoreBOM.Val.new (newValId, bomConTy, []))
        end
    in
      case BOM.Import.node import of
        BOM.Import.Val (vid, ty, maybeId) =>
          let
            val ty' = elaborateMLType ty
            (* FIXME: not sure what to do with this scheme *)
            val (vid', maybeScheme) = Env.lookupLongvid (env, vid)
            val success = ref true
            val _ =
              case maybeScheme of
                (* FIXME: preError? *)
                (* FIXME: real error message? *)
                SOME scheme => MLType.unify (ty', #instance (MLScheme.instantiate
                    scheme), {
                  (* FIXME: real region *)
                  error = fn (l, r) => Control.error (Region.bogus, l, r),
                  preError = fn () => success := false})
               (* FIXME: error message *)
              | NONE => success := false
            val newTy = translateType mlTyEnv ty'
            (* QUESTION: Will we ever create a new type via a val
             import? *)
            (* remove qualifying module, make a BOMId *)
            val newValId = resolveValId CoreBOM.BOMId.fromLongvid (vid, maybeId)
          in
            (if !success then
              (* If it worked (vid was bound to a type that could
              unify with ty), put the new ty into our env and bind our
              new valId to it *)
              (* we never have typarams on a val from ML code *)
              BOMEnv.ValEnv.extend (bomEnv, newValId,
                CoreBOM.Val.new (newValId, newTy, []))
            else
              (* Otherwise, return the env unchanged (errors have
              already been logged above) *)
              bomEnv, mlTyEnv)
          end
      | BOM.Import.Datatype (tyargs, tyc, maybeId, cons) =>
          let
            fun extendBOMEnv ((valId, bomVal), bomEnv) =
              BOMEnv.ValEnv.extend (bomEnv, valId, bomVal)

            val tyargs' = Vector.map elaborateMLType tyargs

             (* FIXME: error handling *)
            val SOME (bomEnv', mlTyEnv', bomTyc, bomTy) =
              extendEnvs (tyargs', tyc, maybeId)
            val cons' = map (translateCon (mlTyEnv', bomTy, tyargs')) cons

            (* Add the constructors to the tycon *)
            val _ = (fn (CoreBOM.TyCon.TyC {definition,...}) =>
              definition := map (fn (valId, bomVal) =>  CoreBOM.ConsDef (
                CoreBOM.ValId.truncateToBOMId valId,
                SOME (CoreBOM.Val.typeOf bomVal))) cons') bomTyc

            val bomEnv' = foldl (fn ((valId, bomVal), bomEnv) =>
             BOMEnv.ValEnv.extend (bomEnv, valId, bomVal)) bomEnv' cons'

          in
            (bomEnv', mlTyEnv')
          end

            (* NOTE: do we want to reject all but the datatype type strs? *)
      | BOM.Import.Exn (tyc, maybeTy, maybeId) => raise Fail "not implemented"
    end
end
