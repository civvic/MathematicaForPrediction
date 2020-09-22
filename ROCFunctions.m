(*
    Reciever operating characteristics functions Mathematica package
    Copyright (C) 2016  Anton Antonov

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
    Mathematica is (C) Copyright 1988-2016 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)

(* :Title: Reciever operating characteristics functions *)
(* :Context: ROCFunctions` *)
(* :Author: Anton Antonov *)
(* :Date: 2016-10-09 *)

(* :Package Version: 1.0 *)
(* :Mathematica Version: *)
(* :Copyright: (c) 2016 Anton Antonov *)
(* :Keywords: ROC, Reciever operating characteristic *)
(* :Discussion:


    Comple usage example with Linear regression
    ===========================================

    #### Using Titanic data

        ExampleData[{"MachineLearning", "Titanic"}, "TrainingData"][[1 ;; 5]]

    #### Get training and testing data

        data = ExampleData[{"MachineLearning", "Titanic"}, "TrainingData"];
        data = ((Flatten@*List) @@@ data)[[All, {1, 2, 3, -1}]];
        trainingData = DeleteCases[data, {___, _Missing, ___}];

        data = ExampleData[{"MachineLearning", "Titanic"}, "TestData"];
        data = ((Flatten@*List) @@@ data)[[All, {1, 2, 3, -1}]];
        testData = DeleteCases[data, {___, _Missing, ___}];

    #### Replace categorical with numerical values

        trainingData = trainingData /. {"survived" -> 1, "died" -> 0,
            "1st" -> 1, "2nd" -> 2, "3rd" -> 3,
            "male" -> 0, "female" -> 1};

        testData = testData /. {"survived" -> 1, "died" -> 0,
            "1st" -> 1, "2nd" -> 2, "3rd" -> 3,
            "male" -> 0, "female" -> 1};

    #### Do linear regression

        lfm = LinearModelFit[{trainingData[[All, 1 ;; -2]], trainingData[[All, -1]]}]

    #### Get the predicted values

        modelValues = lfm @@@ testData[[All, 1 ;; -2]];

        (*Histogram[modelValues,20]*)
        TableForm[{Range[0, 1, 0.2], Quantile[modelValues, Range[0, 1, 0.2]]}]

    #### Obtain ROC associations over a set of parameter values

        testLabels = testData[[All, -1]];

        thRange = Range[0.1, 0.9, 0.025];
        aROCs = Table[ToROCAssociation[{0, 1}, testLabels,
            Map[If[# > th, 1, 0] &, modelValues]], {th, thRange}];

    #### Evaluate ROC functions for given ROC association

        Through[ROCFunctions[{"PPV", "NPV", "TPR", "ACC", "SPC"}][aROCs[[3]]]]

    #### Standard ROC plot

        ROCPlot[thRange, aROCs, "PlotJoined" -> False,
         "ROCPointCallouts" -> True, "ROCPointTooltips" -> True,
         GridLines -> Automatic]

    #### Plot ROC functions wrt to parameter values

        ListLinePlot[
         Map[Transpose[{thRange, #}] &,
          Transpose[
           Map[Through[
              ROCFunctions[{"PPV", "NPV", "TPR", "ACC", "SPC"}][#]] &,
            aROCs]]],
         Frame -> True,
         FrameLabel ->
          Map[Style[#, Larger] &, {"threshold, \[Theta]", "rate"}],
         PlotLegends ->
          Map[# <> ", " <> (ROCFunctions[
                "FunctionInterpretations"][#]) &, {"PPV", "NPV", "TPR", "ACC",
             "SPC"}], GridLines -> Automatic]

    ## Comments

    Remark 1:
     The requirements for atomic labels probably can be removed, but I decided to be conservative and impose
     that restriction.


    Anton Antonov
    2016-10-09
    Windermere, FL, USA
*)

(*

  TODO:
  1. Usage examples.

*)

(* Created by Mathematica Plugin for IntelliJ IDEA *)

BeginPackage["ROCFunctions`"]

ToROCAssociation::usage = "ToROCAssociation[ {trueLabel, falseLabel}, actualLabels, predictedLabels] converts \
two labels lists (actual and predicted) into an Association that can be used as an argument for the ROC functions. \
See ROCFunctions ."

ROCAssociationQ::usage = "Verifies that the argument is a valid ROC Assocition object. \
A ROC Association object has the keys \
\"TruePositive\", \"FalsePositive\", \"TrueNegative\", and \"FalseNegative\" ."

ROCFunctions::usage = "Gives access to the implement ROC functions.
It can be used as Thread[ROCFunctions[][rocAssoc]] or Thread[ROCFunctions[{\"TPR\",\"SPC\"}][rocAssoc]] .\
See ROCFunctions[\"FunctionInterpretations\"] for available functions and their interpretations."

ROCPlot::usage = "Makes a standard ROC plot for specified parameter list and corresponding ROC Association objects."

Begin["`Private`"]

Clear[ToROCRulesFirst]
ToROCRulesFirst[trueLabel_?AtomQ, falseLabel_?AtomQ, rocTbl_?MatrixQ] :=
    Block[{labelPairs = rocTbl[[All, 1 ;; 2]]},
      { "TruePositive" -> rocTbl[[Position[labelPairs, {trueLabel, trueLabel}][[1, 1]], 3]],
        "FalsePositive" -> rocTbl[[Position[labelPairs, {falseLabel, trueLabel}][[1, 1]], 3]],
        "TrueNegative" -> rocTbl[[Position[labelPairs, {falseLabel, falseLabel}][[1, 1]], 3]],
        "FalseNegative" -> rocTbl[[Position[labelPairs, {trueLabel, falseLabel}][[1, 1]], 3]]
      }
    ];

Clear[ToROCAssociation]

ToROCAssociation::nalbl = "The the first argument is expected to be list of two atomic elements."

ToROCAssociation::nvecs = "The the second and third arguments are expected to be vectors of the same length."

ToROCAssociation::sgntrs = "The alllowed signatures are one of : \
\nToROCAssociation[ {trueLabel_?AtomQ, falseLabel_?AtomQ}, actualLabels_, predictedLabels_ ] , \
\nToROCAssociation[ {trueLabel_?AtomQ falseLabel_?AtomQ}, apLabelPairsTally:{{{_,_},__}..}], \
\nToROCAssociation[ {trueLabel_?AtomQ, falseLabel_?AtomQ}, apfAssoc_Association] ."

ToROCAssociation[ {trueLabel_, falseLabel_}, actualLabels_List, predictedLabels_List ] :=
    Block[{ra},
      If[ ! ( AtomQ[trueLabel] && AtomQ[falseLabel] ),
        Message[ToROCAssociation::nalbl]
        Return[$Failed]
      ];
      If[ ! ( VectorQ[actualLabels] && VectorQ[predictedLabels] && Length[actualLabels] == Length[predictedLabels] ),
        Message[ToROCAssociation::nvecs]
        Return[$Failed]
      ];
      ra = Tally[Transpose[{actualLabels,predictedLabels}]];
      ra = Association[ Rule @@@ ra ];
      ra = Join[ Association @ Flatten[Outer[{#1,#2}->0&,{trueLabel,falseLabel},{trueLabel,falseLabel}]], ra ];
      ToROCAssociation[{trueLabel, falseLabel}, ra]
    ];

(*ToROCAssociation[ {trueLabel_?AtomQ falseLabel_?AtomQ}, apLabelPairsTally:{{{_,_},_}..}] :=*)
(*Block[{},*)
(*Print[apLabelPairsTally];*)
(*ToROCAssociation[ {trueLabel, falseLabel}, Association[ Rule @@@ apLabelPairsTally ] ]*)
(*];*)

ToROCAssociation[ {trueLabel_?AtomQ, falseLabel_?AtomQ}, apfAssoc_Association] :=
    Block[{},
      Association[
        { "TruePositive" -> apfAssoc[{trueLabel, trueLabel}],
          "FalsePositive" -> apfAssoc[{falseLabel, trueLabel}],
          "TrueNegative" -> apfAssoc[{falseLabel, falseLabel}],
          "FalseNegative" -> apfAssoc[{trueLabel, falseLabel}]
        }]
    ];

ToROCAssociation[___] := (Message[ToROCAssociation::sgntrs];$Failed);

Clear[ROCAssociationQ]
ROCAssociationQ[ obj_ ] :=
    AssociationQ[obj] &&
        Length[Intersection[Keys[obj],{"TruePositive","FalsePositive","TrueNegative","FalseNegative"}]] == 4;

TPR[rocAssoc_?ROCAssociationQ] := ("TruePositive")/("TruePositive" + "FalseNegative") /. Normal[rocAssoc];

SPC[rocAssoc_?ROCAssociationQ] := ("TrueNegative")/("FalsePositive" + "TrueNegative") /. Normal[rocAssoc];

PPV[rocAssoc_?ROCAssociationQ] := ("TruePositive")/("TruePositive" + "FalsePositive") /. Normal[rocAssoc];

NPV[rocAssoc_?ROCAssociationQ] := ("TrueNegative")/("TrueNegative" + "FalseNegative") /. Normal[rocAssoc];

FPR[rocAssoc_?ROCAssociationQ] := ("FalsePositive")/("FalsePositive" + "TrueNegative") /. Normal[rocAssoc];

FDR[rocAssoc_?ROCAssociationQ] := ("FalsePositive")/("FalsePositive" + "TruePositive") /. Normal[rocAssoc];

FNR[rocAssoc_?ROCAssociationQ] := ("FalseNegative")/("FalseNegative" + "TruePositive") /. Normal[rocAssoc];

ACC[rocAssoc_?ROCAssociationQ] := ("TruePositive" + "TrueNegative") / Total[Values[rocAssoc]] /. Normal[rocAssoc];

aROCAcronyms =
    AssociationThread[{"TPR", "SPC", "PPV", "NPV", "FPR", "FDR", "FNR", "ACC"} ->
        {"true positive rate (sensitivity)", "specificity", "positive predictive value",
          "negative predictive value", "false positive rate",
          "false discovery rate", "false negative rate", "accuracy"}];

aROCFunctions =
    AssociationThread[{"TPR", "SPC", "PPV", "NPV", "FPR", "FDR", "FNR", "ACC"} ->
        {TPR,SPC,PPV,NPV,FPR,FDR,FNR,ACC}];


Clear[ROCFunctions]
ROCFunctions["Methods"] := {"FunctionInterpretations", "FunctionNames", "Functions", "Methods", "Properties"};
ROCFunctions["Properties"] := ROCFunctions["Methods"];
ROCFunctions["FunctionNames"] := Keys[aROCAcronyms];
ROCFunctions["FunctionInterpretations"] := aROCAcronyms;
ROCFunctions["Functions"] := {TPR,SPC,PPV,NPV,FPR,FDR,FNR,ACC};
ROCFunctions[] := Evalaute[ROCFunctions["Functions"]];
ROCFunctions[fnames:{_String..}] := aROCFunctions/@fnames;
ROCFunctions[fname_String] := aROCFunctions[fname];

Clear[ROCPlot]

Options[ROCPlot] =
    Join[ {"ROCPointSize"-> 0.02, "ROCColor"-> Lighter[Blue],
      "ROCPointTooltips"->True, "ROCPointCallouts"->True, "PlotJoined" -> False }, Options[Graphics]];

ROCPlot[ parVals:{_?NumericQ..}, aROCs:{_?ROCAssociationQ..}, opts:OptionsPattern[]] :=
    ROCPlot[ "FPR", "TPR", parVals, aROCs, opts];

ROCPlot[
  xFuncName_String, yFuncName_String,
  parVals:{_?NumericQ..},
  aROCs:{_?ROCAssociationQ..}, opts:OptionsPattern[]] :=
    Block[{xFunc, yFunc, psize, rocc, pt, pc, pj},
      psize = OptionValue["ROCPointSize"];
      rocc = OptionValue["ROCColor"];
      {pt, pc, pj} = TrueQ[OptionValue[#]] & /@ { "ROCPointTooltips", "ROCPointCallouts", "PlotJoined" };
      {xFunc, yFunc} = ROCFunctions[{xFuncName, yFuncName}];
      Graphics[{
        PointSize[psize], rocc,
        Which[
          pt && !pj,
          MapThread[Tooltip[Point[Through[{xFunc,yFunc}[#1]]], #2] &, {aROCs, parVals}],
          !pt && !pj,
          Point @ Map[Through[{xFunc,yFunc}[#1]] &, aROCs],
          True,
          Line @ Map[Through[{xFunc,yFunc}[#1]]&, aROCs]
        ],
        Black,
        If[ pc,
          MapThread[
            Text[#2, Through[{xFunc,yFunc}[#1]], {-1, 2}] &, {aROCs, parVals}],
          {}
        ]},
        AspectRatio -> 1, Frame -> True,
        FrameLabel ->
            Map[Style[#<>", "<>ROCFunctions["FunctionInterpretations"][#], Larger, Bold] &, {xFuncName,yFuncName}],
        DeleteCases[{opts},( "ROCPointSize" | "ROCColor" | "ROCPointTooltips" | "ROCPointCallouts" | "PlotJoined") -> _ ]
      ]
    ]/; Length[parVals] == Length[aROCs];

End[] (* `Private` *)

EndPackage[]