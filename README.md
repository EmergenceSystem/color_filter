# color_filter
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE.md)

An [em_filter](https://hex.pm/packages/em_filter) agent that identifies colors and returns their name, RGB, HSL, and CMYK values via [The Color API](https://www.thecolorapi.com/) (free, no key required).

## Query

A hex color code in any of the supported formats. Prefixed text is stripped automatically.

| Input form | Example |
|---|---|
| 6-char hex | `#FF5733` or `FF5733` |
| 3-char CSS shorthand | `#F57` or `f57` |
| With prefix text | `color #1A2B3C` |

| Field | Example |
|---|---|
| title | `#FF5733 — Outrageous Orange` |
| resume | `rgb(255, 87, 51) \| hsl(11°, 100%, 60%) \| cmyk(0, 66, 80, 0)` |
| source | `thecolorapi.com` |

## Usage

**Via curl (direct to em_disco):**

```bash
# Full hex
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "#FF5733", "capabilities": ["color"]}'

# CSS shorthand
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "f57", "capabilities": ["color"]}'

# With prefix
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "color #1A2B3C", "capabilities": ["color"]}'
```

**Via Erlang shell:**

```erlang
emquest_cli:query(<<"#FF5733">>).
emquest_cli:query(<<"1A2B3C">>).
```

## Installation

```bash
git clone https://github.com/EmergenceSystem/color_filter.git
cd color_filter
rebar3 shell --apps color_filter
```

Requires `em_disco` running on `localhost:8080` (configured in `emergence.conf`).

## Capabilities

`search`, `query`, `color`, `colour`, `hex`, `rgb`, `palette`

## License

Apache 2.0 — see [LICENSE.md](LICENSE.md).
