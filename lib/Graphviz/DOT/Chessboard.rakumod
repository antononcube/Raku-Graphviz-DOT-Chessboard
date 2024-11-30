unit module Graphviz::DOT::Chessboard;

use Graph;
use Graph::Grid;
use Graph::Path;

#==========================================================
# DOT SVG
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
# Predicates
#==========================================================

sub is-positional-of-lists($obj, UInt $l) is export {
    ($obj ~~ Array:D | List:D | Seq:D) && $obj.elems && ( [and] $obj.map({ ($_ ~~ Array:D | List:D | Seq:D) && $_.elems == $l }) )
}

#==========================================================
# Process chess position specs
#==========================================================
my %chess-pieces =
        :p('♟'), :P('♙'), :r('♜'), :R('♖'),
        :n('♞'), :N('♘'), :b('♝'), :B('♗'),
        :q('♛'), :Q('♕'), :k('♚'), :K('♔');

my %white-to-black = :P('p'), :R('r'), :N('n'), :B('b'), :Q('q'), :K('k');
%white-to-black = %white-to-black , ('♙♖♘♗♕♔'.comb Z=> '♟♜♞♝♛♚'.comb).Hash;
my %black-to-white = %white-to-black.invert;

proto sub dot-chess-position($spec, *%args) is export {*}

multi sub dot-chess-position($data where is-positional-of-lists($data, 3), *%args) {
    my @data2 = $data.map({ %( <x y z>.Array Z=> $_.Array) });
    return dot-chess-position(@data2, |%args);
}

multi sub dot-chess-position(@data is copy where @data.all ~~ Map, UInt:D :$font-size=20) {
    return '' unless @data;

    my $k = 0;
    return @data.map({
        my $color =  '♟♜♞♝♛♚pnqrbk'.index($_<z>) ?? 'Black' !! 'White';
        my $label = %chess-pieces{$_<z>};
        my $label2 = %white-to-black{$label} // $label;
        my $x = do given $_<x> {
            when Int:D { $_ - 1 }
            when $_ ~~ / \d+ / { $_.Int - 1 }
            when $_ ~~ / \w / { $_.lc.ord - 'a'.ord }
        }
        my $y = $_<y> ~~ Int:D ?? $_<y> - 1 !! $_<y>.Int - 1;
        my $res = "\"p{$k++}\" [pos=\"$x,$y!\", fontsize=$font-size, fontcolor=$color, label=$label2]";
        if $label ne $label2 {
            $res ~= "\n\"p{$k++}\" [pos=\"$x,$y!\", fontsize=$font-size, fontcolor=Gray, label=$label]";
        }
        $res
    }).join("\n");
}

#==========================================================
# Main chessboard plot
#==========================================================
#| Chessboard generation via Graphviz DOT language spec.
proto sub dot-chessboard(|) is export {*}

multi sub dot-chessboard(UInt:D $rows, $columns is copy = Whatever, *%args) {
    if $columns.isa(Whatever) { $columns = $rows }
    die 'The value of the second argument is expected to be a positive integer or Whatever.'
    unless $columns ~~ Int:D && $columns > 0;

    return dot-chessboard([], :$rows, :$columns, |%args);
}

multi sub dot-chessboard(
        @data = [],
        UInt:D :r(:$rows) = 8,
        UInt:D :c(:$columns) = 8,
        Str:D :$background = '#1F1F1F',
        Str:D :$font-color = 'Ivory',
        UInt:D :$font-size = 70,
        Str:D :white(:$white-square-color) = 'LightGray',
        Str:D :black(:$black-square-color) = 'DimGray',
        UInt:D :$tick-font-size = 20,
        Numeric:D :$tick-offset = 0.7,
        Numeric:D :$opacity = 0.4,
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
    %replace{%colors<0_0>} = $black-square-color;
    %replace{%colors<0_1>} = $white-square-color;

    my %highlight = %colors.map({ $_.key => %replace{$_.value} }).classify(*.value).nodemap(*».key);

    #------------------------------------------------------
    # DOT language spec
    my $preamble = Q:s:to/END/;
    fontcolor = "$font-color";
    fontsize = "24";
    labelloc = "t";
    label = "$plot-label";
    graph [size="$graph-size"];

    bgcolor="$background";
    node [style=filled, opacity=$opacity, fixedsize=true, shape=square, color="Black", fillcolor="SlateBlue", penwidth=1, fontsize=4, fontcolor="White", labelloc=c, width=0.98, height=0.98];
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
    my $pieces = dot-chess-position(@data, :$font-size);

    #------------------------------------------------------
    # Combine DOT fragments
    my $combined-dot = "graph \{\n$board-dot\n\n$ticks-dot\n$pieces\n\}";

    #------------------------------------------------------
    # DOT spec if $svg is False, otherwise rendering of the DOT spec to SVG.
    return $svg ?? dot-svg($combined-dot, engine => 'neato', format => 'svg') !! $combined-dot;
}
