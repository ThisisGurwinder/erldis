-module(erldis_pool_sup_tests).

-include_lib("eunit/include/eunit.hrl").

pool_sup_monitor_test() ->
    {timeout, 30, fun() ->
        % kill the pool if it already exists
        erldis_pool_sup:stop(),

        ConnList = [
        {{"localhost", 6379}, 5},
        {{"localhost", 6379}, 2}
        ],

        RestartFreq = 5000,
        application:set_env(erldis, pool_sup_restart_frequency, RestartFreq),
        {ok, Pid} = erldis_pool_sup:start_link(ConnList, true),
        unlink(Pid),
        Pids = erldis_pool_sup:get_pids({"localhost", 6379}),
        ?assertEqual(7, length(Pids)),

        % Kill the supervisor, sleep until frequency has elapsed, and make sure it has returned
        ?assertEqual(Pid, whereis(erldis_pool_sup)),
        exit(Pid, kill),
        %timer:sleep(RestartFreq),
        ?assertNot(Pid =:= whereis(erldis_pool_sup))
    end}.

pool_test() ->
    % kill the pool if it already exists
    erldis_pool_sup:stop(),

    ConnList = [
    {{"localhost", 6379}, 5},
    {{"localhost", 6379}, 2}
    ],
    unlink(element(2, erldis_pool_sup:start_link(ConnList, false))),
    Pids = erldis_pool_sup:get_pids({"localhost", 6379}),
    ?assertEqual(7, length(Pids)),

    RandomPid = erldis_pool_sup:get_random_pid({"localhost", 6379}),
    ?assertEqual([RandomPid], lists:filter(fun(Pid) -> Pid =:= RandomPid end, Pids)),

    % Increment a key on each connection
    PoolSupCounterKey = <<"pool_sup_counter">>,
    lists:foreach(fun(Client) ->
        erldis:incr(Client, PoolSupCounterKey)
    end, erldis_pool_sup:get_pids({"localhost", 6379})),

    % Check the counter
    ?assertEqual(integer_to_list(length(Pids)), binary_to_list(erldis:get(lists:nth(1, Pids), PoolSupCounterKey))).