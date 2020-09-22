(*
    Data reshaping Mathematica package
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

(* :Title: DataReshape *)
(* :Context: DataReshape` *)
(* :Author: Anton Antonov *)
(* :Date: 2018-09-07 *)

(* :Package Version: 0.1 *)
(* :Mathematica Version: 11.3 *)
(* :Copyright: (c) 2018 Anton Antonov *)
(* :Keywords: long form, wide form, dataset, reshape *)
(* :Discussion:

    # In brief

    Functions for conversion of Dataset objects and matrices into long form or wide form.

    # Rationale

    Obviously inspired from R's package "reshape2", [1].


    # Usage examples



    # References

    [1] Hadley Wickham, reshape2: Flexibly Reshape Data: A Reboot of the Reshape Package, (2017), cran.r-project.org.
        URL: https://cran.r-project.org/web/packages/reshape2/index.html .


    Anton Antonov
    Windermere, FL, USA
    2018-09-07

*)

BeginPackage["DataReshape`"];

TypeOfDataToBeReshaped::usage = "TypeOfDataToBeReshaped[data] gives association with data type elements.";

ToLongForm::usage = "ToLongForm[ds_Dataset, idColumns_, variableColumns_, opts___] \
converts the dataset ds into long form.";

PivotLonger::usage = "PivotLonger[ds_Dataset, columns_, opts___] \
\"lengthens\" data, increasing the number of rows and decreasing the number of columns.";

ToWideForm::usage = "ToWideForm[ds_Dataset, idColumn_, variableColumn_, valueColumn_] \
converts the dataset ds into wide form. The result dataset has columns that are unique values of \
variableColumn. The cell values of the result dataset are derived by applying a specified \
aggregation function over each of the lists of valueColumn values that correspond \
to unique pairs of {idColumn, variableColumn}. \
The aggregation function is specified with the option \"AggregationFunction\".";

RecordsToLongForm::usage = "RecordsToLongForm[records: Association[(_ -> _Association) ..]] \
converts an association of associations into a long form dataset.";

RecordsToWideForm::usage = "RecordsToWideForm[records: { (_Association) ..}, aggrFunc_] \
converts a list of associations into a wide form dataset using a specified aggregation function.";

Begin["`Private`"];

(***********************************************************)
(* Column specs                                            *)
(***********************************************************)

Clear[ColumnSpecQ];

ColumnSpecQ[x_] := IntegerQ[x] || StringQ[x] || MatchQ[x, Key[__]];


(***********************************************************)
(* TypeOfDataToBeReshaped                                      *)
(***********************************************************)

Clear[TypeOfDataToBeReshaped];

TypeOfDataToBeReshaped[ data_Association ] := { "Type" -> "Association", "ColumnNames" -> None, "RowNames" -> None };

TypeOfDataToBeReshaped[ data_Dataset ] :=
    Block[{namedRowsQ = False, firstRecord, colNames, resType},

      If[ AssociationQ[Normal[data]],
        namedRowsQ = True;
      ];

      firstRecord = Normal[data[1, All]];
      colNames = If[ AssociationQ[firstRecord], Keys[firstRecord], None ];

      resType =
          Which[
            TrueQ[colNames === None] && !namedRowsQ,
            "Dataset-NoColumnNames-NoRowNames",

            TrueQ[colNames === None] && namedRowsQ,
            "Dataset-NoColumnNames-RowNames",

            ListQ[colNames] && namedRowsQ,
            "Dataset-ColumnNames-RowNames",

            ListQ[colNames] && !namedRowsQ,
            "Dataset-ColumnNames-NoRowNames",

            True,
            Echo[ "Unhandled dataset case!", "TypeOfDataToBeReshaped:" ];
            Return[$Failed]
          ];

      {"Type" -> resType, "ColumnNames" -> colNames, "RowNames" -> If[ namedRowsQ, Keys @ Normal @data, None ] }

    ];


(***********************************************************)
(* ToLongForm                                              *)
(***********************************************************)

Clear[ToLongForm];

SyntaxInformation[ToLongForm] = { "ArgumentsPattern" -> { _, _., _., OptionsPattern[] } };

Options[ToLongForm] = { "AutomaticKeysTo" -> "AutomaticKey", "VariablesTo" -> "Variable", "ValuesTo" -> "Value" };

ToLongForm[ds_Association, opts : OptionsPattern[] ] := RecordsToLongForm[ds, opts];

ToLongForm[ds_Dataset, Automatic, Automatic, opts : OptionsPattern[] ] :=
    ToLongForm[ds, opts];

ToLongForm[ds_Dataset, isColumn_?ColumnSpecQ, valueColumns_, opts : OptionsPattern[] ] :=
    ToLongForm[ds, {isColumn}, valueColumns, opts];

ToLongForm[ds_Dataset, idColumns_, valueColumn_?ColumnSpecQ, opts : OptionsPattern[] ] :=
    ToLongForm[ds, idColumns, {valueColumn}, opts];

ToLongForm[ds_Dataset, opts : OptionsPattern[] ] :=
    ToLongForm[ ds, {0}, Range[ Length[ ds[1] ] ], opts ];

ToLongForm[ds_Dataset, Automatic, valueColumns : {_Integer ..}, opts : OptionsPattern[] ] :=
    Block[{idColumns},

      idColumns = Complement[ Range @ Length[ds[1]], valueColumns ];

      If[ Length[idColumns] == 0, idColumns = {0} ];

      ToLongForm[ds, idColumns, valueColumns, opts]
    ];

ToLongForm[ds_Dataset, idColumns : {_Integer ..}, Automatic, opts : OptionsPattern[] ] :=
    Block[{valueColumns},

      valueColumns = Complement[ Range @ Length[ds[1]], idColumns ];

      If[ Length[valueColumns] == 0,
        ds,
        (*ELSE*)
        ToLongForm[ds, idColumns, valueColumns, opts]
      ]
    ];

ToLongForm[ds_Dataset, idColumns : {_Integer ..}, valueColumns : {_Integer ..}, opts : OptionsPattern[] ] :=
    Block[{records = Normal[ds], cnAuto},

      cnAuto = OptionValue[RecordsToLongForm, "AutomaticKeysTo"];

      records =
          Which[
            TrueQ[idColumns == {0}] && MatchQ[records, Association[(_ -> _Association) ..]],
            Association@
                KeyValueMap[<|cnAuto -> #1|> -> KeyTake[#2, Keys[#2][[valueColumns]]] &, records],

            ! TrueQ[idColumns == {0}] && MatchQ[records, Association[(_ -> _Association) ..]],
            Association@
                Map[KeyTake[#, Keys[#][[idColumns]]] ->
                    KeyTake[#, Keys[#][[valueColumns]]] &, Values[records]],

            TrueQ[idColumns == {0}] && MatchQ[records, List[_Association ..]],
            Association@
                MapIndexed[<|cnAuto -> #2[[1]]|> -> KeyTake[#1, Keys[#1][[valueColumns]]] &, records],

            MatchQ[records, List[(_Association) ..]],
            Association@
                Map[KeyTake[#, Keys[#][[idColumns]]] ->
                    KeyTake[#, Keys[#][[valueColumns]]] &, records],

            TrueQ[idColumns == {0}] && MatchQ[records, List[(_List) ..]],
            Association@
                MapIndexed[
                  <| cnAuto -> #2[[1]] |> -> AssociationThread[ToString /@ valueColumns, #1[[valueColumns]]] &,
                  records],

            MatchQ[records, List[(_List) ..]],
            Association@
                Map[AssociationThread[ToString /@ idColumns, #[[idColumns]]] ->
                    AssociationThread[ToString /@ valueColumns, #[[valueColumns]]] &,
                  records],

            True,
            Return[$Failed]
          ];

      RecordsToLongForm[records, opts]

    ] /; (TrueQ[idColumns == {0}] ||
        Apply[And, Map[1 <= # <= Dimensions[ds][[2]] &, idColumns]]) &&
        Apply[And, Map[1 <= # <= Dimensions[ds][[2]] &, valueColumns]] &&
        Length[Intersection[idColumns, valueColumns]] == 0;


ToLongForm::nocolkeys = "If the second and third arguments are not column indices the dataset should have named columns.";

ToLongForm::colkeys = "If the second and third arguments are not Automatic or column indices \
then they are expected to be columns names of the dataset.";

ToLongForm[ds_Dataset, idColumnsArg : ( Automatic | _List ), valueColumnsArg : ( Automatic | _List ), opts : OptionsPattern[] ] :=
    Block[{idColumns = idColumnsArg, valueColumns = valueColumnsArg, keys},

      keys = Normal[ds[1]];

      If[!AssociationQ[keys],
        Message[ToLongForm::nocolkeys];
        Return[$Failed]
      ];

      keys = Keys[keys];

      If[
          !( TrueQ[ idColumns === Automatic ] || Length[idColumns] == 0 || Apply[And, Map[ MemberQ[keys, #]&, idColumns ] ] ) ||
              !( TrueQ[ valueColumns === Automatic ] || Apply[And, Map[ MemberQ[keys, #]&, valueColumns ] ] ),

        Message[ToLongForm::colkeys];
        Return[$Failed]
      ];

      If[ TrueQ[ idColumns === Automatic ],
        idColumns = Complement[keys, valueColumns];
      ];

      If[ TrueQ[ valueColumns === Automatic ],
        valueColumns = Complement[keys, idColumns];
      ];

      Which[
        Length[valueColumns] == 0,
        ds,

        Length[idColumns] == 0,
        ToLongForm[ds, {0}, Flatten[Position[keys, #]& /@ valueColumns], opts ],

        True,
        ToLongForm[ds, Flatten[Position[keys, #]& /@ idColumns], Flatten[Position[keys, #]& /@ valueColumns], opts ]
      ]

    ];

ToLongForm[ds_Dataset, "AutomaticKey", valueColumns_List, opts : OptionsPattern[] ] :=
    Block[{keys},
      keys = Normal[ds[1]];

      If[!AssociationQ[keys],
        Message[ToLongForm::nocolkeys];
        Return[$Failed]
      ];

      keys = Keys[keys];

      If[ ! Apply[And, Map[ MemberQ[keys, #]&, valueColumns ] ],
        Message[ToLongForm::colkeys];
        Return[$Failed]
      ];

      ToLongForm[ds, 0, Flatten[Position[keys, #]& /@ valueColumns], opts ]
    ];

ToLongForm::args = "The first argument is expected to be an association or a dataset. \
If the first argument is an association then no other arguments are expected. \
If the first argument is a dataset then the rest of the arguments are expected to be columns specifications or Automatic.";

ToLongForm[___] :=
    Block[{},
      Message[ToLongForm::args];
      $Failed
    ];


(* RecordsToLongForm is an "internal" function. It is assumed that all records have the same keys. *)
(* valueColumns is expected to be a list of keys that is a subset of the records keys. *)

Clear[NotAssociationQ];
NotAssociationQ[x_] := Not[AssociationQ[x]];

Clear[RecordsToLongForm];

Options[RecordsToLongForm] = Options[ToLongForm];

RecordsToLongForm[records : Association[( _?NotAssociationQ -> _Association) ..], opts : OptionsPattern[]] :=
    Block[{cnAuto},
      cnAuto = OptionValue[RecordsToLongForm, "AutomaticKeysTo"];
      RecordsToLongForm[ KeyMap[ <|cnAuto -> #|>&, records ], opts ];
    ];

RecordsToLongForm[records : Association[(_Association -> _Association) ..], opts : OptionsPattern[] ] :=
    Block[{cnVariables, cnValues, res},

      cnVariables = OptionValue[RecordsToLongForm, "VariablesTo"];
      cnValues = OptionValue[RecordsToLongForm, "ValuesTo"];

      res =
          KeyValueMap[
            Function[{k, rec}, Map[Join[k, <|cnVariables -> #, cnValues -> rec[#]|>] &, Keys[rec]]],
            records
          ];

      Dataset[Flatten[res]]
    ];


(***********************************************************)
(* PivotLonger                                             *)
(***********************************************************)

(* More or less follows the interface of the R-package function tidyr::pivot_longer . *)

Clear[PivotLonger];

Options[PivotLonger] = {
  "Data" -> None,
  "Columns" -> None,
  "NamesTo" -> "Variable",
  "ValuesTo" -> "Value",
  "DropMissingValues" -> False
};

PivotLonger[ds_Association, opts : OptionsPattern[] ] := ToLongForm[ds, opts];

PivotLonger[ data_Dataset, columnSpec : _?ColumnSpecQ, opts : OptionsPattern[] ] :=
    PivotLonger[ data, {columnSpec}, opts];

PivotLonger[ data_Dataset, columnsArg : { _?ColumnSpecQ  ..}, opts : OptionsPattern[] ] :=
    Block[{columns = columnsArg, cnVariables, cnValues, dropMissingQ, res},

      cnVariables = OptionValue[PivotLonger, "NamesTo"];
      cnValues = OptionValue[PivotLonger, "ValuesTo"];
      dropMissingQ = OptionValue[PivotLonger, "DropMissingValues"];

      res = ToLongForm[ data, Automatic, columns, "VariablesTo" -> cnVariables, "ValuesTo" -> cnValues ];

      If[ dropMissingQ,
        res = res[ Select[ !MissingQ[#[cnValues]]& ] ];
      ];

      res
    ];


(***********************************************************)
(* ToWideForm                                              *)
(***********************************************************)

(* Essentially a contingency dataset making. *)

Clear[ToWideForm];

Options[ToWideForm] = {"AggregationFunction" -> Total};

ToWideForm[ ds_Dataset, idColumn_Integer, variableColumn_Integer, valueColumn_Integer, opts : OptionsPattern[] ] :=
    Block[{records = Normal[ds]},

      records =
          Which[
            TrueQ[idColumn == 0] && MatchQ[records, Association[(_ -> _Association) ..]],
            KeyValueMap[ <| "AutomaticKey" -> #1, Values[#2][[variableColumn]] -> Values[#2][[valueColumn]] |> &, records],

            ! TrueQ[idColumn == 0] && MatchQ[records, Association[(_ -> _Association) ..]],
            Map[ <| Keys[#][[idColumn]] -> Values[#][[idColumn]] , Values[#][[variableColumn]] -> Values[#][[valueColumn]] |> &, Values[records]],

            MatchQ[records, List[(_Association) ..]],
            Map[ <| Keys[#][[idColumn]] -> Values[#][[idColumn]] , Values[#][[variableColumn]] -> Values[#][[valueColumn]] |> &, records],

            MatchQ[records, List[(_List) ..]],
            Map[ <| idColumn -> #[[idColumn]], #[[variableColumn]] -> #[[valueColumn]] |> &, records],

            True,
            Return[$Failed]
          ];

      RecordsToWideForm[records, OptionValue[ToWideForm, "AggregationFunction"] ]

    ] /; ( idColumn == 0 || 1 <= idColumn <= Dimensions[ds][[2]] ) &&
        ( 1 <= variableColumn <= Dimensions[ds][[2]] ) &&
        ( 1 <= valueColumn <= Dimensions[ds][[2]] ) &&
        ( Length[Union[{idColumn, variableColumn, valueColumn}]] == 3);


ToWideForm::nocolkeys = "If the second and third arguments are not column indices the dataset should have named columns.";

ToWideForm::colkeys = "If the second, third, and fourth arguments are not column indices then they are expected to be columns names of the dataset.";

ToWideForm[ds_Dataset, idColumn_, variableColumn_, valueColumn_, opts : OptionsPattern[] ] :=
    Block[{keys},
      keys = Normal[ds[1]];

      If[!AssociationQ[keys],
        Message[ToWideForm::nocolkeys];
        Return[$Failed]
      ];

      keys = Keys[keys];

      If[ ! Apply[And, Map[ MemberQ[keys, #]&, {idColumn, variableColumn, valueColumn} ] ],
        Message[ToWideForm::colkeys];
        Return[$Failed]
      ];

      ToWideForm[ds, Sequence @@ Flatten[Position[keys, #]& /@ {idColumn, variableColumn, valueColumn}], opts ]
    ];

ToWideForm[ds_Dataset, "AutomaticKey", variableColumn_, valueColumn_, opts : OptionsPattern[] ] :=
    Block[{keys},
      keys = Normal[ds[1]];

      If[!AssociationQ[keys],
        Message[ToWideForm::nocolkeys];
        Return[$Failed]
      ];

      keys = Keys[keys];

      If[ ! Apply[And, Map[ MemberQ[keys, #]&, {variableColumn, valueColumn} ] ],
        Message[ToWideForm::colkeys];
        Return[$Failed]
      ];

      ToWideForm[ds, 0, Sequence @@ Flatten[Position[keys, #]& /@ { variableColumn, valueColumn}], opts ]
    ];

ToWideForm::args = "The first argument is expected to be a dataset; \
the rest of the arguments are expected to be columns specifications.";

ToWideForm[___] :=
    Block[{},
      Message[ToWideForm::args];
      $Failed
    ];


RecordsToWideForm[records : { (_Association) ..}, aggrFunc_] :=
    Block[{res, colNames},

      res = GroupBy[records, {Keys[#][[1]] -> #[[1]], Keys[#][[2]]} &, aggrFunc@Map[Function[{r}, r[Keys[r][[2]]]], #] &];
      res = KeyValueMap[<|#1[[1]], #1[[2]] -> #2|> &, res];

      res = Dataset[GroupBy[res, #[[1]] &, Join[Association[#]] &]];

      colNames = DeleteDuplicates[Flatten[Values[Normal[res[All, Keys]]]]];

      res[All, Join[AssociationThread[colNames -> Missing[]], #]& ]
    ];


End[]; (* `Private` *)

EndPackage[];