# 11e rain streak orientation (no Studio)

Files: src/client/Controllers/WeatherController.luau, tools/test_weather_composition.luau

Cause: Rain already used Orientation = VelocityParallel, which lays the particle along its velocity. Squash = +2 then
widened the particle across that axis, giving the horizontal dashes in captures/t13 (11c guessed the sign).

Fix: Rain Squash 2 -> -2 (the one property that changes). Orientation stays VelocityParallel; the wind slant still comes
from Wind.drift via Acceleration; Rate/Life/budget (600) and comfort scaling untouched. Snow and dust have no Squash or
Orientation (soft, FacingCamera); lobby path untouched.

Tests (test_weather_composition 242 passed, 0 failed): Orientation VelocityParallel + Squash < 0; end-of-life velocity has
down >= horizontal, horizontal unit vector equals Wind.Toward (WNW, X<0, Z<0); rain rate*life within 600; snow/dust no Squash.
luau-compile --null OK. lune_compat --all hit a PermissionError in legacy_world.rmtree (work/legacy locked by another lane), unrelated.

Studio must capture: rain at player height, camera side-on and facing wind; streaks should be vertical-ish tilted WNW. If
still wide, the sign semantics are opposite for this build: try Squash = -0.5 or a tall-thin texture.
