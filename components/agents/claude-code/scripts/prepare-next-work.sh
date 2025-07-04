#!/bin/bash
# Backward compatibility wrapper for prepare-next-work.sh
# Redirects to work-tracker.sh prepare command

exec work-tracker.sh prepare "$@"
