FROM python:3.7-alpine3.7 as base

FROM base as builder
USER root
RUN mkdir /install
WORKDIR /install

COPY requirements.txt /requirements.txt

# numpy in requirements.txt requires Cython which requires gcc
RUN apk add --no-cache --virtual .build-deps gcc musl-dev \
 && pip install cython \
 && pip install --install-option="--prefix=/install" -r /requirements.txt \
 && apk del .build-deps


FROM base
COPY --from=builder /install /usr/local

RUN apk add --no-cache bash perl perl-json

COPY . /app
WORKDIR /app