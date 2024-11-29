#!/usr/bin/env raku

use lib <. lib>;
use Graphviz::DOT::Chessboard;

say dot-chessboard(4, 4, title => 'Example small chessboard'):!svg;