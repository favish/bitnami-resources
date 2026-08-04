# discourse-bitnami

Bitnami's Discourse image with the plugin install and the JavaScript asset build
moved from container start to image build.

Not to be confused with `containers/discourse`, which is a from-scratch Discourse
build running Puma on port 3000. This one keeps the Bitnami layout, Passenger on
port 80 and the `DISCOURSE_*` environment contract, so it drops into the Bitnami
Discourse Helm chart with no other changes.

## Why

A stock pod takes four to six minutes to serve its first request, and nearly all
of it is `rake assets:precompile` re-running work that produces identical output
on every pod, every time. The cost is not only slow rollouts:

- an autoscaler cannot answer a traffic spike in ten minutes;
- a compiling pod burns CPU, which distorts the CPU metric the autoscaler reads,
  so pod churn feeds back into more pod churn.

Measured on the forum: 4m03s of asset build, then 15 seconds of CSS, then the
port opens.

## How

`lib/tasks/assets.rake` skips CSS compilation when `SKIP_DB_AND_REDIS=1`, and CSS
is the only part of the task that needs a database. Everything else - the ember
and sprockets build - runs fine in a build container with no services attached.

So the image runs `SKIP_DB_AND_REDIS=1 rake assets:precompile` at build time and
ships `DISCOURSE_PRECOMPILE_ASSETS=no`, which makes the Bitnami startup script
run `assets:precompile:css` alone. CSS still compiles per boot, where the
database is available, and populates `stylesheet_cache` as before.

## Plugins

`ADPLUGIN_REF` pins the plugin commit. It has to stay pinned: `rake
plugin:install` clones HEAD, so an unpinned build silently upgrades the plugin
whenever upstream moves.

Consumers must also stop persisting plugins (`discourse.persistPlugins: false`
in the chart). With persistence on, `/opt/bitnami/discourse/plugins` is replaced
at boot by a symlink into the shared volume, which would discard the baked
plugin while keeping assets compiled against it - a version skew that is hard to
spot and easy to blame on something else.

## Build

Pushed by `.github/workflows/build-discourse-bitnami.yml` to
`ghcr.io/favish/discourse-bitnami`. Tags follow the upstream version plus the
build number, e.g. `3.4.2-debian-12-r7`.
