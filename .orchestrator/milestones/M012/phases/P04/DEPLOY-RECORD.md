---
schema_version: "1.0"
type: deploy-record
milestone: "M012"
phase: "P04"
deployed_url: "https://Build-Fractal.github.io/spec-kit-orchestrator/"
commit_sha: "84ce4bdc9c398d4108162ab27259e42283bbf5a2"
deployed_at: "2026-04-23T03:52:07Z"
deployer: "bkellgren"
gate_giscus_config_result: "pass"
gate_mkdocs_build_result: "pass"
gate_link_check_result: "pass"
gate_giscus_smoke_result: "pass"
---

# M012/P04 First-deploy record

## Deploy summary

Live deploy completed 2026-04-23 against `Build-Fractal/spec-kit-orchestrator`
(private repo; Giscus App installed directly). Wrapper ran clean: all four
gates PASS, `mkdocs gh-deploy --force` created the `gh-pages` branch, and the
site is live at <https://Build-Fractal.github.io/spec-kit-orchestrator/>.

Deploy required a remediation patch first — the M012 auto-mode execution
used SKIP-as-PASS on mkdocs-dependent gates, so three bugs were caught at
first live run: (1) `mkdocs-include-markdown-plugin` aborting on self-
reference task plans containing literal `{% include-markdown %}` examples
inside code fences; (2) stub-generator emitting 52 broken section-index
links for archived-phase + phase-subdir artifacts; (3) `wiki-link-check.sh`
taking 30+ minutes because of per-anchor `grep` subprocess calls. All three
fixed in the remediation patch (commits `b3cbf74`, `1fef016`, `84ce4bd`).

## Wrapper output (actual live run)

```
GATE: giscus-config PASS
INFO    -  Cleaning site directory
INFO    -  Documentation built in 44.87 seconds
BUILD: ok
PASS: 0 broken in-scope links (1292 pages, 22217 in-scope ok, 1293 out-of-scope)
GATE: link-check PASS
PASS: 1291 pages have Giscus (site=wiki/site)
GATE: giscus-smoke PASS
DEPLOY: pushing to gh-pages
INFO    -  Copying '.../wiki/site' to 'gh-pages' branch and pushing to GitHub.
 * [new branch]      gh-pages -> gh-pages
INFO    -  Your documentation should shortly be available at: https://Build-Fractal.github.io/spec-kit-orchestrator/
OK: deployed to gh-pages
```

The wrapper lives at `scripts/wiki/wiki-deploy.sh` (T03). Its gate-ordering
contract (config → build → link-check → smoke → gh-deploy) is validated
end-to-end by this live run.

## Notes

- First deploy: creates the `gh-pages` branch and triggers an
  initial GitHub Pages build. Subsequent deploys reuse the branch
  and force-push the new built output.
- GitHub Pages can take up to a minute to serve a freshly pushed
  `gh-pages` update. If the deployed URL returns 404 immediately
  after the wrapper exits 0, wait 60s and reload.
- If `gh-pages` is a protected branch, `mkdocs gh-deploy --force`
  requires an administrator override. This is not the default;
  the wrapper assumes direct force-push is allowed.
- The fixture-sentinel path does not mutate remote state. Writing
  this record is safe; a later live run by a human operator is the
  only action that pushes to `gh-pages`.

## SC-5 persistence check (pending)

SC-5 (Giscus comment persistence across redeploy) was validated partially
during the test phase: a test comment posted via local `mkdocs serve`
rendered and persisted on reload. Full SC-5 verification requires a second
live deploy after making a trivial wiki edit and confirming a test comment
posted via the deployed URL survives. Record that observation in
`P04-SUMMARY.md` during M012 consolidation.
