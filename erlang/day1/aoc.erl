-module(aoc).
-compile(export_all).

-type dial()     :: {dial, integer(), integer()}.
-type rotation() :: {rotation, left | right, integer()}.

% Mod: Because rem is remainder, not modulo
-spec mod(integer(), integer()) -> integer().
mod(A, B) -> ((A rem B) + B) rem B.

% Rotation: left/right and an amount
-spec new_rotation(left | right, integer()) -> rotation().
new_rotation(left, N) -> {rotation, left, N};
new_rotation(right, N) -> {rotation, right, N}.

% Dial: Current position, max (inclusive) value
-spec new_dial(integer(), integer()) -> dial().
new_dial(C, M) -> {dial, C, M}.

% Rotate a dial
-spec rotate(dial(), rotation()) -> dial().
rotate({dial, C, M}, R) ->
    case R of
        {rotation, left, N} -> {dial, mod(C-N,M+1), M};
        {rotation, right, N} -> {dial, mod(C+N,M+1), M}
    end.

% How many zeroes does a rotation generate
-spec rotation_zeroes(dial(), rotation()) -> integer().
rotation_zeroes({dial, C, M}, {rotation, Direction, N}) ->
    case Direction of
        right -> (C + N) div (M+1);
        % We convert to a 'right' turn by moving C to its complementary
        % (M+1) - C, and then taking remainder just in case C is 0.
        % If C is already 0 we don´t count as a zero click.
        left -> ((((M+1) - C) rem (M+1)) + N) div (M+1)
    end.

-spec read_lines(file:name_all()) -> [binary()].
read_lines(Path) ->
    {ok, Bin} = file:read_file(Path),
    binary:split(Bin, ~"\n", [global, trim]).

-spec line_to_rotation(binary()) -> rotation().
line_to_rotation(<<"L", N/binary>>) -> new_rotation(left, binary_to_integer(N));
line_to_rotation(<<"R", N/binary>>) -> new_rotation(right, binary_to_integer(N)).

part1() ->
    Lines = read_lines('day2.input'),
    Rotations = lists:map(fun line_to_rotation/1, Lines),
    Dial = new_dial(50, 99),
    {Zeroes, _ } = lists:mapfoldl(
        fun(Rotation, Acc) ->
            Rotated = rotate(Acc, Rotation),
           {rotation_zeroes(Acc, Rotation), Rotated}
       end, Dial, Rotations),
    lists:sum(Zeroes).

part2() ->
    Lines = read_lines('day1.input'),
    Rotations = lists:map(fun line_to_rotation/1, Lines),
    Dial = new_dial(50, 99),
    {Positions, _ } = lists:mapfoldl(
        fun(Rotation, Acc) ->
            R = rotate(Acc, Rotation),
           {R, R}
       end, Dial, Rotations),
    length(lists:filter(
        fun({dial, 0, _}) -> true;
                 ({dial, _, _}) -> false
              end, Positions)).
