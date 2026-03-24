# Release Checklist

Use this checklist before publishing a new `rails_orbit` version to RubyGems.

## 1) Version and Changelog

- [ ] `lib/rails_orbit/version.rb` is bumped to the intended release version.
- [ ] `CHANGELOG.md` has a dated entry for that version.
- [ ] Release notes summarize user-visible changes and migration notes.

## 2) Quality Gates

- [ ] Run full RSpec suite: `bundle exec rspec`
- [ ] Run demo integration suite: `cd ../rails_orbit_demo && bundle exec cucumber`
- [ ] Build gem successfully: `gem build rails_orbit.gemspec`
- [ ] Optional smoke install in a fresh app/worktree.

## 3) Gem Packaging

- [ ] Verify `spec.files` includes required runtime assets (`app/`, `lib/`, `public/`, `db/`).
- [ ] Confirm no local/internal files are packaged.
- [ ] Ensure gem metadata links are valid.
- [ ] Ensure `rubygems_mfa_required` metadata is present.

## 4) Security and Ops

- [ ] Dashboard auth behavior is verified in non-prod and prod modes.
- [ ] CSP/security headers are present and tested.
- [ ] Storage adapter defaults and setup tasks (`rails_orbit:setup`, `rails_orbit:status`) are validated.
- [ ] CI matrix is green for supported Ruby/Rails versions.

## 5) Publish

- [ ] `gem push rails_orbit-<version>.gem`
- [ ] Create Git tag: `git tag v<version> && git push origin v<version>`
- [ ] Create GitHub release notes from changelog entry.
- [ ] Verify RubyGems page metadata and README rendering.

---

## Current Status (2026-03-24)

- [x] RSpec: passing (84 examples)
- [x] Demo Cucumber: passing (55 scenarios)
- [x] Gem builds successfully
- [x] Gemspec metadata warning removed
- [x] RubyGems MFA metadata added
- [x] Changelog dated for `0.1.0`
- [ ] Version bump decision for next publish (currently `0.1.0`)
- [ ] Final publish + tag
