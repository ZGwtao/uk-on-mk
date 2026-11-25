# SPDX-License-Identifier: BSD-2-Clause

# Public uk-on-mk entry point for consumers.
include $(dir $(lastword $(MAKEFILE_LIST)))uk.mk
