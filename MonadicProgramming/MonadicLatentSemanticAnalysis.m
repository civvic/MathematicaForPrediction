(*
    Monadic latent semantic analysis Mathematica package
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

(* :Package Version: 0.8 *)
(* :Mathematica Version: *)
(* :Copyright: (c) 2017 Anton Antonov *)
(* :Keywords: *)
(* :Discussion:

  # Introduction


    This file (package) provides monad-like implementation for for the following Latent Semantic Analysis (LSA)
    main sequence of steps :

      1. ingesting a collection of documents;

      2. creating a term-document matrix (linear vector space representation);

      3. facilitating term-paragraph matrix creation or other breakdowns;

      4. apply different type of term-weighting functions;

      5. extract topics using NNMF (or SVD) with required parameters;

      6. provide topic interpretation;

      7. produce corresponding statistical thesauri;

      8. provide different statistics over the document collection.


  This monadic implementation is just a wrapper interface to the functions provided by the packages [1,2]
  described in [3].


  # Usage example

      (* Get text data. *)
      speeches = ResourceData[ResourceObject["Presidential Nomination Acceptance Speeches"]];
      texts = Normal[speeches[[All, "Text"]]];

      (* Run the main processing pipeline. *)
      res =
        LSAMonUnit[texts]⟹
        LSAMonMakeDocumentTermMatrix[{}, stopWords]⟹
        LSAMonApplyTermWeightFunctions[]⟹
        LSAMonTopicExtraction[5, 12, 12, "MaxSteps" -> 6, "PrintProfilingInfo" -> True];

      (* Show statistical thesaurus in two different ways. *)
      res⟹
        LSAMonStatiscalThesaurus[{"arms", "banking", "economy", "education", "freedom", "tariff", "welfare"}, 6]⟹
        LSAMonRetrieveFromContext["statisticalThesaurus"]⟹
        LSAMonEchoValue⟹
        LSAMonEchoStatiscalThesaurus[];

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

If[Length[DownValues[StateMonadCodeGenerator`GenerateStateMonadCode]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/MonadicProgramming/StateMonadCodeGenerator.m"]
];

If[Length[DownValues[DocumentTermMatrixConstruction`DocumentTermMatrix]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/DocumentTermMatrixConstruction.m"]
];

(**************************************************************)
(* Generation                                                 *)
(**************************************************************)

(* Generate base functions of LSAMon monad (through StMon.) *)

GenerateStateMonadCode[ "LSAMon", "StringContextNames" -> True ]


(**************************************************************)
(* General functions                                          *)
(**************************************************************)


Clear[LSAMonTextCollectionQ]
LSAMonTextCollectionQ[x_] := VectorQ[x, StringQ];

ClearAll[LSAMonMakeDocumentTermMatrix]

LSAMonMakeDocumentTermMatrix[___][None] := None
LSAMonMakeDocumentTermMatrix[stemRules : {_String ...},
  stopWords : {_String ...}][xs_, context_] :=
    Block[{docTermMat, terms},
      Which[
        LSAMonTextCollectionQ[xs],
        {docTermMat, terms} = DocumentTermMatrix[ToLowerCase /@ xs, {stemRules, stopWords}];
        LSAMon[xs, Join[context, <|"texts" -> xs, "docTermMat" -> docTermMat, "terms" -> terms|>]],

        KeyExistsQ[context, "texts"] && LSAMonTextCollectionQ[context["texts"]],
        {docTermMat, terms} = DocumentTermMatrix[ToLowerCase /@ context["texts"], {stemRules, stopWords}];
        LSAMon[xs, Join[context, <|"docTermMat" -> docTermMat, "terms" -> terms|>]],

        True,
        Echo["Ingest texts first.", "LSMonMakeDocumentTermMatrix:"];
        None
      ]
    ];


ClearAll[LSAMonApplyTermWeightFunctions]

LSAMonApplyTermWeightFunctions[___][None] := None
LSAMonApplyTermWeightFunctions[globalWeightFunction_String, localWeightFunction_String, normalizerFunction_String][xs_, context_] :=
    Block[{},
      Echo["Applying terms weight functions using their string names is not implemented yet.", "LSAMonApplyTermWeightFunctions:"];
      None
    ];

LSAMonApplyTermWeightFunctions[args___][xs_, context_] :=
    Block[{wDocTermMat},
      Which[
        KeyExistsQ[context, "docTermMat"],
        wDocTermMat = WeightTerms[context["docTermMat"], args];
        LSAMon[xs, Join[context, <|"wDocTermMat" -> wDocTermMat|>]],

        True,
        Echo["No document-term matrix is made.", "LSAMonApplyTermWeightFunctions:"];
        None
      ]
    ];


ClearAll[LSAMonTopicExtraction]

Options[LSAMonTopicExtraction] = Options[GDCLSGlobal];
LSAMonTopicExtraction[___][None] := None
LSAMonTopicExtraction[nMinDocumentsPerTerm_Integer, nTopics_Integer, nInitlizingDocuments_Integer, opts : OptionsPattern[]][xs_, context_] :=
    Block[{documentsPerTerm, pos, W, H, M1, k, p, m, n},
      Which[
        KeyExistsQ[context, "wDocTermMat"],
        documentsPerTerm = Total /@ Transpose[Clip[context["docTermMat"], {0, 1}]];
        pos = Flatten[Position[documentsPerTerm, s_?NumberQ /; s >= nMinDocumentsPerTerm]];

        M1 = context["wDocTermMat"][[All, pos]];

        {k, p} = {nTopics, nInitlizingDocuments};
        {m, n} = Dimensions[M1];
        M1 = Transpose[M1];
        M1 = Map[# &, M1];
        H = ConstantArray[0, {k, n}];
        W = Table[Total[RandomSample[M1, p]], {k}];
        Do[
          W[[i]] = W[[i]]/Norm[W[[i]]];
          , {i, 1, Length[W]}];
        W = Transpose[W];
        M1 = SparseArray[M1];
        M1 = Transpose[M1];

        W = SparseArray[W];
        H = SparseArray[H];
        {W, H} = GDCLSGlobal[M1, W, H, opts];

        LSAMon[xs, Join[context, <|"W" -> W, "H" -> H, "topicColumnPositions" -> pos|>]],

        True,
        Echo["No document-term matrix is made.", "LSAMonTopicExtraction:"];
        None
      ]
    ];


ClearAll[LSAMonStatiscalThesaurus]

LSAMonStatiscalThesaurus[___][None] := None
LSAMonStatiscalThesaurus[words : {_String ..}, numberOfNNs_Integer][xs_, context_] :=
    Block[{W, H, HNF, thRes},
      Which[
        KeyExistsQ[context, "H"] && KeyExistsQ[context, "W"],
        {W, H} = NormalizeMatrixProduct[context["W"], context["H"]];
        HNF = Nearest[Range[Dimensions[H][[2]]], DistanceFunction -> (Norm[H[[All, #1]] - H[[All, #2]]] &)];

        thRes =
            Map[{#, NearestWords[HNF, #,
              context["terms"][[context["topicColumnPositions"]]], {},
              numberOfNNs]} &,
              Sort[words]];

        LSAMon[xs, Join[context, <|"statisticalThesaurus" -> thRes|>]],

        True,
        Echo["No factorization of the document-term matrix is made.", "LSAMonStatiscalThesaurus:"];
        None
      ]
    ];


ClearAll[LSAMonEchoStatiscalThesaurus]

LSAMonEchoStatiscalThesaurus[___][None] := None
LSAMonEchoStatiscalThesaurus[][xs_, context_] :=
    Block[{},
      Which[
        KeyExistsQ[context, "statisticalThesaurus"],
        Echo@
            Grid[
              Prepend[
                context["statisticalThesaurus"],
                Style[#, Blue, FontFamily -> "Times"] & /@ {"word", "statistical thesaurus"}],
              Dividers -> All, Alignment -> Left,
              Spacings -> {Automatic, 0.75}];
        LSAMon[xs, context],

        True,
        Echo["No statistical thesurus is computed.", "LSAMonEchoStatiscalThesaurus:"];
        None
      ]
    ]