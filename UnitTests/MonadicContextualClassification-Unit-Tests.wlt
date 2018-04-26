(*
    Monadic contextual classification Mathematica unit tests
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
    antononcube @ gmai l . c om,
    Windermere, Florida, USA.
*)

(*
    Mathematica is (C) Copyright 1988-2018 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)

(* :Title: MonadicContextualClassification-Unit-Testss *)
(* :Author: Anton Antonov *)
(* :Date: 2018-04-23 *)

(* :Package Version: 0.7 *)
(* :Mathematica Version: 11.2 *)
(* :Copyright: (c) 2018 Anton Antonov *)
(* :Keywords: monad, monadic, classification, workflow, State monad, Mathematica, Wolfram Language, unit test *)
(* :Discussion:

   This file has units tests for the package

     https://github.com/antononcube/MathematicaForPrediction/blob/master/MonadicProgramming/MonadicContextualClassification.m

*)

BeginTestSection["MonadicContextualClassification-Unit-Tests"]

VerificationTest[(* 1 *)
  CompoundExpression[
    Get["~/MathematicaForPrediction/MonadicProgramming/MonadicContextualClassification.m"]
    (*Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/MonadicProgramming/MonadicContextualClassification.m"]*),
    Greater[Length[SubValues[MonadicContextualClassification`ClConSplitData]], 0]
  ]
  ,
  True
  ,
  TestID->"LoadPackage"
]

VerificationTest[(* 2 *)
  CompoundExpression[
    SeedRandom[2343],
    Set[data, RandomInteger[List[0, 10000], List[400]]],
    Set[data, Dataset[Transpose[List[data, Mod[data, 3], Map[Composition[Last, IntegerDigits], data], Map[OddQ, data]]]]],
    Set[data, Dataset[data[All, Function[AssociationThread[List["number", "feature1", "feature2", "label"], Slot[1]]]]]],
    Dimensions[data]
  ]
  ,
  List[400, 4]
  ,
  TestID->"EvenOddDataset"
]

VerificationTest[(* 3 *)
  CompoundExpression[
    Set[dataMLRules, Map[Function[Rule[Most[Slot[1]], Last[Slot[1]]]], Normal[data[All, Values]]]],
    MatchQ[dataMLRules, List[Repeated[Rule[List[BlankSequence[]], Alternatives[True, False]]]]]
  ]
  ,
  True
  ,
  TestID->"EvenOddDataMLRules"
]

VerificationTest[(* 4 *)
  CompoundExpression[
    Set[res,
      DoubleLongRightArrow[
        ClConUnit[data],
        ClConSplitData[0.4`],
        ClConAddToContext,
        ClConTakeContext]
    ],
    Keys[res]
  ]
  ,
  List["trainingData", "testData"]
  ,
  TestID->"DataToContext-no-[]"
]

VerificationTest[(* 5 *)
  CompoundExpression[Set[res, DoubleLongRightArrow[ClConUnit[data], ClConSplitData[0.4`], ClConAddToContext[], ClConTakeContext[]]], Keys[res]]
  ,
  List["trainingData", "testData"]
  ,
  TestID->"DataToContext-with-[]"
]

VerificationTest[(* 6 *)
  CompoundExpression[
    SeedRandom[232],
    Set[res,
      DoubleLongRightArrow[
        ClConUnit[data],
        ClConSplitData[0.4`],
        ClConAddToContext,
        ClConMakeClassifier["RandomForest"],
        ClConClassifierMeasurements[List["Accuracy", "Precision", "Recall"]],
        ClConTakeValue]
    ],
    Greater[res["Accuracy"], 0.85`]
  ]
  ,
  True
  ,
  TestID->"ClassifierMaking-with-Dataset-1"
]

VerificationTest[(* 7 *)
  CompoundExpression[
    SeedRandom[232],
    Set[res,
      DoubleLongRightArrow[
        ClConUnit[dataMLRules],
        ClConSplitData[0.7`],
        ClConMakeClassifier["RandomForest"],
        ClConClassifierMeasurements[List["Accuracy", "Precision", "Recall"]],
        ClConTakeValue]
    ],
    Greater[res["Accuracy"], 0.85`]
  ]
  ,
  True
  ,
  TestID->"ClassifierMaking-with-MLRules-1"
]

VerificationTest[(* 8 *)
  CompoundExpression[
    Set[res,
      DoubleLongRightArrow[
        ClConUnit[data],
        ClConSplitData[0.7`],
        ClConMakeClassifier["RandomForest"],
        ClConAccuracyByVariableShuffling,
        ClConTakeValue]
    ],
    And[
      AssociationQ[res],
      Equal[Sort[Keys[res]], Sort[Prepend[DeleteCases[Normal[Keys[data[1]]], "label"], None]]]
    ]
  ]
  ,
  True
  ,
  TestID->"AccuracyByVariableShuffling-1"
]

VerificationTest[(* 9 *)
  CompoundExpression[
    Set[res,
      DoubleLongRightArrow[
        ClConUnit[data],
        ClConSplitData[0.4`],
        ClConMakeClassifier["RandomForest"],
        ClConROCData,
        ClConTakeValue]
    ],
    MatchQ[res, Association[Rule[False, List[Repeated[Blank[Association]]]], Rule[True, List[Repeated[Blank[Association]]]]]]
  ]
  ,
  True
  ,
  TestID->"ROCData-1"
]


VerificationTest[(* 10 *)
  CompoundExpression[
    SeedRandom[456],
    Set[resEnsembleDiffMethods,
      DoubleLongRightArrow[
        ClConUnit[data],
        ClConSplitData[0.7`],
        ClConMakeClassifier[List["NearestNeighbors", "LogisticRegression", "SupportVectorMachine"]],
        ClConClassifierMeasurements[List["Accuracy", "Precision", "Recall"]]]
    ],
    Greater[DoubleLongRightArrow[resEnsembleDiffMethods, ClConTakeValue]["Accuracy"], 0.75`]
  ]
  ,
  True
  ,
  TestID->"ClassifierEnsemble-different-methods-1"
]

VerificationTest[(* 11 *)
  CompoundExpression[
    Set[res,
      DoubleLongRightArrow[
        resEnsembleDiffMethods,
        ClConAccuracyByVariableShuffling,
        ClConTakeValue]
    ],
    And[AssociationQ[res], Equal[Sort[Keys[res]], Sort[Prepend[DeleteCases[Normal[Keys[data[1]]], "label"], None]]]]
  ]
  ,
  True
  ,
  TestID->"ClassifierEnsemble-different-methods-2-cont"
]

VerificationTest[(* 12 *)
  CompoundExpression[
    Set[res,
      DoubleLongRightArrow[
        resEnsembleDiffMethods,
        ClConROCData,
        ClConTakeValue]
    ],
    MatchQ[res, Association[Rule[False, List[Repeated[Blank[Association]]]], Rule[True, List[Repeated[Blank[Association]]]]]]
  ]
  ,
  True
  ,
  TestID->"ClassifierEnsemble-different-methods-3-cont"
]


VerificationTest[(* 13 *)
  CompoundExpression[
    SeedRandom[363],
    Set[resEnsembleOfOneMethod,
      DoubleLongRightArrow[
        ClConUnit[data],
        ClConSplitData[0.7`],
        ClConMakeClassifier[List["NearestNeighbors", 0.9`, 6]], ClConClassifierMeasurements[List["Accuracy", "Precision", "Recall"]]]
    ],
    Greater[DoubleLongRightArrow[resEnsembleOfOneMethod, ClConTakeValue]["Accuracy"], 0.7`]
  ]
  ,
  True
  ,
  TestID->"ClassifierEnsemble-one-method-1"
]

VerificationTest[(* 14 *)
  CompoundExpression[
    SeedRandom[363],
    Set[resEnsembleOfOneMethod,
      DoubleLongRightArrow[
        ClConUnit[data],
        ClConSplitData[0.7`],
        ClConMakeClassifier[Association[Rule["method", "NearestNeighbors"], Rule["sampleFraction", 0.95`], Rule["nClassifiers", 12], Rule["samplingFunction", RandomChoice]]],
        ClConClassifierMeasurements[List["Accuracy", "Precision", "Recall"]]]
    ],
    Greater[DoubleLongRightArrow[resEnsembleOfOneMethod, ClConTakeValue]["Accuracy"], 0.75`]
  ]
  ,
  True
  ,
  TestID->"ClassifierEnsemble-one-method-2"
]

VerificationTest[(* 15 *)
  CompoundExpression[
    Set[res,
      DoubleLongRightArrow[
        resEnsembleOfOneMethod,
        ClConAccuracyByVariableShuffling,
        ClConTakeValue]
    ],
    And[AssociationQ[res], Equal[Sort[Keys[res]], Sort[Prepend[DeleteCases[Normal[Keys[data[1]]], "label"], None]]]]
  ]
  ,
  True
  ,
  TestID->"ClassifierEnsemble-one-method-3-cont"
]

VerificationTest[(* 16 *)
  CompoundExpression[
    Set[res,
      DoubleLongRightArrow[
        resEnsembleOfOneMethod,
        ClConROCData,
        ClConTakeValue]
    ],
    MatchQ[res, Association[Rule[False, List[Repeated[Blank[Association]]]], Rule[True, List[Repeated[Blank[Association]]]]]]
  ]
  ,
  True
  ,
  TestID->"ClassifierEnsemble-one-method-4-cont"
]

VerificationTest[(* 17 *)
  CompoundExpression[
    Set[List[n, m], List[10, 12]],
    DoubleLongRightArrow[
      ClConUnit[Association[Rule["trainingData", Thread[Rule[RandomReal[1, List[n, m]], RandomChoice[List["a", "b"], n]]]], Rule["testData", List[]]]],
      ClConAddToContext[],
      ClConAssignVariableNames[],
      ClConTakeVariableNames]
  ]
  ,
  Map[ToString, Range[1, m]]
  ,
  TestID->"AssignVariableNames-1"
]

VerificationTest[(* 18 *)
  CompoundExpression[
    Set[List[n, m], List[10, 12]],
    DoubleLongRightArrow[
      ClConUnit[Association[Rule["trainingData", Thread[Rule[RandomReal[1, List[n, m]], RandomChoice[List["a", "b"], n]]]], Rule["testData", List[]]]],
      ClConAddToContext[],
      ClConAssignVariableNames[List["k", "j", "l"]],
      ClConTakeVariableNames]
  ]
  ,
  Join[List["k", "j", "l"], Map[ToString, Range[4, m]]]
  ,
  TestID->"AssignVariableNames-2"
]

VerificationTest[(* 19 *)
  CompoundExpression[
    Set[List[n, m], List[10, 12]],
    DoubleLongRightArrow[ClConUnit[Association[Rule["trainingData", Dataset[RandomReal[1, List[n, m]]]], Rule["testData", List[]]]],
      ClConAddToContext[],
      ClConAssignVariableNames[Automatic],
      ClConTakeVariableNames]
  ]
  ,
  Map[ToString, Range[1, m]]
  ,
  TestID->"AssignVariableNames-3"
]


EndTestSection[]
