# Changelog

## [3.1.1](https://github.com/kanso-labs/github-actions/compare/v3.1.0...v3.1.1) (2026-08-21)


### Reverts

* remove actions/check-shared-docs ([#41](https://github.com/kanso-labs/github-actions/issues/41)) ([b8f61a5](https://github.com/kanso-labs/github-actions/commit/b8f61a5b3b8dfb65648acc1678a670ddd1d5e886))

## [3.1.0](https://github.com/kanso-labs/github-actions/compare/v3.0.2...v3.1.0) (2026-08-21)


### Features

* add actions/check-shared-docs to catch AGENTS.md drift ([#39](https://github.com/kanso-labs/github-actions/issues/39)) ([3a475f6](https://github.com/kanso-labs/github-actions/commit/3a475f605d513f249e103778a09e71c79a87c1af))

## [3.0.2](https://github.com/kanso-labs/github-actions/compare/v3.0.1...v3.0.2) (2026-08-21)


### Continuous Integration

* call release-please by path to stop the release loop ([#31](https://github.com/kanso-labs/github-actions/issues/31)) ([570442c](https://github.com/kanso-labs/github-actions/commit/570442c9e80c5da02c2f13aaa00235c534123511))
* cut a release for ci-typed changes ([#32](https://github.com/kanso-labs/github-actions/issues/32)) ([80475e4](https://github.com/kanso-labs/github-actions/commit/80475e40bf7662f9726c25e8ca57f6133d7bf41e))

## [3.0.1](https://github.com/kanso-labs/github-actions/compare/v3.0.0...v3.0.1) (2026-08-21)


### Dependencies

* update kanso-labs/github-actions action to v3 ([#29](https://github.com/kanso-labs/github-actions/issues/29)) ([cfb0aa7](https://github.com/kanso-labs/github-actions/commit/cfb0aa79d4c4e472d97b105ad3c19c87fccb5ee5))

## [3.0.0](https://github.com/kanso-labs/github-actions/compare/v2.1.0...v3.0.0) (2026-08-21)


### ⚠ BREAKING CHANGES

* publish to GitHub Packages alongside npm ([#27](https://github.com/kanso-labs/github-actions/issues/27))

### Features

* publish to GitHub Packages alongside npm ([#27](https://github.com/kanso-labs/github-actions/issues/27)) ([bdb4fdd](https://github.com/kanso-labs/github-actions/commit/bdb4fdd01af2c5d70f272a1806da846aa05cfb7d))

## [2.1.0](https://github.com/kanso-labs/github-actions/compare/v2.0.0...v2.1.0) (2026-08-20)


### Features

* share npm publishing and workflow linting ([#20](https://github.com/kanso-labs/github-actions/issues/20)) ([143c257](https://github.com/kanso-labs/github-actions/commit/143c257f40affbf82666bcd636eb5adc3ac7f0fe))

## [2.0.0](https://github.com/kanso-labs/github-actions/compare/v1.3.0...v2.0.0) (2026-08-14)


### ⚠ BREAKING CHANGES

* require the client id and drop the app id alias ([#16](https://github.com/kanso-labs/github-actions/issues/16))

### Features

* require the client id and drop the app id alias ([#16](https://github.com/kanso-labs/github-actions/issues/16)) ([976108e](https://github.com/kanso-labs/github-actions/commit/976108eb44db5ab5ae60da274a722687d1bcef2d))

## [1.3.0](https://github.com/kanso-labs/github-actions/compare/v1.2.1...v1.3.0) (2026-08-14)


### Features

* accept a client id alongside the deprecated app id ([#11](https://github.com/kanso-labs/github-actions/issues/11)) ([61afb90](https://github.com/kanso-labs/github-actions/commit/61afb904b23297c0244f5b3975306438614b2ee9))

## [1.2.1](https://github.com/kanso-labs/github-actions/compare/v1.2.0...v1.2.1) (2026-08-14)


### Bug Fixes

* mint the application token here too ([#12](https://github.com/kanso-labs/github-actions/issues/12)) ([c28b412](https://github.com/kanso-labs/github-actions/commit/c28b4123d75118a46909e3de17c25f9a9a616ab7))

## [1.2.0](https://github.com/kanso-labs/github-actions/compare/v1.1.0...v1.2.0) (2026-08-13)


### Features

* answer Renovate comment commands ([#7](https://github.com/kanso-labs/github-actions/issues/7)) ([4c27183](https://github.com/kanso-labs/github-actions/commit/4c271831f7eb34a9c360e60d50b1b50b15148b02))

## [1.1.0](https://github.com/kanso-labs/github-actions/compare/v1.0.2...v1.1.0) (2026-08-13)


### Features

* test the release workflow on pull requests ([#5](https://github.com/kanso-labs/github-actions/issues/5)) ([e43e127](https://github.com/kanso-labs/github-actions/commit/e43e1278dacf731ce2e16bc201959b30efb87d7d))

## [1.0.2](https://github.com/kanso-labs/github-actions/compare/v1.0.1...v1.0.2) (2026-08-13)


### Bug Fixes

* stop auto-merging release pull requests without an app token ([7243334](https://github.com/kanso-labs/github-actions/commit/724333477a1c3d0a17a9929d942d75c9de6987d0))

## [1.0.1](https://github.com/kanso-labs/github-actions/compare/v1.0.0...v1.0.1) (2026-08-13)


### Bug Fixes

* move the release concurrency guard to the caller ([94296a4](https://github.com/kanso-labs/github-actions/commit/94296a4d2b1bce169dc8bdba394bc36e70ba9025))
