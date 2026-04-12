%%%-------------------------------------------------------------------
%%% @doc Color identification and harmonics agent.
%%%
%%% Takes a hex color code and returns its name, RGB, HSL, CMYK values
%%% and complementary color via The Color API (free, no key required).
%%%
%%% API: https://www.thecolorapi.com/id?hex={RRGGBB}
%%%
%%% Query forms accepted:
%%%   "#FF5733", "FF5733", "f57"  (CSS shorthand → expanded)
%%%   "color #FF5733"  (prefixed text is stripped)
%%%
%%% Handler contract: handle/2 (Body, Memory) -> {RawList, Memory}.
%%% @end
%%%-------------------------------------------------------------------
-module(color_filter_app).
-behaviour(application).

-export([start/2, stop/1]).
-export([handle/2, base_capabilities/0]).

-define(BASE_URL, "https://www.thecolorapi.com/id?hex=").

%%====================================================================
%% Capability cascade
%%====================================================================

-spec base_capabilities() -> [binary()].
base_capabilities() ->
    em_filter:base_capabilities() ++ [<<"color">>, <<"colour">>,
                                      <<"hex">>, <<"rgb">>,
                                      <<"palette">>].

%%====================================================================
%% Application behaviour
%%====================================================================

start(_Type, _Args) ->
    em_filter:start_agent(color_filter, ?MODULE, #{
        capabilities => base_capabilities()
    }),
    {ok, self()}.

stop(_State) ->
    em_filter:stop_agent(color_filter).

%%====================================================================
%% Agent handler
%%====================================================================

handle(Body, Memory) when is_binary(Body) ->
    {generate_embryo_list(Body), Memory};
handle(_Body, Memory) ->
    {[], Memory}.

%%====================================================================
%% Query processing
%%====================================================================

generate_embryo_list(JsonBinary) ->
    {Query, Timeout} = extract_params(JsonBinary),
    case extract_hex(Query) of
        error -> [];
        Hex   -> fetch_color(Hex, Timeout)
    end.

extract_params(JsonBinary) ->
    try json:decode(JsonBinary) of
        Map when is_map(Map) ->
            Query = binary_to_list(maps:get(<<"value">>, Map,
                        maps:get(<<"query">>, Map,
                        maps:get(<<"hex">>, Map, <<"">>)))),
            Timeout = to_timeout(maps:get(<<"timeout">>, Map, undefined)),
            {Query, Timeout};
        _ ->
            {binary_to_list(JsonBinary), 10}
    catch
        _:_ -> {binary_to_list(JsonBinary), 10}
    end.

%% Extract and normalise a hex color from a free-form string.
%% Accepts: "#RRGGBB", "RRGGBB", "#RGB" (CSS shorthand), "RGB".
-spec extract_hex(string()) -> string() | error.
extract_hex(Query) ->
    case re:run(string:trim(Query),
                "#?([0-9a-fA-F]{6})",
                [{capture, all_but_first, list}]) of
        {match, [Hex]} ->
            string:uppercase(Hex);
        nomatch ->
            %% Try 3-char CSS shorthand: "f0a" → "FF00AA"
            case re:run(string:trim(Query),
                        "#?([0-9a-fA-F]{3})\\b",
                        [{capture, all_but_first, list}]) of
                {match, [[R, G, B]]} ->
                    string:uppercase([R, R, G, G, B, B]);
                _ ->
                    error
            end
    end.

%%====================================================================
%% Fetch and parse
%%====================================================================

fetch_color(Hex, Timeout) ->
    Url = lists:flatten(io_lib:format("~s~s", [?BASE_URL, Hex])),
    case httpc:request(get, {Url, []},
                       [{timeout, Timeout * 1000},
                        {ssl, [{verify, verify_none}]}],
                       [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, Body}} -> parse_color(Body, Hex);
        _                            -> []
    end.

parse_color(JsonBin, Hex) ->
    try json:decode(JsonBin) of
        Color when is_map(Color) ->
            [build_embryo(Color, Hex)];
        _ -> []
    catch
        _:_ -> []
    end.

build_embryo(Color, Hex) ->
    Name  = nested(Color, [<<"name">>, <<"value">>],     <<"Unknown">>),
    Rgb   = nested(Color, [<<"rgb">>,  <<"value">>],     <<"">>),
    Hsl   = nested(Color, [<<"hsl">>,  <<"value">>],     <<"">>),
    Cmyk  = nested(Color, [<<"cmyk">>, <<"value">>],     <<"">>),
    HexV  = nested(Color, [<<"hex">>,  <<"value">>],
                   list_to_binary("#" ++ Hex)),

    Resume = iolist_to_binary(
        lists:join(" | ", [V || V <- [Rgb, Hsl, Cmyk], V =/= <<>>])
    ),

    #{<<"properties">> => #{
        <<"url">>    => iolist_to_binary([
            "https://www.thecolorapi.com/id?hex=", Hex
        ]),
        <<"title">>  => iolist_to_binary([HexV, " — ", Name]),
        <<"resume">> => Resume,
        <<"source">> => <<"thecolorapi.com">>
    }}.

nested(Map, [Key], Default) ->
    maps:get(Key, Map, Default);
nested(Map, [Key | Rest], Default) ->
    case maps:get(Key, Map, undefined) of
        undefined           -> Default;
        Sub when is_map(Sub) -> nested(Sub, Rest, Default);
        _                   -> Default
    end.

%%====================================================================
%% Helpers
%%====================================================================

to_timeout(undefined)            -> 10;
to_timeout(T) when is_integer(T) -> T;
to_timeout(T) when is_binary(T)  ->
    try binary_to_integer(T) catch _:_ -> 10 end;
to_timeout(_) -> 10.
