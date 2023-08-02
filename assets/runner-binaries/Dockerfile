FROM alpine:latest as package

WORKDIR /tmp/runner-binaries

RUN apk add --no-cache curl

ENV RUNNER_RELEASE_ARTIFACT_BASE_URL=https://github.com/philips-labs/terraform-aws-github-runner/releases/download
ARG RUNNER_VERSION=3.6.1

RUN curl -L "${RUNNER_RELEASE_ARTIFACT_BASE_URL}/v${RUNNER_VERSION}/runner-binaries-syncer.zip" -o runner-binaries-syncer.zip && \
    curl -L "${RUNNER_RELEASE_ARTIFACT_BASE_URL}/v${RUNNER_VERSION}/runners.zip" -o runners.zip && \
    curl -L "${RUNNER_RELEASE_ARTIFACT_BASE_URL}/v${RUNNER_VERSION}/webhook.zip" -o webhook.zip
