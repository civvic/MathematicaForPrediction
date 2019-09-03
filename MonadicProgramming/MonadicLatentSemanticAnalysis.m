(*
    Monadic Latent Semantic Analysis Mathematica package
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
    antononcube @ gmail . com,
    Windermere, Florida, USA.
*)

(*
    Mathematica is (C) Copyright 1988-2017 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)

(* :Title: MonadicLatentSemanticAnalysis *)
(* :Context: MonadicLatentSemanticAnalysis` *)
(* :Author: Anton Antonov *)
(* :Date: 2017-10-06 *)
(* Created with the Wolfram Language Plugin for IntelliJ, see http://wlplugin.halirutan.de/ . *)

(* :Package Version: 1.0 *)
(* :Mathematica Version: *)
(* :Copyright: (c) 2017 Anton Antonov *)
(* :Keywords: *)
(* :Discussion:

  # Introduction

    This file (package) provides monad-like implementation for for the following Latent Semantic Analysis (LSA)
    main sequence of steps :

      1. ingesting a collection of documents;

      2. creating a document-term matrix (linear vector space representation);

      3. facilitating term-paragraph matrix creation or other breakdowns;

      4. apply different type of term-weighting functions;

      5. extract topics using NNMF (or SVD) with required parameters;

      6. provide topic interpretation;

      7. produce corresponding statistical thesauri;

      8. provide different statistics over the document collection.


  This monadic implementation is just a wrapper interface to the functions provided by the packages [1,2];
  those functions described in [3].


  # Usage example

      (* Get text data. *)
      speeches = ResourceData[ResourceObject["Presidential Nomination Acceptance Speeches"]];
      texts = Normal[speeches[[All, "Text"]]];

      (* Run the main processing pipeline. *)
      res =
        LSAMonUnit[texts]⟹
        LSAMonMakeDocumentTermMatrix[{}, stopWords]⟹
        LSAMonApplyTermWeightFunctions[]⟹
        LSAMonExtractTopics[5, 60, 12, "MaxSteps" -> 6, "PrintProfilingInfo" -> True];

      (* Show statistical thesaurus in two different ways. *)
      res⟹
        LSAMonExtractStatisticalThesaurus[{"arms", "banking", "economy", "education", "freedom", "tariff", "welfare"}, 6]⟹
        LSAMonRetrieveFromContext["statisticalThesaurus"]⟹
        LSAMonEchoValue⟹
        LSAMonEchoStatisticalThesaurus[];

  # References

    [1] Anton Antonov, Implementation of document-term matrix construction and re-weighting functions in Mathematica, (2013),
        MathematicaForPrediction at GitHub.
        https://github.com/antononcube/MathematicaForPrediction/blob/master/DocumentTermMatrixConstruction.m

    [2] Anton Antonov, Implementation of the Non-Negative Matrix Factorization algorithm in Mathematica, (2013),
        https://github.com/antononcube/MathematicaForPrediction/blob/master/NonNegativeMatrixFactorization.m

    [3] Anton Antonov, "Topic and thesaurus extraction from a document collection", (2013),
        MathematicaForPrediction at GitHub.
        https://github.com/antononcube/MathematicaForPrediction/blob/master/Documentation/Topic%20and%20thesaurus%20extraction%20from%20a%20document%20collection.pdf

  Anton Antonov
  2017-10-06

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

If[Length[DownValues[DocumentTermMatrixConstruction`DocumentTermMatrix]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/DocumentTermMatrixConstruction.m"]
];

If[Length[DownValues[NonNegativeMatrixFactorization`GDCLS]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/NonNegativeMatrixFactorization.m"]
];

If[Length[DownValues[CrossTabulate`CrossTabulate]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/CrossTabulate.m"]
];

If[Length[DownValues[SSparseMatrix`ToSSparseMatrix]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/SSparseMatrix.m"]
];

If[Length[DownValues[OutlierIdentifiers`OutlierPosition]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/OutlierIdentifiers.m"]
];


(**************************************************************)
(* Package definition                                         *)
(**************************************************************)

BeginPackage["MonadicLatentSemanticAnalysis`"];

$LSAMonFailure::usage = "Failure symbol for the monad LSAMon.";

LSAMonApplyTermWeightFunctions::usage = "Apply term weight functions to entries of the document-term matrix.";

LSAMonInterpretBasisVector::usage = "Interpret the a specified basis vector.";

LSAMonEchoStatisticalThesaurus::usage = "Echo the statistical thesaurus entries for a specified list of words.";

LSAMonEchoDocumentsStatistics::usage = "Echo statistics for the text collection.";

LSAMonEchoTopicsTable::usage = "Echo the a table with the extracted topics.";

LSAMonGetDocuments::usage = "Get monad's document collection.";

LSAMonMakeDocumentTermMatrix::usage = "Make the document-term matrix.";

LSAMonMakeGraph::usage = "Make a graph of the document-term, document-document, or term-term relationships.";

LSAMonFindMostImportantDocuments::usage = "Find the most important texts in the text collection.";

LSAMonExtractStatisticalThesaurus::usage = "Extract the statistical thesaurus for specified list of words.";

LSAMonDocumentCollectionQ::usage = "Gives True if the argument is a text collection.";

LSAMonExtractTopics::usage = "Extract topics.";

LSAMonFindTagsTopicsRepresentation::usage = "Find the topic representation corresponding to a list of tags. \
Each monad document is expected to have a tag. One tag might correspond to multiple documents.";

LSAMonRepresentByTopics::usage = "Find the topics representation of a matrix.";

LSAMonMakeTopicsTable::usage = "Make a table of topics.";

LSAMonTakeTexts::usage = "Gives the value of the key \"texts\" from the monad context.";

LSAMonTakeMatrix::usage = "Gives SSparseMatrix object of the value of the key \"docTermMat\" from the monad context.";

LSAMonTakeWeightedMatrix::usage = "Gives SSparseMatrix object of the value of the key \"wDocTermMat\" from the monad context.";

FindMostImportantSentences::usage = "FindMostImportantSentences[sentences : ( _String | {_String ..} ), nTop_Integer : 5, opts : OptionsPattern[]] \
finds the most important sentences in a text or a list of sentences.";

DocumentTermSSparseMatrix::usage = "SSparseMatrix adapter function to DocumentTermMatrix.";

WeightTermsOfSSparseMatrix::usage = "SSparseMatrix adapter function to WeightTerms.";

Begin["`Private`"];

Needs["MathematicaForPredictionUtilities`"];
Needs["StateMonadCodeGenerator`"];
Needs["DocumentTermMatrixConstruction`"];
Needs["NonNegativeMatrixFactorization`"];
Needs["CrossTabulate`"];
Needs["SSparseMatrix`"];
Needs["OutlierIdentifiers`"];


(**************************************************************)
(* Generation                                                 *)
(**************************************************************)

(* Generate base functions of LSAMon monad (through StMon.) *)

GenerateStateMonadCode[ "MonadicLatentSemanticAnalysis`LSAMon", "FailureSymbol" -> $LSAMonFailure, "StringContextNames" -> False ];

(**************************************************************)
(* Setters and takers                                         *)
(**************************************************************)

GenerateMonadAccessors[
  "MonadicLatentSemanticAnalysis`LSAMon",
  {"documents", "terms", "documentTermMatrix", "weightedDocumentTermMatrix", "globalTermWeights",
    "topicColumnPositions", "automaticTopicNames", "statisticalThesaurus", "topicsTable", "method" },
  "FailureSymbol" -> $LSAMonFailure ];

GenerateMonadAccessors[
  "MonadicLatentSemanticAnalysis`LSAMon",
  {"W", "H" },
  "FailureSymbol" -> $LSAMonFailure, "DecapitalizeElementName" -> False ];

Clear[LSAMonTakeMatrix, LSAMonTakeWeightedMatrix];

LSAMonTakeMatrix = LSAMonTakeDocumentTermMatrix;

LSAMonTakeWeightedMatrix = LSAMonTakeWeightedDocumentTermMatrix;

(**************************************************************)
(* Adapter functions                                          *)
(**************************************************************)

Clear[DocumentTermSSparseMatrix];

DocumentTermSSparseMatrix[ docs : ( {_String ...} | {{_String...}...} ), {stemmingRules : (_List | _Dispatch | _Association | Automatic), stopWords_}, opts : OptionsPattern[] ] :=
    DocumentTermSSparseMatrix[ AssociationThread[ Map[ ToString, Range[Length[docs]]], docs ], {stemmingRules, stopWords}, opts ];

DocumentTermSSparseMatrix[
  docs : ( Association[ (_ -> _String) ...] | Association[ (_ -> {_String...}) ... ] ),
  {stemmingRules : (_List | _Dispatch | _Association | Automatic), stopWords_},
  opts : OptionsPattern[]] :=
    Block[{docIDs, docTermMat, terms},

      docIDs = Keys[docs];

      {docTermMat, terms} = DocumentTermMatrix[ Values[docs], { stemmingRules, stopWords}, opts];

      ToSSparseMatrix[ docTermMat, "RowNames" -> docIDs, "ColumnNames" -> terms ]
    ];

(*------------------------------------------------------------*)
(* Also can be used in SMRMon. *)

Clear[WeightTermsOfSSparseMatrix];

WeightTermsOfSSparseMatrix[ smat_SSparseMatrix ] := WeightTermsOfSSparseMatrix[ smat, "IDF", "None", "Cosine"];

WeightTermsOfSSparseMatrix[ smat_SSparseMatrix, globalWeightFunction_, localWeightFunction_, normalizerFunction_ ] :=
    Block[{},
      ToSSparseMatrix[
        WeightTerms[SparseArray[smat], globalWeightFunction, localWeightFunction, normalizerFunction],
        "RowNames" -> RowNames[smat],
        "ColumnNames" -> ColumnNames[smat]
      ]
    ];

(**************************************************************)
(* Get texts                                                  *)
(**************************************************************)

Clear[LSAMonDocumentCollectionQ];
LSAMonDocumentCollectionQ[x_] := AssociationQ[x] && VectorQ[ Values[x], StringQ ];

Clear[LSAMonGetDocuments];

LSAMonGetDocuments[$LSAMonFailure] := $LSAMonFailure;

LSAMonGetDocuments[][xs_, context_] := LSAMonGetDocuments[xs, context];

LSAMonGetDocuments[xs_, context_] :=
    Block[{texts},

      Which[

        KeyExistsQ[context, "documents"] && LSAMonDocumentCollectionQ[ context["documents"] ],
        LSAMonUnit[ context["documents"], context],

        KeyExistsQ[context, "documents"] && VectorQ[ context["documents"], StringQ ],
        texts = ToAutomaticKeysAssociation[context["documents"]];
        LSAMonUnit[ texts, context],

        LSAMonDocumentCollectionQ[xs],
        LSAMonUnit[xs, context],

        VectorQ[xs, StringQ],
        texts = ToAutomaticKeysAssociation[xs];
        LSAMonUnit[ texts, context],

        True,
        Echo["Cannot find documents.", "LSAMonGetDocuments:"];
        $LSAMonFailure
      ]

    ];

LSAMonGetDocuments[___][xs_, context_Association] := $LSAMonFailure;


(**************************************************************)
(* General functions                                          *)
(**************************************************************)

(*------------------------------------------------------------*)
(* Make document-term matrix                                  *)
(*------------------------------------------------------------*)
Clear[LSAMonMakeDocumentTermMatrix];

Options[LSAMonMakeDocumentTermMatrix] = { "StemmingRules" -> {}, "StopWords" -> Automatic };

LSAMonMakeDocumentTermMatrix[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonMakeDocumentTermMatrix[xs_, context_Association] := LSAMonMakeDocumentTermMatrix[][xs, context];

LSAMonMakeDocumentTermMatrix[][xs_, context_Association] := LSAMonMakeDocumentTermMatrix[ {}, Automatic ][xs, context];

LSAMonMakeDocumentTermMatrix[ opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{ stemRules, stopWords },

      stemRules = OptionValue[ LSAMonMakeDocumentTermMatrix, "StemmingRules" ];

      If[ ! ( AssociationQ[stemRules] || DispatchQ[stemRules] || MatchQ[ stemRules, {_Rule...} ] || TrueQ[ stemRules === Automatic ] ),
        Echo[
          "The value of the option \"StemmingRules\" is expected to be a list or rules, dispatch table, an association, or Automatic.",
          "LSAMonMakeDocumentTermMatrix:"
        ];
        Return[$LSAMonFailure]
      ];

      stopWords = OptionValue[ LSAMonMakeDocumentTermMatrix, "StopWords" ];

      If[ ! ( MatchQ[ stopWords, {_String..} ] || TrueQ[ stopWords === Automatic ] ),
        Echo[
          "The value of the option \"StopWords\" is expected to be a list or strings or Automatic.",
          "LSAMonMakeDocumentTermMatrix:"
        ];
        Return[$LSAMonFailure]
      ];

      LSAMonMakeDocumentTermMatrix[ stemRules, stopWords ][xs, context]
    ];

LSAMonMakeDocumentTermMatrix[stemRules : (_List | _Dispatch | _Association | Automatic), stopWordsArg : {_String ...} | Automatic ][xs_, context_] :=
    Block[{stopWords = stopWordsArg, docs, docTermMat },

      docs = Fold[ LSAMonBind, LSAMonUnit[xs, context], { LSAMonGetDocuments, LSAMonTakeValue } ];

      If[ TrueQ[docs === $LSAMonFailure],
        Echo["Ingest texts first.", "LSMonMakeDocumentTermMatrix:"];
        Return[$LSAMonFailure]
      ];

      If[ TrueQ[ stopWords === Automatic ],
        stopWords = DictionaryLookup["*"];
        stopWords = Complement[stopWords, DeleteStopwords[stopWords]];
      ];

      docTermMat = DocumentTermSSparseMatrix[ ToLowerCase /@ docs, {stemRules, stopWords} ];

      LSAMonUnit[xs, Join[context, <| "documents" -> docs, "documentTermMatrix" -> docTermMat, "terms" -> ColumnNames[docTermMat] |>]]

    ];

LSAMonMakeDocumentTermMatrix[__][___] :=
    Block[{},
      Echo[
        "The expected signature is LSAMonMakeDocumentTermMatrix[stemRules : (_List|_Dispatch|_Association), stopWords : {_String ...}] .",
        "LSAMonMakeDocumentTermMatrix:"];
      $LSAMonFailure
    ];


(*------------------------------------------------------------*)
(* Apply term weight function to matrix entries               *)
(*------------------------------------------------------------*)

Clear[LSAMonApplyTermWeightFunctions];

Options[LSAMonApplyTermWeightFunctions] = { "GlobalWeightFunction" -> "IDF", "LocalWeightFunction" -> "None", "NormalizerFunction" -> "Cosine" };

LSAMonApplyTermWeightFunctions[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonApplyTermWeightFunctions[xs_, context_Association] := LSAMonApplyTermWeightFunctions[][xs, context];

LSAMonApplyTermWeightFunctions[ opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{ termFuncs, val },

      termFuncs =
          Table[
            (
              val = OptionValue[ LSAMonApplyTermWeightFunctions, funcName ];

              If[ ! StringQ[val],
                Echo[
                  "The value of the option \"" <> funcName <> "\" is expected to be a string.",
                  "LSAMonMakeDocumentTermMatrix:"
                ];
                Return[$LSAMonFailure]
              ];

              val
            ),
            { funcName, { "GlobalWeightFunction", "LocalWeightFunction", "NormalizerFunction" } }
          ];

      LSAMonApplyTermWeightFunctions[ Sequence @@ termFuncs ][xs, context]
    ];

LSAMonApplyTermWeightFunctions[globalWeightFunction_String, localWeightFunction_String, normalizerFunction_String][xs_, context_] :=
    Block[{wDocTermMat, globalWeights},

      Which[
        KeyExistsQ[context, "documentTermMatrix"],
        wDocTermMat = WeightTermsOfSSparseMatrix[context["documentTermMatrix"], globalWeightFunction, localWeightFunction, normalizerFunction];
        globalWeights =
            AssociationThread[
              ColumnNames[context["documentTermMatrix"]],
              GlobalTermFunctionWeights[ SparseArray[context["documentTermMatrix"]], globalWeightFunction ]
            ];
        LSAMonUnit[xs, Join[context, <|"weightedDocumentTermMatrix" -> wDocTermMat, "globalTermWeights" -> globalWeights |>]],

        True,
        Echo["No document-term matrix.", "LSAMonApplyTermWeightFunctions:"];
        $LSAMonFailure
      ]

    ];

LSAMonApplyTermWeightFunctions[args___][xs_, context_] :=
    Block[{wDocTermMat, globalWeights},
      (* This code is the same as above. But I want to emphasize the string function names specification. *)
      Which[
        KeyExistsQ[context, "documentTermMatrix"],
        wDocTermMat = WeightTermsOfSSparseMatrix[context["documentTermMatrix"], args];
        globalWeights =
            AssociationThread[
              ColumnNames[context["documentTermMatrix"]],
              GlobalTermFunctionWeights[ SparseArray[context["documentTermMatrix"]], {args}[[1]] ]
            ];
        LSAMonUnit[xs, Join[context, <|"weightedDocumentTermMatrix" -> wDocTermMat, "globalTermWeights" -> globalWeights |>]],

        True,
        Echo["No document-term matrix.", "LSAMonApplyTermWeightFunctions:"];
        $LSAMonFailure
      ]
    ];

LSAMonApplyTermWeightFunctions[__][___] :=
    Block[{},
      Echo[
        "The expected signature is LSAMonApplyTermWeightFunctions[globalWeightFunction_String, localWeightFunction_String, normalizerFunction_String] .",
        "LSAMonApplyTermWeightFunctions:"];
      $LSAMonFailure
    ];


(*------------------------------------------------------------*)
(* Make document-term matrix                                  *)
(*------------------------------------------------------------*)

Clear[LSAMonExtractTopics];

Options[LSAMonExtractTopics] =
    Join[
      { "NumberOfTopics" -> None, Method -> "NNMF", "MinDocumentsPerTerm" -> 10, "NumberOfInitializingDocuments" -> 12, Tolerance -> 10^-6  },
      Options[GDCLSGlobal]
    ];

LSAMonExtractTopics[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonExtractTopics[$LSAMonFailure] := $LSAMonFailure;

LSAMonExtractTopics[xs_, context_Association] := $LSAMonFailure;

(*LSAMonExtractTopics[nTopics_Integer, nMinDocumentsPerTerm_Integer, nInitializingDocuments_Integer, opts : OptionsPattern[]][xs_, context_] :=*)
(*    LSAMonExtractTopics[ nTopics, Join[ { "MinDocumentsPerTerm" -> nMinDocumentsPerTerm, "NumberOfInitializingDocuments" -> nInitializingDocuments }, {opts}] ][xs, context];*)

LSAMonExtractTopics[ opts : OptionsPattern[] ][xs_, context_] :=
    Block[{nTopics},

      nTopics = OptionValue[ LSAMonExtractTopics, "NumberOfTopics" ];

      If[ ! IntegerQ[nTopics],
        Echo[
          "The value of the option \"NumberOfTopics\" is expected to be a integer.",
          "LSAMonMakeDocumentTermMatrix:"
        ];
        Return[$LSAMonFailure]
      ];

      LSAMonExtractTopics[ nTopics, opts ][xs, context]
    ];

LSAMonExtractTopics[ nTopics_Integer, opts : OptionsPattern[] ][xs_, context_] :=
    Block[{method, nMinDocumentsPerTerm, nInitializingDocuments,
      docTermMat, documentsPerTerm, pos, W, H, M1, k, p, m, n, U, S, V, nnmfOpts, automaticTopicNames },

      method = OptionValue[ LSAMonExtractTopics, Method ];

      If[ StringQ[method], method = ToLowerCase[method]];

      If[ TrueQ[ MemberQ[ {SingularValueDecomposition, ToLowerCase["SingularValueDecomposition"], ToLowerCase["SVD"] }, method ] ], method = "SVD" ];

      If[ TrueQ[ MemberQ[ ToLowerCase[ { "NNMF", "NMF", "NonNegativeMatrixFactorization" } ], method ] ], method = "NNMF" ];

      If[ !MemberQ[ {"SVD", "NNMF"}, method ],
        Echo["The value of the option Method is expected to be \"SVD\" or \"NNMF\".", "LSAMonExtractTopics:"];
        Return[$LSAMonFailure]
      ];

      nMinDocumentsPerTerm = OptionValue[ LSAMonExtractTopics, "MinDocumentsPerTerm" ];
      If[ ! ( IntegerQ[ nMinDocumentsPerTerm ] && nMinDocumentsPerTerm > 0 ),
        Echo["The value of the option \"MinDocumentsPerTerm\" is expected to be a positive integer.", "LSAMonExtractTopics:"];
        Return[$LSAMonFailure]
      ];

      nInitializingDocuments = OptionValue[ LSAMonExtractTopics, "NumberOfInitializingDocuments" ];
      If[ ! ( IntegerQ[ nInitializingDocuments ] && nInitializingDocuments > 0 ),
        Echo["The value of the option \"NumberOfInitializingDocuments\" is expected to be a positive integer.", "LSAMonExtractTopics:"];
        Return[$LSAMonFailure]
      ];

      If[ !KeyExistsQ[context, "weightedDocumentTermMatrix"],
        Return[
          Fold[
            LSAMonBind,
            LSAMonUnit[xs, context],
            {
              LSAMonApplyTermWeightFunctions[],
              LSAMonExtractTopics[
                nTopics,
                Join[ { Method -> method, "MinDocumentsPerTerm" -> nMinDocumentsPerTerm, "NumberOfInitializingDocuments" -> nInitializingDocuments }, {opts}]
              ]
            }
          ]
        ]
      ];

      (* Restrictions *)
      docTermMat = SparseArray[ context["documentTermMatrix"] ];

      documentsPerTerm = Total /@ Transpose[Clip[docTermMat, {0, 1}]];
      pos = Flatten[Position[documentsPerTerm, s_?NumberQ /; s >= nMinDocumentsPerTerm]];

      M1 = SparseArray[ context["weightedDocumentTermMatrix"][[All, pos]] ];

      (* Factorization *)
      Which[
        method == "NNMF" && KeyExistsQ[context, "weightedDocumentTermMatrix"] && SSparseMatrixQ[context["weightedDocumentTermMatrix"]],
        (* Non-negative matrix factorization *)

        {k, p} = {nTopics, nInitializingDocuments};
        {m, n} = Dimensions[M1];
        M1 = Transpose[M1];
        M1 = Map[# &, M1];
        H = ConstantArray[0, {k, n}];
        W = Table[Total[RandomSample[M1, p]], {k}];
        Do[
          W[[i]] = W[[i]] / Norm[W[[i]]];
          , {i, 1, Length[W]}];
        W = Transpose[W];
        M1 = SparseArray[M1];
        M1 = Transpose[M1];

        W = SparseArray[W];
        H = SparseArray[H];

        nnmfOpts = FilterRules[ {opts}, Options[GDCLSGlobal] ];
        If[ TrueQ[ ("MaxSteps" /. nnmfOpts) === Automatic ],
          nnmfOpts = Prepend[ nnmfOpts, "MaxSteps" -> 12 ];
        ];

        {W, H} = GDCLSGlobal[M1, W, H, Evaluate[ nnmfOpts ] ],

        method == "SVD" && KeyExistsQ[context, "weightedDocumentTermMatrix"] && SSparseMatrixQ[context["weightedDocumentTermMatrix"]],
        (* Singular Value Decomposition *)

        {U, S, V} = SingularValueDecomposition[ M1, nTopics, DeleteCases[ FilterRules[ {opts}, Options[SingularValueDecomposition] ], Method -> _ ]];

        (* Re-fit the result to monad's data interpretation. *)
        W = SparseArray[U];
        H = Transpose[V];
        H = S . H,

        True,
        Echo["Cannot find a document-term matrix.", "LSAMonExtractTopics:"];
        Return[$LSAMonFailure]
      ];

      automaticTopicNames =
          Table[
            StringJoin[Riffle[BasisVectorInterpretation[Normal@H[[ind]], 3, context["terms"][[pos]]][[All, 2]], "-"]],
            {ind, 1, Dimensions[W][[2]]}];

      If[ ! DuplicateFreeQ[automaticTopicNames],
        automaticTopicNames = MapIndexed[ #1 <> "-" <> ToString[#2]&, automaticTopicNames ];
      ];

      W = ToSSparseMatrix[ SparseArray[W], "RowNames" -> RowNames[context["documentTermMatrix"]], "ColumnNames" -> automaticTopicNames ];
      H = ToSSparseMatrix[ SparseArray[H], "RowNames" -> automaticTopicNames, "ColumnNames" -> ColumnNames[context["documentTermMatrix"]][[pos]] ];

      LSAMonUnit[xs, Join[context, <|"W" -> W, "H" -> H, "topicColumnPositions" -> pos, "automaticTopicNames" -> automaticTopicNames, "method" -> method |>]]

    ];

LSAMonExtractTopics[___][__] :=
    Block[{},
      Echo[
        "The expected signature is LSAMonExtractTopics[ nTopics_Integer, opts___] .",
        "LSAMonExtractTopics::"];
      $LSAMonFailure;
    ];

LSAMonTopicExtraction = LSAMonExtractTopics;


(*------------------------------------------------------------*)
(* Extract statistical thesaurus                                 *)
(*------------------------------------------------------------*)

Clear[LSAMonExtractStatisticalThesaurus];

Options[LSAMonExtractStatisticalThesaurus] = { "Words" -> None, "NumberOfNearestNeighbors" -> 12 };

LSAMonExtractStatisticalThesaurus[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonExtractStatisticalThesaurus[ opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{words, numberOfNNs},

      words = OptionValue[ LSAMonExtractStatisticalThesaurus, "Words" ];

      If[ ! MatchQ[ words, {_String..} ],
        Echo[
          "The value of the option \"Words\" is expected to be a list of strings.",
          "LSAMonExtractStatisticalThesaurus:"
        ];
        Return[$LSAMonFailure]
      ];

      numberOfNNs = OptionValue[ LSAMonExtractStatisticalThesaurus, "NumberOfNearestNeighbors" ];

      If[ ! MatchQ[ words, {_String..} ],
        Echo[
          "The value of the option \"Words\" is expected to be a list of strings.",
          "LSAMonExtractStatisticalThesaurus:"
        ];
        Return[$LSAMonFailure]
      ];

      LSAMonExtractStatisticalThesaurus[ words, numberOfNNs ][xs, context]
    ];

LSAMonExtractStatisticalThesaurus[words : {_String ..}, numberOfNNs_Integer][xs_, context_Association] :=
    Block[{W, H, HNF, thRes},
      Which[
        KeyExistsQ[context, "H"] && KeyExistsQ[context, "W"],

        {W, H} = NormalizeMatrixProduct[ SparseArray[context["W"]], SparseArray[context["H"]] ];

        HNF = Nearest[Range[Dimensions[H][[2]]], DistanceFunction -> (Norm[H[[All, #1]] - H[[All, #2]]] &)];

        thRes =
            Map[{#, NearestWords[HNF, #,
              context["terms"][[context["topicColumnPositions"]]], {},
              numberOfNNs]} &,
              Sort[words]];

        LSAMonUnit[thRes, Join[context, <|"statisticalThesaurus" -> thRes|>]],

        True,
        Echo["No factorization of the document-term matrix is made.", "LSAMonExtractStatisticalThesaurus:"];
        $LSAMonFailure
      ]
    ];

LSAMonExtractStatisticalThesaurus[___][__] :=
    Block[{},
      Echo[
        "The expected signature is LSAMonExtractStatisticalThesaurus[words : {_String ..}, numberOfNNs_Integer] .",
        "LSAMonExtractStatisticalThesaurus::"];
      $LSAMonFailure;
    ];


(*------------------------------------------------------------*)
(* Echo statistical thesaurus                                 *)
(*------------------------------------------------------------*)

Clear[LSAMonEchoStatisticalThesaurus];

Options[LSAMonEchoStatisticalThesaurus] = Options[LSAMonExtractStatisticalThesaurus];

LSAMonEchoStatisticalThesaurus[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonEchoStatisticalThesaurus[xs_, context_Association] := LSAMonEchoStatisticalThesaurus[][xs, context];

LSAMonEchoStatisticalThesaurus[ opts : OptionsPattern[] ][xs_, context_Association] :=
    Block[{words},

      words = OptionValue[ LSAMonEchoStatisticalThesaurus, "Words" ];

      Which[

        !TrueQ[ words === None ],
        Fold[ LSAMonBind, LSAMonUnit[xs, context], { LSAMonExtractStatisticalThesaurus[opts], LSAMonEchoStatisticalThesaurus } ],

        TrueQ[ words === None ] && KeyExistsQ[context, "statisticalThesaurus"],
        Echo@
            Grid[
              Prepend[
                context["statisticalThesaurus"],
                Style[#, Blue, FontFamily -> "Times"] & /@ {"word", "statistical thesaurus"}],
              Dividers -> All, Alignment -> Left,
              Spacings -> {Automatic, 0.75}];
        LSAMonUnit[xs, context],

        True  ,
        Echo["No statistical thesaurus is computed.", "LSAMonEchoStatisticalThesaurus:"];
        $LSAMonFailure
      ]
    ];

LSAMonEchoStatisticalThesaurus[___][__] :=
    Block[{},
      Echo["No arguments are expected.", "LSAMonEchoStatisticalThesaurus:"];
      $LSAMonFailure;
    ];


(*------------------------------------------------------------*)
(* Basis vector interpretation                                *)
(*------------------------------------------------------------*)

Clear[LSAMonInterpretBasisVector];

Options[LSAMonInterpretBasisVector] = { "NumberOfTerms" -> 12 };

LSAMonInterpretBasisVector[___][$LSAMonFailure] := $LSAMonFailure;
LSAMonInterpretBasisVector[vectorIndices : (_Integer | {_Integer..}), opts : OptionsPattern[] ][xs_, context_] :=
    Block[{W, H, res, numberOfTerms},

      numberOfTerms = OptionValue[LSAMonInterpretBasisVector, "NumberOfTerms"];

      {W, H} = RightNormalizeMatrixProduct[ SparseArray[context["W"]], SparseArray[context["H"]] ];

      res =
          Map[
            BasisVectorInterpretation[#, numberOfTerms, ColumnNames[context["H"]] ]&,
            Normal @ H[[ Flatten @ {vectorIndices} ]]
          ];

      If[ !MatchQ[res, {{{_?NumberQ, _String}..}..}],
        $LSAMonFailure,
        LSAMonUnit[ res, context ]
      ]

    ];

LSAMonInterpretBasisVector[___][__] :=
    Block[{},
      Echo[
        "The expected arguments are LSAMonInterpretBasisVector[vectorIndices:(_Integer|{_Integer..}), opts___] .",
        "LSAMonInterpretBasisVector:"];
      $LSAMonFailure;
    ];


(*------------------------------------------------------------*)
(* Topics table making                                        *)
(*------------------------------------------------------------*)

Clear[LSAMonMakeTopicsTable];

Options[LSAMonMakeTopicsTable] = { "NumberOfTerms" -> 12 };

LSAMonMakeTopicsTable[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonMakeTopicsTable[xs_, context_Association] := LSAMonMakeTopicsTable[][xs, context];

LSAMonMakeTopicsTable[opts : OptionsPattern[]][xs_, context_] :=
    Block[{topicsTbl, k, numberOfTerms},

      numberOfTerms = OptionValue["NumberOfTerms"];

      k = Dimensions[context["W"]][[2]];

      topicsTbl =
          Table[
            TableForm[{NumberForm[#[[1]] / t[[1, 1]], {4, 3}], #[[2]]} & /@ t],
            {t, First @ LSAMonInterpretBasisVector[Range[k], "NumberOfTerms" -> numberOfTerms][xs, context] }];

      LSAMonUnit[ topicsTbl, Join[ context, <| "topicsTable" -> topicsTbl|> ] ]
    ];

LSAMonMakeTopicsTable[__][___] :=
    Block[{},
      Echo["No arguments, just options are expected.", "LSAMonMakeTopicsTable:"];
      $LSAMonFailure
    ];


(*------------------------------------------------------------*)
(* Topics table echoing                                       *)
(*------------------------------------------------------------*)

Clear[LSAMonEchoTopicsTable];

Options[LSAMonEchoTopicsTable] = Join[
  {"NumberOfTableColumns" -> Automatic, "NumberOfTerms" -> 12 , "MagnificationFactor" -> Automatic},
  Options[Multicolumn] ];

LSAMonEchoTopicsTable[$LSAMonFailure] := $LSAMonFailure;

LSAMonEchoTopicsTable[ opts : OptionsPattern[] ][$LSAMonFailure] := $LSAMonFailure;

LSAMonEchoTopicsTable[xs_, context_Association] := LSAMonEchoTopicsTable[][xs, context];

LSAMonEchoTopicsTable[][xs_, context_Association] := LSAMonEchoTopicsTable[Options[LSAMonEchoTopicsTable]][xs, context];

LSAMonEchoTopicsTable[opts : OptionsPattern[]][xs_, context_] :=
    Block[{topicsTbl, k, numberOfTableColumns, numberOfTerms, mFactor, tOpts},

      numberOfTableColumns = OptionValue[LSAMonEchoTopicsTable, "NumberOfTableColumns"];

      numberOfTerms = OptionValue[LSAMonEchoTopicsTable, "NumberOfTerms"];

      mFactor = OptionValue[LSAMonEchoTopicsTable, "MagnificationFactor"];
      If[ TrueQ[mFactor === Automatic], mFactor = 0.8 ];

      k = Dimensions[context["W"]][[2]];

      If[ KeyExistsQ[context, "topicsTable"],
        topicsTbl = context["topicsTable"],
        (*ELSE*)
        topicsTbl = First @ LSAMonMakeTopicsTable["NumberOfTerms" -> numberOfTerms][xs, context]
      ];

      tOpts = Join[ FilterRules[ {opts}, Options[Multicolumn] ], {Dividers -> All, Alignment -> Left} ];

      Echo @ Magnify[#, mFactor] & @
          If[ TrueQ[numberOfTableColumns === Automatic],
            Multicolumn[
              ColumnForm /@ Transpose[{Style[#, Red] & /@ Range[k], topicsTbl}], tOpts],
            (* ELSE *)
            Multicolumn[
              ColumnForm /@ Transpose[{Style[#, Red] & /@ Range[k], topicsTbl}], numberOfTableColumns, tOpts]
          ];

      LSAMonUnit[ topicsTbl, context ]
    ];

LSAMonEchoTopicsTable[__][___] :=
    Block[{},
      Echo["No arguments, just options are expected.", "LSAMonEchoTopicsTable:"];
      $LSAMonFailure
    ];


(*------------------------------------------------------------*)
(* Topics representation of tags                              *)
(*------------------------------------------------------------*)

Clear[LSAMonFindTagsTopicsRepresentation];

Options[LSAMonFindTagsTopicsRepresentation] = { "ComputeTopicRepresentation" -> True, "AssignAutomaticTopicNames" -> True };

LSAMonFindTagsTopicsRepresentation[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonFindTagsTopicsRepresentation[xs_, context_Association] := LSAMonFindTagsTopicsRepresentation[][xs, context];

LSAMonFindTagsTopicsRepresentation[][xs_, context_] :=
    LSAMonFindTagsTopicsRepresentation[Automatic, "ComputeTopicRepresentation" -> True][xs, context];

LSAMonFindTagsTopicsRepresentation[tags : (Automatic | _List), opts : OptionsPattern[]][xs_, context_] :=
    Block[{computeTopicRepresentationQ, assignAutomaticTopicNamesQ, ctTags, W, H, docTopicIndices, ctMat },

      computeTopicRepresentationQ = OptionValue[LSAMonFindTagsTopicsRepresentation, "ComputeTopicRepresentation"];
      assignAutomaticTopicNamesQ = OptionValue[LSAMonFindTagsTopicsRepresentation, "AssignAutomaticTopicNames"];

      If[ ! ( KeyExistsQ[context, "documentTermMatrix"] && KeyExistsQ[context, "W"] ),
        Echo["No document-term matrix factorization is computed.", "LSAMonFindTagsTopicsRepresentation:"];
        Return[$LSAMonFailure]
      ];

      Which[

        TrueQ[tags === Automatic] && KeyExistsQ[context, "docTags"],
        ctTags = context["docTags"],

        TrueQ[tags === Automatic],
        ctTags = RowNames[context["documentTermMatrix"]],

        Length[tags] == Dimensions[context["documentTermMatrix"]][[1]],
        ctTags = tags,

        True,
        Echo["The length of the argument tags is expected to be same as the number of rows of the document-term matrix.",
          "LSAMonFindTagsTopicsRepresentation:"];
        Return[$LSAMonFailure]
      ];

      {W, H} = NormalizeMatrixProduct[ SparseArray[context["W"]], SparseArray[context["H"]] ];
      W = Clip[W, {0.01, 1}, {0, 1}];

      If[ computeTopicRepresentationQ || !KeyExistsQ[context, "docTopicIndices"],

        (* This is expected to be fairly quick, less than 1 second. *)
        (* If not, some sort of memoization has to be used, which will require consistency support. *)
        (* Using the option "ComputeTopicRepresentation" comes from those computation management concerns. *)
        docTopicIndices =
            Block[{v = Select[#, # > 0 &], vpos, ts1, ts2},
              vpos = Flatten@Position[#, x_ /; x > 0];
              ts1 =
                  OutlierIdentifiers`OutlierPosition[v,
                    OutlierIdentifiers`TopOutliers@*SPLUSQuartileIdentifierParameters];
              ts2 =
                  OutlierIdentifiers`OutlierPosition[v, OutlierIdentifiers`TopOutliers@*HampelIdentifierParameters];
              Which[
                Length[ts1] > 0, vpos[[ts1]],
                Length[ts2] > 0, vpos[[ts2]],
                True, vpos
              ]
            ] & /@ W,
        (* ELSE *)
        docTopicIndices = context["docTopicIndices"]
      ];

      (* Note that CrossTabulate is going to sort the matrix rows. *)
      (* The matrix rows correspond to the union of the tags. *)
      ctMat = CrossTabulate`CrossTabulate[ Flatten[MapThread[Thread[{#1, #2}] &, {ctTags, docTopicIndices}], 1]];

      (* This should be done better. *)
      If[ assignAutomaticTopicNamesQ,
        ctMat = Join[ ctMat, <| "ColumnNames" -> context["automaticTopicNames"][[ ctMat["ColumnNames"] ]] |> ];
        ctMat = ToSSparseMatrix[ ctMat ];
      ];

      LSAMonUnit[ ctMat, Join[ context, <| "docTopicIndices" -> docTopicIndices |> ] ]

    ];

LSAMonFindTagsTopicsRepresentation[__][___] :=
    Block[{},
      Echo[
        "The expected signature is LSAMonFindTagsTopicsRepresentation[tags:(Automatic|_List), opts___] .",
        "LSAMonFindTagsTopicsRepresentation:"];
      $LSAMonFailure
    ];


(*------------------------------------------------------------*)
(* Topics representation                                      *)
(*------------------------------------------------------------*)

Clear[LSAMonRepresentByTopics];

(*Options[LSAMonRepresentByTopics] = { "NumberOfNearestNeighbors" -> 4 };*)

LSAMonRepresentByTopics[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonRepresentByTopics[xs_, context_Association] := $LSAMonFailure;

LSAMonRepresentByTopics[][xs_, context_] := $LSAMonFailure;

LSAMonRepresentByTopics[ query_String, opts : OptionsPattern[] ][xs_, context_] :=
      LSAMonRepresentByTopics[ TextWords[query], opts][xs, context];

LSAMonRepresentByTopics[ query : {_String .. }, opts : OptionsPattern[] ][xs_, context_] :=
    Block[{vals, qmat},
      If[ KeyExistsQ[context, "globalTermWeights"],
        vals = Lookup[ context["globalTermWeights"], #, 1.] & /@ query;
        vals = vals / Max[vals],
        (* ELSE *)
        vals = ConstantArray[1,Length[query]]
      ];
      qmat = ToSSparseMatrix[ SparseArray[{vals}], "RowNames" -> {"query"}, "ColumnNames" -> query ];
      LSAMonRepresentByTopics[ qmat, opts][xs, context]
    ];

LSAMonRepresentByTopics[ matArg_SSparseMatrix, opts : OptionsPattern[] ][xs_, context_] :=
    Block[{ nns, mat = matArg, matNew = None, W, H, invH, nf, inds, approxVec },

      nns = OptionValue[ LSAMonRepresentByTopics, "NumberOfNearestNeighbors" ];

      If[ ! ( IntegerQ[nns] && nns > 0 ),
        Echo["The value of the option \"NumberOfNearestNeighbors\" is expected to be a positive integer.", "LSAMonRepresentByTopics:"];
        Return[$LSAMonFailure]
      ];

      If[ ! ( KeyExistsQ[context, "documentTermMatrix"] && KeyExistsQ[context, "W"] ),
        Echo["No document-term matrix factorization is computed.", "LSAMonRepresentByTopics:"];
        Return[$LSAMonFailure]
      ];

      mat = ImposeColumnNames[ mat, ColumnNames[ context["H"] ] ];

      If[ Max[Abs[ColumnSums[mat]]] == 0,
        Echo["The terms of the argument cannot be found in the topics matrix factor (H).", "LSAMonRepresentByTopics:"];
        Return[$LSAMonFailure]
      ];

      {W, H} = RightNormalizeMatrixProduct[ SparseArray[context["W"]], SparseArray[context["H"]] ];

      If[ context["method"] == "NNMF",

        invH = PseudoInverse[H];

        (*
        nf = Nearest[ Normal[W] -> Range[Dimensions[W][[1]]] ];
        matNew =
            Map[
              Function[{vec},
                inds = nf[ Normal[vec . invH], nns ];
                approxVec = Total[ W[[inds]] ];
                approxVec / Norm[approxVec]
              ],
              SparseArray[mat]
            ];
        *)

        matNew = Map[ # . invH &, SparseArray[mat] ];
      ];

      If[ context["method"] == "SVD",

        (* We are using Map in order to prevent too much memory usage. *)
        (*  matNew = Map[ Transpose[H] . ( H . # )&, SparseArray[mat] ];*)
        matNew = Map[ H . # &, SparseArray[mat] ];
      ];

      If[ TrueQ[ matNew === None ],
        Echo["Unknown value of the context member \"method\".", "LSAMonRepresentByTopics:"];
        Return[$LSAMonFailure]
      ];

      matNew = ToSSparseMatrix[ SparseArray[matNew], "RowNames" -> RowNames[mat], "ColumnNames" -> RowNames[context["H"]] ];

      LSAMonUnit[matNew, context]
    ];

LSAMonRepresentByTopics[__][___] :=
    Block[{},
      Echo[
        "The expected signature is LSAMonRepresentByTopics[ mat_SSparseMatrix | {_String..} | _String ] .",
        "LSAMonRepresentByTopics:"];
      $LSAMonFailure
    ];


(*------------------------------------------------------------*)
(* Documents collection statistics                            *)
(*------------------------------------------------------------*)

Clear[LSAMonEchoDocumentsStatistics];

Options[LSAMonEchoDocumentsStatistics] = Join[ {"LogBase" -> None}, Options[Histogram] ];

LSAMonEchoDocumentsStatistics[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonEchoDocumentsStatistics[xs_, context_Association] := LSAMonEchoDocumentsStatistics[][xs, context];

LSAMonEchoDocumentsStatistics[][xs_, context_Association] := LSAMonEchoDocumentsStatistics[ImageSize -> 300][xs, context];

LSAMonEchoDocumentsStatistics[opts : OptionsPattern[]][xs_, context_] :=
    Block[{logBase, logFunc, logInsert, texts, textWords, eLabel = None, dOpts, smat},

      logBase = OptionValue[LSAMonEchoDocumentsStatistics, "LogBase"];

      texts = Fold[ LSAMonBind, LSAMonUnit[xs, context], {LSAMonGetDocuments, LSAMonTakeValue} ];

      If[ TrueQ[ texts === $LSAMonFailure], Return[$LSAMonFailure] ];

      If[ KeyExistsQ[context, "documents"],
        eLabel = "Context value \"documents\":",
        eLabel = "Pipeline value:"
      ];

      textWords = StringSplit /@ texts;

      dOpts = FilterRules[ Join[{opts}, {PerformanceGoal -> "Speed", PlotRange -> All, PlotTheme -> "Detailed", ImageSize -> 300}], Options[Histogram] ];

      If[ !KeyExistsQ[context, "documentTermMatrix"],
        smat = None,
        (*ELSE*)
        smat = context["documentTermMatrix"];
        If[ !SSparseMatrixQ[smat],
          smat = None,
          (*ELSE*)
          smat = Clip[SparseArray[smat]];
        ]
      ];

      If[ NumberQ[logBase],
        logFunc = N[Log[logBase, #]]&;
        logInsert = "log " <> ToString[logBase] <> " number of",
        (* ELSE *)
        logFunc = Identity;
        logInsert = "number of"
      ];

      Echo[
        Grid[{
          {
            Row[{"Number of documents:", Length[texts]}],
            Row[{"Number of unique words:", Length[Union[Flatten[Values[textWords]]]]}],
            If[ TrueQ[smat === None],
              Nothing,
              Row[{"Document-term matrix dimensions:", Dimensions[smat]}]],
            If[ TrueQ[smat === None], Nothing, ""]
          },
          {
            Histogram[ logFunc[ StringLength /@ texts ], PlotLabel -> Capitalize[logInsert] <> " characters per document", FrameLabel -> {"Characters", "Documents"}, dOpts],
            Histogram[ logFunc[ Length /@ textWords ], PlotLabel -> Capitalize[logInsert] <> " words per document", FrameLabel -> {"Words", "Documents"}, dOpts],
            If[ TrueQ[smat === None],
              Nothing,
              Histogram[ logFunc[ Total[smat] ], PlotLabel -> Capitalize[logInsert] <> " documents per term", FrameLabel -> {"Documents", "Terms"}, dOpts]],
            If[ TrueQ[smat === None],
              Nothing,
              Column[{Capitalize[logInsert] <> "\ndocuments per term\nsummary", RecordsSummary[ logFunc[ Total[smat] ], {"# documents"} ]}]]
          }
        }],
        eLabel
      ];

      LSAMonUnit[xs, context]
    ];

LSAMonEchoDocumentsStatistics[__][___] :=
    Block[{},
      Echo["No arguments, just options are expected.", "LSAMonEchoDocumentsStatistics:"];
      $LSAMonFailure
    ];


(*------------------------------------------------------------*)
(* Make a graph                                               *)
(*------------------------------------------------------------*)

Clear[LSAMonMakeGraph];

Options[LSAMonMakeGraph] = { "Weighted" -> True, "Type" -> "Bipartite", "RemoveLoops" -> True };

LSAMonMakeGraph[___][$LSAMonFailure] := $LSAMonFailure;
LSAMonMakeGraph[opts : OptionsPattern[]][xs_, context_] :=
    Block[{weightedQ, type, am, res, knownGrTypes, removeLoopsQ },

      weightedQ = TrueQ[OptionValue[LSAMonMakeGraph, "Weighted"]];

      type = OptionValue[LSAMonMakeGraph, "Type"];

      removeLoopsQ = TrueQ[OptionValue[LSAMonMakeGraph, "RemoveLoops"]];

      knownGrTypes = { "Bipartite", "DocumentDocument", "TermTerm", "Document", "Term" };
      If[ !MemberQ[knownGrTypes, type],
        Echo[Row[{"The value of the option \"Type\" is expected to be one of:", knownGrTypes}], "LSAMonMakeGraph:"];
        Return[$LSAMonFailure]
      ];

      Which[
        MatrixQ[xs],
        am = xs,

        KeyExistsQ[context, "weightedDocumentTermMatrix"],
        am = context["weightedDocumentTermMatrix"],

        KeyExistsQ[context, "documentTermMatrix"],
        am = context["documentTermMatrix"],

        True,
        Echo["Make a document-term matrix first.", "LSAMonMakeGraph:"];
        Return[$LSAMonFailure]
      ];

      (* Note that this takes the SparseArray object of a SSparseMatrix object. *)
      am = SparseArray[am];

      Which[

        weightedQ && type == "Bipartite",
        am = SparseArray[ Append[Most[ArrayRules[am]], {_, _} -> Infinity], Dimensions[am] ];
        am = SparseArray[ ArrayFlatten[{{Infinity, am}, {Transpose[am], Infinity}}] ];
        res = WeightedAdjacencyGraph[am, DirectedEdges -> True],

        !weightedQ && type == "Bipartite",
        am = SparseArray[ArrayFlatten[{{0, am}, {Transpose[am], 0}}]];
        res = AdjacencyGraph[am, DirectedEdges -> True],

        weightedQ && ( type == "DocumentDocument" || type == "Document" ),
        am = am . Transpose[am];
        am = Transpose[SparseArray[Map[If[Norm[#1] == 0, #1, #1 / Norm[#1]] &, Transpose[am]]]];
        am = SparseArray[ Append[Most[ArrayRules[am]], {_, _} -> Infinity], Dimensions[am] ];
        If[removeLoopsQ, am = am - DiagonalMatrix[Diagonal[am]]];
        res = WeightedAdjacencyGraph[am],

        !weightedQ && ( type == "DocumentDocument" || type == "Document" ),
        am = am . Transpose[am];
        If[removeLoopsQ, am = am - DiagonalMatrix[Diagonal[am]]];
        res = AdjacencyGraph[Unitize[am]],

        weightedQ && ( type == "TermTerm" || type == "Term" ),
        am = Transpose[am] . am;
        am = Transpose[SparseArray[Map[If[Norm[#1] == 0, #1, #1 / Norm[#1]] &, Transpose[am]]]];
        am = SparseArray[ Append[Most[ArrayRules[am]], {_, _} -> Infinity], Dimensions[am] ];
        If[removeLoopsQ, am = am - DiagonalMatrix[Diagonal[am]]];
        res = WeightedAdjacencyGraph[am],

        !weightedQ && ( type == "TermTerm" || type == "Term" ),
        am = Transpose[am] . am;
        If[removeLoopsQ, am = am - DiagonalMatrix[Diagonal[am]]];
        res = AdjacencyGraph[Unitize[am]];

      ];

      LSAMonUnit[res, context]

    ];

LSAMonMakeGraph[__][___] :=
    Block[{},
      Echo["No arguments, just options are expected.", "LSAMonMakeGraph:"];
      $LSAMonFailure
    ];


(*------------------------------------------------------------*)
(* Find most important texts                                  *)
(*------------------------------------------------------------*)

Clear[LSAMonFindMostImportantDocuments];

Options[LSAMonFindMostImportantDocuments] = { "CentralityFunction" -> EigenvectorCentrality };

LSAMonFindMostImportantDocuments[___][$LSAMonFailure] := $LSAMonFailure;

LSAMonFindMostImportantDocuments[topN_Integer, opts : OptionsPattern[]][xs_, context_] :=
    Block[{cFunc, gr, cvec, inds, smat },

      cFunc = OptionValue[LSAMonFindMostImportantDocuments, "CentralityFunction"];

      (* Here we should check that the monad value is a text collection. *)
      If[ !( KeyExistsQ[context, "documents"] || KeyExistsQ[context, "weightedDocumentTermMatrix"] || KeyExistsQ["documentTermMatrix"] ),

        If[ !KeyExistsQ[context, "documents"] && !(KeyExistsQ[context, "weightedDocumentTermMatrix"] || KeyExistsQ["documentTermMatrix"]) ,
          Echo["No texts.", "LSAMonFindMostImportantDocuments:"];
          Return[$LSAMonFailure]
        ];


        If[ !( KeyExistsQ[context, "weightedDocumentTermMatrix"] || KeyExistsQ["documentTermMatrix"] ),
          Echo["No texts and document-term matrices.", "LSAMonFindMostImportantDocuments:"];
          Return[$LSAMonFailure]
        ];
      ];

      Which[
        TrueQ[ Head[xs] === Graph ] && VertexCount[xs] == Length[context["documents"]] ,
        gr = xs,

        TrueQ[ Head[xs] === Graph ] && VertexCount[xs] == Length[context["documents"]] + Length[context["terms"]],
        gr = xs,

        TrueQ[ cFunc === EigenvectorCentrality ] && !GraphQ[xs],
        (* Optimization, see below. *)
        gr = None,

        True,
        gr = Fold[ LSAMonBind, LSAMon[xs, context], {LSAMonMakeGraph["Type" -> "Bipartite"], LSAMonTakeValue} ]
      ];


      (* There is some inconsistencies in handling weighted graphs. *)
      (* That is why the most popular/likely case is computed directly. (For now.) *)
      If[ TrueQ[ cFunc === EigenvectorCentrality ] && ( TrueQ[ gr === None ] || VertexCount[xs] == Length[context["documents"]] ),

        (* Get document-term matrix. *)
        smat =
            If[ TrueQ[ KeyExistsQ[context, "weightedDocumentTermMatrix"] ],
              Lookup[context, "weightedDocumentTermMatrix"],
              Lookup[context, "documentTermMatrix"]
            ];

        (* Take the sparse array from the SSparseMatrix object. *)
        smat = SparseArray[smat];

        (* Make column stochastic. *)
        smat = Transpose[SparseArray[Map[If[Norm[#1] == 0, #1, #1 / Norm[#1]] &, Transpose[smat]]]];

        (* Compute eigenvector. *)
        cvec = SingularValueDecomposition[ N[smat], 1 ];

        cvec = cvec[[1]][[All, 1]];
        cvec = Abs[cvec] / Max[Abs[cvec]],

        (*ELSE*)
        cvec = cFunc[gr];
      ];

      If[ !ListQ[cvec], Return[$LSAMonFailure] ];

      inds = Take[Reverse[Ordering[cvec]], UpTo[topN]];

      Which[

        TrueQ[ gr === None ] || VertexCount[gr] == Length[context["documents"]],
        LSAMonUnit[ Transpose[{cvec[[inds]], inds, Keys @ context["documents"][[inds]], Values @ context["documents"][[inds]]}], context ],

        VertexCount[gr] == Length[context["documents"]] + Length[context["terms"]],
        LSAMonUnit[ Transpose[{cvec[[inds]], inds, Join[ Values[context["documents"]], context["terms"]][[inds]]}], context ],

        True,
        $LSAMonFailure
      ]
    ];

LSAMonFindMostImportantDocuments[___][__] :=
    Block[{},
      Echo[
        "The expected signature is LSAMonFindMostImportantDocuments[topN_Integer, opts___] .",
        "LSAMonFindMostImportantDocuments::"];
      $LSAMonFailure;
    ];


(*------------------------------------------------------------*)
(* Find most important sentences stand alone function         *)
(*------------------------------------------------------------*)

Clear[FindMostImportantSentences];

Options[FindMostImportantSentences] =
    Join[
      {
        "Splitter" -> Function[{text}, Select[StringSplit[text, {".", "!", "?", "..."}], StringLength[#] >= 3 &] ],
        "StopWords" -> Automatic
      },
      Options[Grid]
    ];

FindMostImportantSentences[text_String, nTop_Integer : 5, opts : OptionsPattern[] ] :=
    Block[{splitFunc = OptionValue["Splitter"]},
      FindMostImportantSentences[splitFunc[text], nTop, opts]
    ];

FindMostImportantSentences[sentences : {_String ..}, nTop_Integer : 5, opts : OptionsPattern[]] :=
    Block[{res, stopWords = OptionValue["StopWords"]},

      Quiet[
        res =
            Fold[
              LSAMonBind,
              LSAMonUnit[sentences],
              {
                LSAMonMakeDocumentTermMatrix[{}, stopWords],
                LSAMonApplyTermWeightFunctions["IDF", "None", "Cosine"],
                (*                LSAMonMakeGraph["Type" -> "DocumentDocument"],*)
                LSAMonFindMostImportantDocuments[nTop],
                LSAMonTakeValue
              }
            ];
      ];

      Grid[res, FilterRules[{opts}, Options[Grid]], Alignment -> Left]
    ];


End[]; (*`Private`*)

EndPackage[]
