# syntax=docker/dockerfile:1.0.0-experimental
FROM ubuntu:bionic-20180526 AS build 
RUN set -ex; touch /a
# Generated 2020-01-28 02:36:01 -0500
# syntax=docker/dockerfile:1.0.0-experimental
FROM build AS deploy 
RUN set -ex; touch /b
# Generated 2020-01-28 02:36:01 -0500
# syntax=docker/dockerfile:1.0.0-experimental
FROM deploy AS test 
RUN set -ex; touch /c
# Generated 2020-01-28 02:36:01 -0500
