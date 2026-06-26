-module(aoc).
-compile(export_all).

% Range returns a list with integers from [Lower, Upper]
-spec range(integer(), integer()) -> [integer()].
range(Lower, Upper) -> lists:reverse(range(Lower, Upper, [])).
% Tail recursive
-spec range(integer(), integer(), [integer()]) -> [integer()].
range(Lower, Upper, Acc) when Lower > Upper -> Acc;
range(Lower, Upper, Acc) -> range(Lower+1, Upper, [Lower | Acc]).

% repeats_twice is true iif N is composed of a sequence repeated twice
-spec repeats_twice(integer()) -> boolean().
repeats_twice(N) ->
    NList = integer_to_list(N),
    if
        length(NList) rem 2 =:= 0 ->
            NList1 = lists:sublist(NList, 1, length(NList) div 2),
            NList2 = lists:sublist(NList, (length(NList) div 2) + 1, length(NList) div 2),
            NList1 == NList2;
        true -> false
    end.

% repeats returns true if the prefix indicated by Idx can generate the whole list
-spec repeats(integer(), [term()]) -> boolean().
repeats(Idx, List) ->
    if
        length(List) rem Idx =/= 0 -> false;
        true ->
            Prefix = lists:sublist(List, Idx),
            Times = length(List) div Idx,
            lists:flatten(lists:duplicate(Times, Prefix)) == List
    end.

% repeats_any_times is true if there is a single sequence that conforms Ns digits that repeats at least twice
-spec repeats_any_times(integer()) -> boolean().
repeats_any_times(N) ->
    NList = integer_to_list(N),
    lists:any(
        fun(Idx) -> repeats(Idx, NList) end,
        range(1, length(NList) div 2)).


-spec read_lines(file:name_all()) -> [binary()].
read_lines(Path) ->
    {ok, Bin} = file:read_file(Path),
    Parts = binary:split(Bin, ~",", [global, trim]),
    [string:trim(P) || P <- Parts].

-spec to_range(binary()) -> {integer(), integer()}.
to_range(Bin) ->
    [Lower, Upper] = binary:split(Bin, ~"-", [global, trim]),
    {binary_to_integer(Lower), binary_to_integer(Upper)}.

part1() ->
    Lines = read_lines('day2.input'),
    Ranges = [to_range(Line) || Line <- Lines],
    RepeatingTwice = lists:map(
        fun({Lower, Upper}) ->
            [ N || N <- range(Lower, Upper), repeats_twice(N)]
        end,
        Ranges),
    lists:sum(lists:uniq(lists:flatten(RepeatingTwice))).

part2() ->
    Lines = read_lines('day2.input'),
    Ranges = [to_range(Line) || Line <- Lines],
    Repeats = lists:map(
        fun({Lower, Upper}) ->
            [ N || N <- range(Lower, Upper), repeats_any_times(N)]
        end,
        Ranges),
    lists:sum(lists:uniq(lists:flatten(Repeats))).
