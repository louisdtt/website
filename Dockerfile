FROM node:20 AS build-env
ENV NODE_ENV production
ADD . /app
WORKDIR /app
RUN npm ci --omit=dev

FROM gcr.io/distroless/nodejs20-debian12:nonroot
COPY --from=build-env /app /app
WORKDIR /app
EXPOSE 3000
CMD ["index.js"]
