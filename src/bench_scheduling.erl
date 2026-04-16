% Scheduler responsiveness checker.
%
% Check that json encoding/decoding does not block schedulers. This is an
% important feature of jiffy and we want to make sure it works.
%
% Confige time and test set with env vars:
%   BENCH_IMPLS       (default "jiffy") — comma-separated: jiffy,json
%   BENCH_JSON        (default citm-catalog.json)
%   BENCH_DURATION_MS (default 5000)

-module(bench_scheduling).

-export([main/0]).

duration_ms() ->
    list_to_integer(os:getenv("BENCH_DURATION_MS", "5000")).

json_file() ->
    os:getenv("BENCH_JSON", "citm-catalog.json").

impls() ->
    string:split(os:getenv("BENCH_IMPLS", "jiffy"), ",", all).

main() ->
    DurationMs = duration_ms(),
    JsonFile   = json_file(),
    Impls      = impls(),
    {ok, Json} = file:read_file(filename:join("data", JsonFile)),
    Term       = jiffy:decode(Json, [return_maps]),
    Schedulers = erlang:system_info(schedulers_online),

    io:format("scheduler responsiveness probe~n"),
    io:format("  input:       ~s (~p KB)~n", [JsonFile, byte_size(Json) div 1024]),
    io:format("  probe:       timer:sleep(1) jitter, ~pms per pass~n", [DurationMs]),
    io:format("  schedulers:  ~p online~n", [Schedulers]),
    io:format("  impls:       ~s~n", [string:join(Impls, ", ")]),

    lists:foreach(fun(Impl) ->
        run_impl(Impl, Json, Term, DurationMs, Schedulers)
    end, Impls).

run_impl(Impl, Json, Term, DurationMs, Schedulers) ->
    {Dec, Enc} = fns_for(Impl, Json, Term),
    io:format("~n[~s]~n", [Impl]),
    % Bit of warmup first and see if we can call these functions
    Dec(),
    Enc(),
    run_pass("idle (no workers)", Dec, 0, DurationMs),
    run_pass(label("~px decode", [Schedulers]), Dec, Schedulers, DurationMs),
    run_pass(label("~px encode", [Schedulers]), Enc, Schedulers, DurationMs),
    run_pass(label("~px decode", [2 * Schedulers]), Dec, 2 * Schedulers, DurationMs),
    run_pass(label("~px encode", [2 * Schedulers]), Enc, 2 * Schedulers, DurationMs).

fns_for("jiffy", Json, Term) ->
    {
       fun() -> jiffy:decode(Json, [return_maps]) end,
       fun() -> jiffy:encode(Term) end
    };
fns_for("json", Json, Term) ->
    {
       fun() -> json:decode(Json) end,
       fun() -> json:encode(Term) end
    };
fns_for(Other, _, _) ->
    error({unknown_impl, Other}).

run_pass(Label, Fun, NWorkers, DurationMs) ->
    Workers = [worker(Fun) || _ <- lists:seq(1, NWorkers)],
    [W ! start || W <- Workers],
    % Wait a bit for workers to start up
    timer:sleep(50),
    Samples = probe(DurationMs),
    [exit(W, kill) || W <- Workers],
    io:format("  ~-28s ~s~n", [Label, fmt(stats(Samples))]).

worker(Fun) ->
    spawn(fun() ->
        receive start -> ok end,
        worker_loop(Fun)
    end).

worker_loop(Fun) ->
    Fun(),
    worker_loop(Fun).

% Dead simple probe: sleep and measure jitter
%
probe(DurationMs) ->
    probe_loop(msec() + DurationMs, []).

probe_loop(Deadline, Acc) ->
    T0 = usec(),
    timer:sleep(1),
    Jitter = usec() - T0 - 1000,
    case msec() >= Deadline of
        true  -> lists:reverse([Jitter | Acc]);
        false -> probe_loop(Deadline, [Jitter | Acc])
    end.

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

msec() ->
    erlang:monotonic_time(millisecond).

usec() ->
    erlang:monotonic_time(microsecond).
