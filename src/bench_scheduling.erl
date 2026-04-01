% Scheduler responsiveness checker.
%
% Check that JSON encoding/decoding doesn't block schedulers. Send an example
% term back and forth between processes encoding and decoding it, simulating
% some server workloading doing the same concurrently. Start with one pair,
% then scale it with the number of schedulers 1x and 2x.
%
% We'd like to gracefully degrade and not hit scheduler collapse or block
% schedulers too long.
%
% Config with env vars. This is called from bench_scheduling.sh usually
%
%   BENCH_IMPLS       (default "jiffy")   jiffy,json,simdjsone,jsone,jsx
%   BENCH_JSON        (default citm-catalog.json)
%   BENCH_DURATION_MS (default 2000)

-module(bench_scheduling).

-export([main/0]).

duration_ms() ->
    list_to_integer(os:getenv("BENCH_DURATION_MS", "2000")).

json_file() ->
    os:getenv("BENCH_JSON", "citm-catalog.json").

impls() ->
    string:split(os:getenv("BENCH_IMPLS", "jiffy"), ",", all).

main() ->
    DurMs = duration_ms(),
    JsonFile   = json_file(),
    Impls      = impls(),
    {ok, Json} = file:read_file(filename:join("data", JsonFile)),
    Term       = jiffy:decode(Json, [return_maps]),
    Scheds = erlang:system_info(schedulers_online),
    io:format("scheduler responsiveness check~n"),
    io:format("  input:       ~s duration: ~p~n", [JsonFile, DurMs]),
    io:format("  schedulers:  ~p online~n", [Scheds]),
    io:format("  impls:       ~s~n", [string:join(Impls, ", ")]),
    [run_impl(Impl, Json, Term, DurMs, Scheds) || Impl <- Impls],
    ok.

run_impl(Impl, Json, Term, DurMs, Scheds) ->
    {DecFn, EncFn} = fns_for(Impl),
    io:format("~n[~s]~n", [Impl]),
    % Sanity check
    DecFn(Json), EncFn(Term),
    run_encdec(label("~px encdec", [1]), DecFn, EncFn, Json, Scheds, DurMs),
    run_encdec(label("~px encdec", [Scheds]), DecFn, EncFn, Json, Scheds, DurMs),
    run_encdec(label("~px encdec", [2 * Scheds]), DecFn, EncFn, Json, 2 * Scheds, DurMs).

% Add new implementations here
fns_for("jiffy") ->
    { fun(J) -> jiffy:decode(J, [return_maps]) end,
      fun(T) -> jiffy:encode(T) end };
fns_for("json") ->
    { fun(J) -> json:decode(J) end,
      fun(T) -> json:encode(T) end };
fns_for("simdjsone") ->
    { fun(J) -> simdjson:decode(J) end,
      fun(T) -> simdjson:encode(T) end };
fns_for("jsone") ->
    { fun(J) -> jsone:decode(J) end,
      fun(T) -> jsone:encode(T) end };
fns_for("jsx") ->
    { fun(J) -> jsx:decode(J) end,
      fun(T) -> jsx:encode(T) end };
fns_for(Other) ->
    error({unknown_impl, Other}).

run_encdec(Label, DecFn, EncFn, Json, N, DurMs) ->
    Parent = self(),
    Pings = [start_pair(Parent, DecFn, EncFn, Json) || _ <- lists:seq(1, N)],
    timer:sleep(100),  % wait a bit for them to start
    [P ! go || P <- Pings],
    timer:sleep(DurMs),
    [P ! stop || P <- Pings],
    Samples = collect(N, []),
    io:format("  ~-28s ~s~n", [Label, fmt(stats(Samples))]).

start_pair(Parent, DecFn, EncFn, Bin) ->
    B = spawn(fun() -> echo_loop(DecFn, EncFn) end),
    spawn(fun() -> ping_loop(Parent, B, DecFn, EncFn, Bin, []) end).

ping_loop(Parent, Peer, DecFn, EncFn, Bin, Samples) ->
    receive
        go ->
            ping_cycle(Parent, Peer, DecFn, EncFn, Bin, Samples);
        stop ->
            Peer ! stop,
            Parent ! {res, lists:reverse(Samples)}
    end.

ping_cycle(Parent, Peer, DecFn, EncFn, Bin, Samples) ->
    T0 = usec(),
    Peer ! {ping, self(), Bin},
    receive
        {pong, BinBack} ->
            RTT = usec() - T0,
            Term = DecFn(BinBack),
            NewBin = iolist_to_binary(EncFn(Term)),
            ping_cycle(Parent, Peer, DecFn, EncFn, NewBin, [RTT | Samples]);
        stop ->
            Peer ! stop,
            Parent ! {res, lists:reverse(Samples)}
    end.

echo_loop(DecFn, EncFn) ->
    receive
        {ping, From, Bin} ->
            Term = DecFn(Bin),
            From ! {pong, iolist_to_binary(EncFn(Term))},
            echo_loop(DecFn, EncFn);
        stop ->
            ok
    end.

collect(0, Acc) -> Acc;
collect(N, Acc) ->
    receive
        {res, Samples} -> collect(N - 1, Samples ++ Acc)
    end.

stats([]) ->
    #{n => 0, p50 => 0, p95 => 0, p99 => 0, max => 0};
stats(Samples) ->
    Sorted = lists:sort(Samples),
    N = length(Sorted),
    At = fun(P) -> lists:nth(max(1, (N * P) div 100), Sorted) end,
    #{
        n   => N,
        p50 => At(50),
        p95 => At(95),
        p99 => At(99),
        max => lists:last(Sorted)
    }.

fmt(#{n := N, p50 := P50, p95 := P95, p99 := P99, max := Max}) ->
    io_lib:format("n=~p p50=~s p95=~s p99=~s max=~s",
                  [N, u(P50), u(P95), u(P99), u(Max)]).

u(Us) when Us >= 1000 ->
    io_lib:format("~.1fms", [Us / 1000]);
u(Us) ->
    io_lib:format("~pus", [Us]).

label(Fmt, Args) ->
    lists:flatten(io_lib:format(Fmt, Args)).

usec() ->
    erlang:monotonic_time(microsecond).
