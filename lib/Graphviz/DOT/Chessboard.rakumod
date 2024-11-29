unit module Graphviz::DOT::Chessboard;

use Graph;
use Graph::Grid;

#| Chessboard generation via Graphviz DOT language spec.
proto sub dot-chessboard(|) is export {*}

multi sub dot-chessboard(*%args) {
    return dot-chessboard(8, 8, |%args);
}

multi sub dot-chessboard(
        UInt:D $rows, UInt:D $cols,
        Str:D :white(:$white-squares-color) = 'LightGray',
        Str:D :black(:$black-squares-color) = 'DimGray',
        Str:D :title(:$plot-label) = '',
        :size(:$graph-size) is copy = Whatever,
        Bool:D :$svg = False) {

    #------------------------------------------------------
    # Process graph size
    if $graph-size.isa(Whatever) { $graph-size = ($rows, $cols) }
    if $graph-size ~~ Positional:D && $graph-size.elems == 2 { $graph-size = $graph-size.join(',') ~ '!'}
    die 'The value of $graph-size is expected to be a list of two integers, a string size spec, or Whatever.'
    unless $graph-size ~~ Str:D;

    #------------------------------------------------------
    # Leveraging that grid graphs are bipartite
    # Bipartite graph
    my $g = Graph::Grid.new($rows, $cols);

    # Make sure the left bottom square is black
    my %colors = $g.bipartite-coloring;
    my %replace;
    %replace{%colors<0_0>} = $black-squares-color;
    %replace{%colors<0_1>} = $white-squares-color;

    my %highlight = %colors.map({ $_.key => %replace{$_.value} }).classify(*.value).nodemap(*».key);

    #------------------------------------------------------
    # DOT language spec
    my $preamble = Q:s:to/END/;
    fontcolor = "Ivory";
    fontsize = "16";
    labelloc = "t";
    label = "$plot-label";
    graph [size="$graph-size"];

    bgcolor="#1F1F1F";
    node [style=filled, label="", opacity=0.3, fixedsize=true, shape=square, color="Black", fillcolor="SlateBlue", penwidth=1, fontsize=4, fontcolor="White", labelloc=c, width=0.98, height=0.3];
    edge [style=invis, color="SteelBlue", penwidth=0.6];
    END

    # DOT spec if $svg is False, otherwise rendering of the DOT spec to SVG.
    return $g.dot(:$preamble, :%highlight, :!node-labels, engine => 'neato', :$svg);
}
