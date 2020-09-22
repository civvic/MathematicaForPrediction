(*
    Maybe monad code generator Mathematica package
    Copyright (C) 2017  Anton Antonov

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Written by Anton Antonov,
    antononcube @ gmail.com,
    Windermere, Florida, USA.
*)

(*
    Mathematica is (C) Copyright 1988-2017 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)

(* :Title: MaybeMonadCodeGenerator *)
(* :Context: MaybeMonadCodeGenerator` *)
(* :Author: Anton Antonov *)
(* :Date: 2017-06-11 *)

(* :Package Version: 0.1 *)
(* :Mathematica Version: *)
(* :Copyright: (c) 2017 Anton Antonov *)
(* :Keywords: *)
(* :Discussion:


    The code of this package is mostly made for demonstration purposes.

    To generate the "standard" Maybe monad code use the command:

        GenerateMaybeMonadCode["Maybe", "FailureSymbol" -> None ]

    Illustrative special functions can be generated with :

        GenerateMaybeMonadSpeciaCode["Maybe", "FailureSymbol" -> None ]


    This file was created by Mathematica Plugin for IntelliJ IDEA.

    Anton Antonov
    Windermere, FL, USA
    2017-06-11

*)

BeginPackage["MaybeMonadCodeGenerator`"]
(* Exported symbols added here with SymbolName::usage *)

GenerateMaybeMonadCode::usage = "GenerateMaybeMonadCode[monadName_String] generates the basic functions \
of a Maybe monad that allows sequential computations with optional failure. \
Monad's failure symbol is specified with the option \"FailureSymbol\"."

GenerateMaybeMonadSpecialCode::usage = "GenerateMaybeMonadSpecialCode[monadName_String] generates the special \
functions of a Maybe monad that allows sequential computations with optional failure. \
Monad's failure symbol is specified with the option \"FailureSymbol\". \
GenerateMaybeMonadSpecialCode is made for didactic purposes."

Begin["`Private`"]

ClearAll[GenerateMaybeMonadCode]
Options[GenerateMaybeMonadCode] = {"FailureSymbol" -> None};
GenerateMaybeMonadCode[monadName_String, opts : OptionsPattern[]] :=
    With[{
      Maybe = ToExpression[monadName],
      MaybeUnit = ToExpression[monadName <> "Unit"],
      MaybeUnitQ = ToExpression[monadName <> "UnitQ"],
      MaybeBind = ToExpression[monadName <> "Bind"],
      MaybeFilter = ToExpression[monadName <> "Filter"],
      MaybeEcho = ToExpression[monadName <> "Echo"],
      MaybeEchoFunction = ToExpression[monadName <> "EchoFunction"],
      MaybeOption = ToExpression[monadName <> "Option"],
      MaybeIfElse = ToExpression[monadName <> "IfElse"],
      MaybeWhen = ToExpression[monadName <> "When"],
      MaybeFailureSymbol = OptionValue["FailureSymbol"]
    },

      ClearAll[Maybe, MaybeUnit, MaybeUnitQ, MaybeBind,
        MaybeEcho, MaybeEchoFunction,
        MaybeFilter, MaybeOption, MaybeIfElse, MaybeWhen,
        MaybeOption, MaybeWhen];

      (************************************************************)
      (* Core functions                                           *)
      (************************************************************)

      MaybeUnitQ[x_] := MatchQ[x, MaybeFailureSymbol] || MatchQ[x, Maybe[___]];

      MaybeUnit[MaybeFailureSymbol] := MaybeFailureSymbol;
      MaybeUnit[x_] := Maybe[x];

      MaybeBind[MaybeFailureSymbol, f_] := MaybeFailureSymbol;
      MaybeBind[Maybe[x___], f_] :=
          Block[{res = f[x]}, If[FreeQ[res, MaybeFailureSymbol], res, MaybeFailureSymbol]];

      MaybeFilter[filterFunc_][xs_] := Maybe@Select[xs, filterFunc[#] &];

      MaybeEcho = Maybe@*Echo;
      MaybeEchoFunction = (Maybe@*EchoFunction[#] &);

      MaybeOption[f_][xs_] :=
          Block[{res = f[xs]}, If[FreeQ[res, MaybeFailureSymbol], res, Maybe@xs]];

      MaybeIfElse[testFunc_, fYes_, fNo_][xs_] :=
          Block[{testRes = testFunc[xs]}, If[TrueQ[testRes], fYes[xs], fNo[xs]]];

      MaybeWhen[testFunc_, f_][xs_] := MaybeIfElse[testFunc, f, Maybe];


      (************************************************************)
      (* Infix operators                                          *)
      (************************************************************)
      DoubleRightArrow[x_?MaybeQ, f_] := MaybeBind[x, f];
      DoubleRightArrow[x_, y_, z__] := DoubleRightArrow[DoubleRightArrow[x, y], z];

      Unprotect[NonCommutativeMultiply];
      NonCommutativeMultiply[x_, f_] := MaybeBind[x, f];
      NonCommutativeMultiply[x_, y_, z__] := NonCommutativeMultiply[NonCommutativeMultiply[x, y], z];

    ];

ClearAll[GenerateMaybeMonadSpecialCode]
Options[GenerateMaybeMonadSpecialCode] = {"FailureSymbol" -> None};
GenerateMaybeMonadSpecialCode[monadName_String, opts : OptionsPattern[]] :=
    With[{
      Maybe = ToExpression[monadName],
      MaybeUnit = ToExpression[monadName <> "Unit"],
      MaybeRandomChoice = ToExpression[monadName <> "RandomChoice"],
      MaybeMapToFail = ToExpression[monadName <> "MapToFail"],
      MaybeNegativeToFail = ToExpression[monadName <> "NegativeFailure"],
      MaybeRandomReal = ToExpression[monadName <> "RandomReal"],
      MaybeDivide = ToExpression[monadName <> "Divide"],
      MaybeFailureSymbol = OptionValue["FailureSymbol"]
    },

      ClearAll[Maybe, MaybeUnit,
        MaybeRandomChoice, MaybeMapToFail,
        MaybeNegativeToFail, MaybeRandomReal, MaybeDivide];

      (************************************************************)
      (* Special functions                                        *)
      (************************************************************)

      MaybeRandomChoice[n_][xs_] :=
          Maybe@Block[{res = RandomChoice[xs, n]},
            If[TrueQ[Head[res] === RandomChoice], MaybeFailureSymbol, res]];

      MaybeMapToFail[critFunc_][xs_] :=
          If[AtomQ[xs],
            If[critFunc[xs], MaybeFailureSymbol, xs],
            Maybe@Map[If[critFunc[#], MaybeFailureSymbol, #] &, xs]
          ];

      MaybeNegativeToFail = MaybeMapToFail[NumberQ[#] && # < 0 &];

      MaybeRandomReal[xs_] :=
          Block[{res = RandomReal[Sequence @@ xs]},
            If[NumberQ[res] || ListQ[res], Maybe@res, MaybeFailureSymbol]];

      MaybeDivide[x_?MaybeQ, y_?MaybeQ] :=
          Block[{yres = MaybeBind[y, MaybeMapToFail[# == 0 &]]},
            If[! FreeQ[yres, MaybeFailureSymbol], MaybeFailureSymbol, Maybe[x[[1]]/y[[1]]]]
          ];

      MaybeDivide[y_][xs_] := If[FreeQ[xs, MaybeFailureSymbol], MaybeDivide[y, Maybe[xs]], MaybeFailureSymbol];
    ];

End[] (* `Private` *)

EndPackage[]