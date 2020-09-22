(*
    Call graph for context functions Mathematica package
    Copyright (C) 2018  Anton Antonov

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
    antononcube @ gmail . com,
    Windermere, Florida, USA.
*)

(*
    Mathematica is (C) Copyright 1988-2018 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)
(* :Title: CallGraph *)
(* :Context: CallGraph` *)
(* :Author: Anton Antonov *)
(* :Date: 2018-12-31 *)

(* :Package Version: 0.6 *)
(* :Mathematica Version: 11.3 *)
(* :Copyright: (c) 2018 Anton Antonov *)
(* :Keywords: call graph, dependencies, down values, sub values *)
(* :Discussion: *)

BeginPackage["CallGraph`"];

CallGraph::usage = "CallGraph[contexts:{_String..}, opts___] makes a call graph for the functions of \
specified (package) contexts."

Begin["`Private`"];

Clear[SymbolQ]
SymbolQ[x_] := Head[x] === Symbol;


Clear[CallGraph]

Options[CallGraph] =
    Join[
      { "PrivateContexts" -> False, "SelfReferencing" -> False, "UsageTooltips" -> True },
      Options[Graph]
    ];

CallGraph[context_String, opts:OptionsPattern[] ] := CallGraph[{context}, opts ];

CallGraph[contexts:{_String..}, opts:OptionsPattern[] ] :=
    Block[{pSymbs, pPrivateSymbs, dvs, dRes, aDependencyRules, gRules, grOpts},

      pSymbs =
          Flatten@
              Map[
                Function[{c},
                  Block[{p = Names[c <> "*"]},
                    Select[Map[ToExpression[c <> #] &, p], Head[#] === Symbol &]]
                ], contexts];

      If[ TrueQ[OptionValue[CallGraph, "PrivateContexts"]],
        pPrivateSymbs =
            Flatten@
                Map[ToExpression[Names[# <> "Private`*"]] &, contexts];

        pSymbs = Join[pSymbs, pPrivateSymbs];
      ];

      dvs = AssociationThread[pSymbs, MapThread[Join, {DownValues /@ pSymbs, SubValues /@ pSymbs}] ];
      dvs = Select[dvs, Length[#] > 0 &];

      Block[{pSymbs = Keys[dvs]},
        dRes = AssociationThread[
          pSymbs ->
              Map[Function[{s}, Map[! FreeQ[HoldPattern[#], s] &, dvs]], pSymbs]];
      ];

      aDependencyRules = Map[Pick[Keys[#], Values[#]] &, dRes];

      gRules = Reverse /@ Flatten[Thread /@ Normal[aDependencyRules]];

      (*Delete the self-referencing rules:*)
      If[ !TrueQ[OptionValue[CallGraph, "SelfReferencing"]],
        gRules = DeleteCases[gRules, x_ -> x_];
      ];

      If[ TrueQ[OptionValue[CallGraph, "UsageTooltips"]],
        gRules = Map[Tooltip[#, #::usage] &, gRules, {2}];
      ];

      grOpts = Normal @ KeyTake[ {opts}, First /@ Options[Graph]];

      Graph[gRules, grOpts, VertexLabels -> "Name"]
    ];

End[]; (* `Private` *)

EndPackage[]