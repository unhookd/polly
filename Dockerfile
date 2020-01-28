# syntax=docker/dockerfile:1.0.0-experimental
FROM ubuntu:bionic-20180526 AS build 
# Generated 2020-01-28 00:53:43 -0500
# syntax=docker/dockerfile:1.0.0-experimental
FROM build AS deploy 
# Generated 2020-01-28 00:53:43 -0500
# syntax=docker/dockerfile:1.0.0-experimental
FROM deploy AS test 
# Generated 2020-01-28 00:53:43 -0500
