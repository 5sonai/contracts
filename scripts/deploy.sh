#!/bin/bash
sui client publish --force --with-unpublished-dependencies --skip-dependency-verification --skip-fetch-latest-git-deps --gas-budget 100000000
