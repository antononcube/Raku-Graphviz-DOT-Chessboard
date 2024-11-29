unit module Graphviz::DOT::Chessboard;

use Graph;
use Graph::Grid;
use Graph::Path;

#==========================================================
# This code is the same as the method Graph!dot-svg.
# But I do not want to Graph to the non-private method dot-svg.
# Also, having this sub in the package makes the combinations of
# chessboard elements easier.
sub dot-svg($input, Str:D :$engine = 'dot', Str:D :$format = 'svg') {
    my $temp-file = $*TMPDIR.child("temp-graph.dot");
    $temp-file.spurt: $input;
    my $svg-output = run($engine, $temp-file, "-T$format", :out).out.slurp-rest;
    unlink $temp-file;
    return $svg-output;
}

#==========================================================
#| Chessboard generation via Graphviz DOT language spec.
proto sub dot-chessboard(|) is export {*}

multi sub dot-chessboard(*%args) {
    return dot-chessboard(rows => 8, columns => 8, |%args);
}

multi sub dot-chessboard(UInt:D $rows, UInt:D $columns, *%args) {
    return dot-chessboard(:$rows, :$columns, |%args);
}

multi sub dot-chessboard(
        UInt:D :r(:$rows),
        UInt:D :c(:$columns),
        Str:D :$background = '#1F1F1F',
        Str:D :$font-color = 'Ivory',
        Str:D :white(:$white-squares-color) = 'LightGray',
        Str:D :black(:$black-squares-color) = 'DimGray',
        UInt:D :$tick-font-size = 14,
        Numeric:D :$tick-offset = 0.7,
        Str:D :title(:$plot-label) = '',
        :size(:$graph-size) is copy = Whatever,
        Bool:D :$svg = False) {

    #------------------------------------------------------
    # Process graph size
    if $graph-size.isa(Whatever) { $graph-size = ($rows, $columns) }
    if $graph-size ~~ Positional:D && $graph-size.elems == 2 { $graph-size = $graph-size.join(',') ~ '!'}
    die 'The value of $graph-size is expected to be a list of two integers, a string size spec, or Whatever.'
    unless $graph-size ~~ Str:D;

    #------------------------------------------------------
    # Leveraging that grid graphs are bipartite
    # Bipartite graph
    my $g = Graph::Grid.new($rows, $columns);

    # Make sure the left bottom square is black
    my %colors = $g.bipartite-coloring;
    my %replace;
    %replace{%colors<0_0>} = $black-squares-color;
    %replace{%colors<0_1>} = $white-squares-color;

    my %highlight = %colors.map({ $_.key => %replace{$_.value} }).classify(*.value).nodemap(*».key);

    #------------------------------------------------------
    # DOT language spec
    my $preamble = Q:s:to/END/;
    fontcolor = "$font-color";
    fontsize = "16";
    labelloc = "t";
    label = "$plot-label";
    graph [size="$graph-size"];

    bgcolor="$background";
    node [style=filled, opacity=0.3, fixedsize=true, shape=square, color="Black", fillcolor="SlateBlue", penwidth=1, fontsize=4, fontcolor="White", labelloc=c, width=0.98, height=0.98];
    edge [style=invis, color="SteelBlue", penwidth=0.6];
    END

    my $board-dot = $g.dot(:$preamble, :%highlight, :!node-labels);
    $board-dot .= subst(/ ^ graph .*? '{' | \s* '}' \s*/, :g);

    #------------------------------------------------------
    # Ticks
    my @row-ticks = ('a'..'z').head($columns);
    my $gr = Graph::Path(@row-ticks);
    $gr.vertex-coordinates = (@row-ticks Z=> (^$columns X -$tick-offset)).Hash;
    my $gc = Graph::Path(1..$rows);
    $gc.vertex-coordinates = (1..$rows Z=> (-$tick-offset X ^$rows)).Hash;
    my $gt = $gr.union($gc);

    my $ticks-dot = $gt.dot.subst(/ ^ graph .*? '{' | \s* '}' \s*/, :g);

    my $ticks-preamble = Q:s:to/END/;
    node [color=none, fillcolor=none, fontcolor=$font-color, labelloc=c, fontsize=$tick-font-size];
    edge [style=invis];
    END

    $ticks-dot = $ticks-preamble ~ "\n" ~ $ticks-dot;

    #------------------------------------------------------
    # Combine DOT fragments
    my $combined-dot = "graph \{\n$board-dot\n\n$ticks-dot\n\}";

    #------------------------------------------------------
    # DOT spec if $svg is False, otherwise rendering of the DOT spec to SVG.
    return $svg ?? dot-svg($combined-dot, engine => 'neato', format => 'svg') !! $combined-dot;
}
