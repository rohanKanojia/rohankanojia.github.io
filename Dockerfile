FROM alpine:3.16.0 
ARG HUGO_VERSION=0.120.4-r0
RUN apk add --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community --no-cache hugo=~${HUGO_VERSION}
RUN apk add --update wget  nodejs npm hugo
ENV HUGO_ENVIRONMENT=production
ENV HUGO_ENV=production
RUN [[ -f package-lock.json || -f npm-shrinkwrap.json ]] && npm ci || true
RUN npm install -g sass
WORKDIR /usr/src/
ENTRYPOINT ["hugo", "--gc", "--minify", "--baseURL"] 
