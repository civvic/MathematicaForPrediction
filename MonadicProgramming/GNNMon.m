(*
    Monadic Geometric Nearest Neighbors Mathematica package
    Copyright (C) 2019  Anton Antonov

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
    Mathematica is (C) Copyright 1988-2019 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)
(* Created by the Wolfram Language Plugin for IntelliJ, see http://wlplugin.halirutan.de/ *)

(* :Title: GNNMon *)
(* :Context: GNNMon` *)
(* :Author: Anton Antonov *)
(* :Date: 2019-09-22 *)

(* :Package Version: 0.9 *)
(* :Mathematica Version: 12.0 *)
(* :Copyright: (c) 2019 Anton Antonov *)
(* :Keywords: nearest neighbors, anomaly detection, outliers, monad *)
(* :Discussion:

   # In brief

   The primary motivation for making this Geometric Nearest Neighbors (GNN) software monad
   (GNNMon) is the implementation of a simple Nearest Neighbors (NN's) classifier that tells
   does a point belong to a set of points.

   That classification functionality can be also used to find outliers in a set points.

   # Usage examples

    Block[{n = 30}, SeedRandom[343];
      points = 
       Transpose[{RandomVariate[NormalDistribution[0, 5], n], RandomVariate[NormalDistribution[12, 3], n]}]
    ];
    
    gnnObj =
      GNNMonUnit[points]⟹
       GNNMonMakeNearestFunction[DistanceFunction -> EuclideanDistance]⟹
       GNNMonComputeThresholds[10, Mean, OutlierIdentifier -> SPLUSQuartileIdentifierParameters];

    newPoints = {{-6, 2.5}, {4.5, 16}};

    doesNotBelong =
      gnnObj⟹
       GNNMonFindAnomalies[newPoints, "UpperThresholdFactor" -> 1]⟹
       GNNMonTakeValue

    (* {{-6, 2.5}} *)

    ListPlot[<|"Original points" -> points, "\"Does not belong\"" -> newAnomalies, "New points" -> newPoints|>,
     PlotRange -> All, 
     PlotStyle -> {{GrayLevel[0.6]}, {Pink, PointSize[0.022]}, {Blue, PointSize[0.01]}},
     ImageSize -> Large, PlotTheme -> "Detailed"]



   Anton Antonov
   Florida, USA
   2019-09-22
   
*)

(**************************************************************)
(* Importing packages (if needed)                             *)
(**************************************************************)

If[Length[DownValues[MathematicaForPredictionUtilities`RecordsSummary]] == 0,
  Echo["MathematicaForPredictionUtilities.m", "Importing from GitHub:"];
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/MathematicaForPredictionUtilities.m"]
];

If[Length[DownValues[StateMonadCodeGenerator`GenerateStateMonadCode]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/MonadicProgramming/StateMonadCodeGenerator.m"]
];

If[Length[DownValues[SSparseMatrix`ToSSparseMatrix]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/SSparseMatrix.m"]
];

If[Length[DownValues[OutlierIdentifiers`OutlierIdentifier]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/OutlierIdentifiers.m"]
];


(**************************************************************)
(* Package definition                                         *)
(**************************************************************)

BeginPackage["GNNMon`"];
(* Exported symbols added here with SymbolName::usage *)

$GNNMonFailure = "Failure symbol for GNNMon.";

GNNMonGetData::usage = "GNNMonGetData[] gets monad's points.";

GNNMonMakeNearestFunction::usage = "GNNMonMakeNearestFunction[opts] makes the Nearest function";

GNNMonComputeThresholds::usage = "GNNMonComputeThresholds[ nTopNNs_Integer, radiusFunc_:Mean ] computes \
the proximity thresholds using nTopNNs nearest neighbors and aggregating with radiusFunc.";

GNNMonFindNearest::usage = "GNNMonFindNearest[ pnt_?VectorQ, nTopNNs_Integer ] finds nTopNNs of monad's points \
that are nearest to pnt.";

GNNMonClassify::usage = "GNNMonClassify[ pnts : { _?VectorQ | _?MatrixQ }, opts ] classifies to True elements of pnts
that are considered close enough to monad's points.";

GNNMonFindAnomalies::usage = "GNNMonFindAnomalies[ pnts : { _?VectorQ | _?MatrixQ }, opts ] finds anomalies \
of pnts according to monad's points.";

GNNMonRescale::usage = "GNNMonRescale non-monadic rescaling.";


Begin["`Private`"];

Needs["MathematicaForPredictionUtilities`"];
Needs["StateMonadCodeGenerator`"];
Needs["OutlierIdentifiers`"];

(**************************************************************)
(* Generation                                                 *)
(**************************************************************)

(* Generate base functions of GNNMon monad (through StMon.) *)

GenerateStateMonadCode[ "GNNMon`GNNMon", "FailureSymbol" -> $GNNMonFailure, "StringContextNames" -> False ];

GenerateMonadAccessors[
  "GNNMon`GNNMon",
  { "data", "nearestFunction", "distanceFunction", "numberOfNNs", "nearestNeighborDistances",
    "RadiusFunction", "radius", "lowerThreshold", "UpperThreshold" },
  "FailureSymbol" -> $GNNMonFailure ];


(**************************************************************)
(* GetData                                                    *)
(**************************************************************)

Clear[DataToNormalForm];

DataToNormalForm[data_] :=
    Which[
      MatrixQ[data, NumericQ] && Dimensions[data][[2]] == 2,
      data,

      VectorQ[data, NumericQ],
      Transpose[{ Range[Length[data]], data }]
    ];

Clear[GNNMonGetData];

SyntaxInformation[GNNMonGetData] = { "ArgumentsPattern" -> { } };

GNNMonGetData[$GNNMonFailure] := $GNNMonFailure;

GNNMonGetData[][xs_, context_] := GNNMonGetData[xs, context];

GNNMonGetData[xs_, context_] :=
    Block[{data},

      Which[

        KeyExistsQ[context, "data"] && MatrixQ[context["data"], NumericQ],
        GNNMonUnit[ context["data"], context],

        MatrixQ[xs, NumericQ],
        GNNMonUnit[xs, context],

        True,
        Echo["Cannot find data.", "GetData:"];
        $GNNMonFailure
      ]

    ];

GNNMonGetData[___][xs_, context_Association] := $GNNMonFailure;


(**************************************************************)
(* Find distance from a point to matrix rows                  *)
(**************************************************************)
(* Non-monadic at this point. *)

Clear[GNNMonRescale];

GNNMonRescale[points_?MatrixQ] := GNNMonRescale[points, MinMax /@ Transpose[points]];

GNNMonRescale[points_?MatrixQ, mms_?MatrixQ] :=
    Block[{},
      Transpose@
          MapThread[Rescale[#1, #2, {0, 1}] &, {Transpose[points], mms}]
    ] /; Dimensions[points][[2]] == Dimensions[mms][[1]] && Dimensions[mms][[2]] == 2;


(**************************************************************)
(* Find distance from a point to matrix rows                  *)
(**************************************************************)

Clear[GNNMonMakeNearestFunction];

SyntaxInformation[GNNMonMakeNearestFunction] = { "ArgumentsPattern" -> { OptionsPattern[] } };

Options[GNNMonMakeNearestFunction] = Options[Nearest];

GNNMonMakeNearestFunction[$GNNMonFailure] := $GNNMonFailure;

GNNMonMakeNearestFunction[xs_, context_Association] := GNNMonFindAnomalies[][xs, context];

GNNMonMakeNearestFunction[ opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{data, distFunc, nf},

      distFunc = OptionValue[ GNNMonMakeNearestFunction, DistanceFunction ];

      data = GNNMonBind[ GNNMonGetData[xs, context], GNNMonTakeValue ];
      If[ TrueQ[ data === $GNNMonFailure ],
        Return[$GNNMonFailure]
      ];

      nf = Nearest[ data -> Range[Length[data]], DistanceFunction -> distFunc ];

      GNNMonUnit[ xs, Join[context, <| "data" -> data, "nearestFunction" -> nf, "distanceFunction" -> distFunc |> ] ]
    ];

GNNMonMakeNearestFunction[___][xs_, context_Association] :=
    Block[{},
      Echo[
        "The expected signature is GNNMonMakeNearestFunction[ opts:OptionsPattern[] ].",
        "GNNMonMakeNearestFunction:"
      ];
      $GNNMonFailure
    ];

(**************************************************************)
(* Find distance from a point to matrix rows                  *)
(**************************************************************)

ClearAll[GNNMonComputeThresholds];

SyntaxInformation[GNNMonComputeThresholds] = { "ArgumentsPattern" -> { _, _., OptionsPattern[] } };

Options[GNNMonComputeThresholds] = { "OutlierIdentifier" -> HampelIdentifierParameters };

GNNMonComputeThresholds[$GNNMonFailure] := $GNNMonFailure;

GNNMonComputeThresholds[xs_, context_Association] := $GNNMonFailure ;;

    GNNMonComputeThresholds[ nTopNNs_Integer, radiusFunc_ : Mean, opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{outFunc, data, nf, distFunc, nns, means, ths},

      outFunc = OptionValue[ GNNMonComputeThresholds, "OutlierIdentifier" ];

      data = GNNMonTakeData[xs, context];
      If[ TrueQ[ data === $GNNMonFailure ], Return[$GNNMonFailure] ];

      nf = GNNMonTakeNearestFunction[xs, context];
      If[ TrueQ[ nf === $GNNMonFailure ], Return[$GNNMonFailure] ];

      distFunc = GNNMonTakeDistanceFunction[xs, context];

      nns = Association @ Map[# -> nf[ data[[#]], nTopNNs ] &, Range[Length[data]] ];

      means = Association @ KeyValueMap[ Function[{k, v}, k -> radiusFunc[Map[distFunc[data[[k]], data[[#]]] &, Complement[v, {k}]]]], nns];

      ths = outFunc[ Values[means] ];

      GNNMonUnit[ xs,
        Join[context, <|
          "nearestNeighborDistances" -> nns,
          "numberOfNNs" -> nTopNNs,
          "radius" -> radiusFunc[ Values[means] ],
          "radiusFunction" -> radiusFunc,
          "lowerThreshold" -> ths[[1]],
          "upperThreshold" -> ths[[2]] |> ] ]
    ];

GNNMonComputeThresholds[___][xs_, context_Association] :=
    Block[{},
      Echo[
        "The expected signature is GNNMonComputeThresholds[ nTopNNs_Integer, radiusFunc_Mean, opts:OptionsPattern[] ].",
        "GNNMonComputeThresholds:"
      ];
      $GNNMonFailure
    ];


(**************************************************************)
(* Find nearest points                                        *)
(**************************************************************)

Clear[GNNMonFindNearest];

SyntaxInformation[GNNMonFindNearest] = { "ArgumentsPattern" -> { _, _., OptionsPattern[] } };

GNNMonFindNearest[$GNNMonFailure] := $GNNMonFailure;

GNNMonFindNearest[xs_, context_Association] := $GNNMonFailure ;;

    GNNMonFindNearest[ point_?VectorQ, nTopNNs_Integer, prop_String : "Values" ][xs_, context_Association] :=
    Block[{data, nf, nns},

      data = GNNMonBind[ GNNMonGetData[xs, context], GNNMonTakeValue ];
      If[ TrueQ[ data === $GNNMonFailure ], Return[$GNNMonFailure] ];

      nf = GNNMonTakeNearestFunction[xs, context];
      If[ TrueQ[ nf === $GNNMonFailure ], Return[$GNNMonFailure] ];

      Which[
        MemberQ[ { "indices", "indexes", "ids" }, ToLowerCase[prop]],
        nns = nf[point, nTopNNs],

        MemberQ[ { "values", "points" }, ToLowerCase[prop]],
        nns = nf[point, nTopNNs];
        nns = data[[ nns ]],

        ToLowerCase[prop] == "properties",
        Echo[ {"Indices", "Values", "Properties"}, "GNNMonFindNearest:"];
        nns = {"Indices", "Values", "Properties"},

        True,
        Echo["Unknown property.", "GNNMonFindNearest:"];
        Return[$GNNMonFailure]
      ];

      GNNMonUnit[ nns, context ]
    ];

GNNMonFindNearest[___][xs_, context_Association] :=
    Block[{},
      Echo[
        "The expected signature is GNNMonFindNearest[ point_?VectorQ, nTopNNs_Integer, prop_String : \"Values\" ].",
        "GNNMonFindNearest:"
      ];
      $GNNMonFailure
    ];



(**************************************************************)
(* Classify                                                   *)
(**************************************************************)

Clear[GNNMonClassify];

SyntaxInformation[GNNMonClassify] = { "ArgumentsPattern" -> { _., OptionsPattern[] } };

Options[GNNMonClassify] = { "UpperThresholdFactor" -> 1 };

GNNMonClassify[$GNNMonFailure] := $GNNMonFailure;

GNNMonClassify[xs_, context_Association] := $GNNMonFailure ;

GNNMonClassify[ ][xs_, context_Association] :=
    GNNMonClassify[ Automatic, "Decision", Options[GNNMonClassify] ][xs, context];

GNNMonClassify[ prop_String : "Decision", opts : OptionsPattern[] ][xs_, context_Association] :=
    GNNMonClassify[ Automatic, prop, opts][xs, context];

GNNMonClassify[ Automatic, prop_String : "Decision", opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{data, points},

      data = GNNMonTakeData[xs, context];
      If[ TrueQ[ data === $GNNMonFailure ], Return[$GNNMonFailure] ];

      Which[
        MatrixQ[xs, NumericQ] && Dimensions[xs][[2]] == Dimensions[data][[2]],
        points = xs,

        True,
        points = data
      ];

      GNNMonClassify[ points, prop, opts][xs, context]
    ];

GNNMonClassify[ point_?VectorQ, prop_String : "Decision", opts : OptionsPattern[] ][xs_, context_Association] :=
    GNNMonClassify[ {point}, opts ][xs, context];

GNNMonClassify[ points_?MatrixQ, prop_String : "Decision", opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{factor, data, nf, distFunc, nTopNNs, radiusFunc, upperThreshold, res, knownProperties},

      knownProperties = {"Decision", "Probabilities", "Properties"};

      factor = OptionValue[GNNMonClassify, "UpperThresholdFactor" ];
      If[ ! ( NumberQ[ factor ] && factor > 0 ),
        Echo["The value of the option \"UpperThresholdFactor\" is expected to be a positive number.", "GNNMonClassify:"];
        Return[$GNNMonFailure]
      ];

      data = GNNMonBind[ GNNMonGetData[xs, context], GNNMonTakeValue ];
      If[ TrueQ[ data === $GNNMonFailure ], Return[$GNNMonFailure] ];

      nf = GNNMonTakeNearestFunction[xs, context];
      If[ TrueQ[ nf === $GNNMonFailure ], Return[$GNNMonFailure] ];

      distFunc = GNNMonTakeDistanceFunction[xs, context];
      If[ TrueQ[ nf === $GNNMonFailure ], Return[$GNNMonFailure] ];

      nTopNNs = GNNMonTakeNumberOfNNs[xs, context];
      If[ TrueQ[ nf === $GNNMonFailure ], Return[$GNNMonFailure] ];

      radiusFunc = GNNMonTakeRadiusFunction[xs, context];
      If[ TrueQ[ nf === $GNNMonFailure ], Return[$GNNMonFailure] ];

      upperThreshold = GNNMonTakeUpperThreshold[xs, context];
      If[ TrueQ[ nf === $GNNMonFailure ], Return[$GNNMonFailure] ];

      res = Association[ MapIndexed[ #2[[1]] -> nf[#, nTopNNs]&, points] ];

      res = Association @
          KeyValueMap[ Function[{k, v}, k -> radiusFunc[ Map[ distFunc[ points[[k]], data[[#]] ] &, v ] ] ], res];

      res = Map[ # <= upperThreshold * factor &, res ];

      Which[
        MemberQ[ ToLowerCase[{ "Probabilities" }], ToLowerCase[prop]],
        Echo["Probabilities of belonging is not implemented yet.", "GNNMonClassify:"];
        Nothing,

        MemberQ[ ToLowerCase[{ "Decision" }], ToLowerCase[prop]],
        Nothing,

        ToLowerCase[prop] == "properties",
        Echo[ knownProperties, "GNNMonClassify:"];
        res = knownProperties,

        True,
        Echo["Unknown property. The second argument should be one of " <> ToString[knownProperties] <> ".",
          "GNNMonClassify:"];
        Return[$GNNMonFailure]
      ];

      GNNMonUnit[ res, context ]
    ];

GNNMonClassify[___][xs_, context_Association] :=
    Block[{},
      Echo[
        "The expected signature is GNNMonClassify[ points : ( _?VectorQ | _?MatrixQ | Automatic ), prop_String : \"Decision\" ].",
        "GNNMonClassify:"
      ];
      $GNNMonFailure
    ];


(**************************************************************)
(* Anomalies finder                                           *)
(**************************************************************)

ClearAll[GNNMonFindAnomalies];

SyntaxInformation[GNNMonFindAnomalies] = { "ArgumentsPattern" -> { _., OptionsPattern[] } };

Options[GNNMonFindAnomalies] = { "UpperThresholdFactor" -> 1 };

GNNMonFindAnomalies[$GNNMonFailure] := $GNNMonFailure;

GNNMonFindAnomalies[xs_, context_Association] := $GNNMonFailure ;

GNNMonFindAnomalies[ opts : OptionsPattern[] ][xs_, context_Association] :=
    GNNMonFindAnomalies[ Automatic, "Anomalies", opts ][xs, context];

GNNMonFindAnomalies[ point_?VectorQ, prop_String : "Anomalies", opts : OptionsPattern[] ][xs_, context_Association] :=
    GNNMonFindAnomalies[ {point}, opts ][xs, context];

GNNMonFindAnomalies[ points : ( _?MatrixQ | Automatic ), prop_String : "Anomalies", opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{res, knownProperties},

      knownProperties = {"Anomalies", "AnomalyPositions", "Decision", "Properties"};

      res = Fold[ GNNMonBind, GNNMonUnit[xs, context], {GNNMonClassify[points, "Decision", opts ], GNNMonTakeValue } ];
      If[ TrueQ[ res === $GNNMonFailure ], Return[$GNNMonFailure] ];

      Which[
        TrueQ[points === Automatic] &&  MemberQ[ ToLowerCase[{ "Anomalies" }], ToLowerCase[prop]],
        (* It assumed GNNMonClassify failed if !KeyExistsQ[context,"data"] *)
        res = Pick[context["data"], Not /@ Values[res]],

        MemberQ[ ToLowerCase[{ "Anomalies" }], ToLowerCase[prop]],
        res = Pick[points, Not /@ Values[res]],

        MemberQ[ ToLowerCase[{ "AnomalyPositions" }], ToLowerCase[prop]],
        res = Pick[Keys[res], Not /@ Values[res]],

        MemberQ[ ToLowerCase[{ "Decision" }], ToLowerCase[prop]],
        res = Not /@ res,

        ToLowerCase[prop] == "properties",
        Echo[ knownProperties, "GNNMonClassify:"];
        res = knownProperties,

        True,
        Echo["Unknown property. The second argument should be one of " <> ToString[knownProperties] <> ".",
          "GNNMonFindAnomalies:"];
        Return[$GNNMonFailure]
      ];

      GNNMonUnit[ res, context ]
    ];

GNNMonFindAnomalies[___][xs_, context_Association] :=
    Block[{},
      Echo[
        "The expected signature is GNNMonFindAnomalies[ points : ( _?VectorQ | _?MatrixQ | Automatic ), prop_String : \"Anomalies\" ].",
        "GNNMonFindAnomalies:"
      ];
      $GNNMonFailure
    ];

End[]; (* `Private` *)

EndPackage[]