# Agent

This directory contains configuration for the OpenCode agent container.

The agent is pulled from `pandeiro/openmoko:latest` on DockerHub.

For development or custom builds, you can build and push your own image:

```bash
docker build -t your-registry/openmoko:latest .
docker push your-registry/openmoko:latest
```
