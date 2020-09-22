//# Tries with frequencies Java implementation
//# Copyright (C) 2016  Anton Antonov
//#
//# This program is free software: you can redistribute it and/or modify
//# it under the terms of the GNU General Public License as published by
//# the Free Software Foundation, either version 3 of the License, or
//# (at your option) any later version.
//#
//# This program is distributed in the hope that it will be useful,
//# but WITHOUT ANY WARRANTY; without even the implied warranty of
//# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//# GNU General Public License for more details.
//#
//# You should have received a copy of the GNU General Public License
//# along with this program.  If not, see <http://www.gnu.org/licenses/>.
//#
//# Written by Anton Antonov,
//# antononcube @ gmail. com ,
//# Windermere, Florida, USA.
//#
//# Version 1.0
//# The Java code in this file corresponds to the Mathematica package
//# "Tries with frequencies" also written by Anton Antonov:
//# https://github.com/antononcube/MathematicaForPrediction/blob/master/TriesWithFrequencies.m .
//# There is also an R package with implementing that functionality:
//# https://github.com/antononcube/MathematicaForPrediction/blob/master/R/TriesWithFrequencies.R .
//# Both packages are part of the MathematicaForPrediction project at GitHub.
//#
//# For detailed explanations see the blog post:
//# "Tries with frequencies for data mining",
//# https://mathematicaforprediction.wordpress.com/2013/12/06/tries-with-frequencies-for-data-mining/ .


import java.io.File;
import java.io.FileNotFoundException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Scanner;
import java.util.logging.Level;
import java.util.logging.Logger;



public class Experiments {

	public static void main( String args[] ) {

		basic();
	}

	public static void basic() {

		List<String> sampleSeq = new ArrayList<String>() {{ 
			add("arm"); add("arms"); add("arc"); add("bar"); add("bark"); add("barman"); add("arcola"); }};

			List< List<String> > sampleSeqList = new ArrayList<>();

			for ( String s : sampleSeq ) {			
				sampleSeqList.add( Arrays.asList( s.split("") ) );
			}

			System.out.println( sampleSeqList );

			Trie strie = TrieFunctions.create( sampleSeqList );

			System.out.println("strie = ");
			System.out.println( strie + "\n");

			List<String> sword = new ArrayList() {{ add("a"); add("r"); add("m"); }};
			Trie ftrie = TrieFunctions.retrieve( strie, sword );

			System.out.println("ftrie = ");
			System.out.println( ftrie + "\n" );

			Trie pstrie = TrieFunctions.nodeProbabilities( strie );

			System.out.println("pstrie = ");
			System.out.println( pstrie + "\n" );
	}

}
