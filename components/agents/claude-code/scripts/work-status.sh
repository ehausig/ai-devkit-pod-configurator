#!/bin/bash
# Backward compatibility wrapper for work-status.sh
# Redirects to work-tracker.sh status command

exec work-tracker.sh status "$@"
