FROM mambaorg/micromamba:latest

ARG IMAGE_VERSION=1.0.0

LABEL org.opencontainers.image.title="REPEXPREP preprocessing tools"
LABEL org.opencontainers.image.description="Software environment for REPEXPREP preprocessing"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"

COPY --chown=$MAMBA_USER:$MAMBA_USER \
    repexprep-tools.yml \
    /tmp/repexprep-tools.yml

RUN micromamba install \
        --yes \
        --name base \
        --file /tmp/repexprep-tools.yml \
    && micromamba clean \
        --all \
        --yes \
    && rm -f /tmp/repexprep-tools.yml

ENV PATH="/opt/conda/bin:${PATH}"
ENV LC_ALL="C.UTF-8"
ENV LANG="C.UTF-8"
ENV HOME="/tmp"

WORKDIR /work
