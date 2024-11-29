#!/usr/bin/env raku

use lib <. lib>;
use Graphviz::DOT::Chessboard;

# Empty chessboard
say dot-chessboard(4, 4, title => 'Example small chessboard'):!svg;

# Some pieces
say dot-chessboard([(1, 1, 'N'), (2, 3, 'q')], :4r, :4c):!svg;
