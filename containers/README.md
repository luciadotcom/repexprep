# REPEXPREP preprocessing container

## Build Docker image

```bash
docker build \
    --tag repexprep-tools:1.0.2 \
    --file containers/repexprep-tools.Dockerfile \
    containers
```

## Export Docker image

 docker save repexprep-tools:1.0.2 \
    | gzip \
    > containers/repexprep-tools_1.0.2.docker.tar.gz

## Build Singularity image

singularity build \
    containers/repexprep-tools_1.0.2.sif \
    "docker-archive://$(pwd)/containers/repexprep-tools_1.0.2.docker.tar.gz"

The Docker archive and SIF are intentionally excluded from Git.
Checksums and package manifests must be retained for each released
container version.

## Released container artifacts

The Docker archive and SIF are intentionally excluded from Git.
Checksums and package manifests must be retained for each released
container version.
