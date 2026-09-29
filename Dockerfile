# syntax=docker/dockerfile:1

FROM hugomods/hugo:exts AS build
WORKDIR /src
COPY . .
RUN hugo --minify --cleanDestinationDir --destination /public

FROM nginx:1.27-alpine
COPY --from=build /public/ /usr/share/nginx/html/
EXPOSE 80
